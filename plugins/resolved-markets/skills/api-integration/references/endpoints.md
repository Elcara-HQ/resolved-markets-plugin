# REST endpoint reference

Base URL `https://api.resolvedmarkets.com`. Every authenticated request needs `X-API-Key: rm_your_key_here`.

Unknown query parameters are **rejected with 400** (the error lists `unknown_parameters` and `allowed_parameters`) — don't guess parameter names. All filters AND together. Exact response skeletons for every endpoint are in `response-shapes.md` (same directory) — parse against those, not guesses.

### Public (no key)

- `GET /health` — infra status (`clickhouse`, `redis`, `ws_clob`, `ws_trade`, `pipeline_ready`, …). `200` healthy / `503` degraded. Lighter probes: `/health/live`, `/health/ready`.
- `GET /v1/public-stats` — total `snapshot_count` (string), `active_markets`, current `prices` for all 7 coins, Hyperliquid collection freshness. Cached 5 s.
- `GET /v1/payments/packs` — tier/pack definitions (public).

### GET /v1/categories — 1 credit

Every collection config with `id`, `category`, `displayName`, `activeMarkets`, capture cadence. One row per **config**, not per category (`crypto` = `crypto-updown` + `crypto-hit-price`; `weather` = daily-temperature + hurricanes + global-weather; `equities` spans stocks/indices/commodities/forex/IPOs/earnings/…). Sum `activeMarkets` across rows sharing `category` for a category total. Cheap first call of a session.

### GET /v1/markets/live — 1 credit

All currently active markets visible to your tier. Filters (all optional, AND-ed): `category`, `subcategory` (case-sensitive; weather uses full city names — `NYC`, `Hong Kong`), `crypto` (one of the 7 tickers), `timeframe`.

`limit` (1–5000) and `offset` cap the payload — worth using, since an unfiltered call on a full-access tier returns ~2,000 markets. **Passing either one sorts the response soonest-expiring first** (`expiresIn` ascending, ties broken by `conditionId`), so `?crypto=BTC&limit=1` is the *current* BTC window rather than an arbitrary one. Omit both and you get every match in discovery order, unsorted.

Each item: `conditionId`, `slug`, `question`/`label`, `category`, `subcategory`, `timeframe`, `crypto`, `tokenIds` (`[up, down]`), `tokenIdUp`/`tokenIdDown`, `outcomes`, `endDate` (ISO), `active`, `expired`, `expiresIn` (ms). Grouped markets (weather buckets, sports fixtures) also carry `eventTitle` and `negRiskMarketID`.

Traps:
- `crypto` is an **empty string on non-crypto markets** — filtering by `crypto` implicitly excludes every other category.
- Near a window boundary, crypto slots pre-subscribe the next window (~2 min early, these markets trade pre-open), so e.g. `?crypto=BTC&timeframe=5m` briefly returns **two** live markets. Take the one with the smaller `expiresIn` as the current window.
- `?crypto=BTC` returns **both** the up/down family and the hit-price strikes; add `timeframe=5m`/`1d`/etc. to isolate one series (`timeframe=hit-price` for the strike ladder).

### GET /v1/markets/by-slug/:slug — 1 credit

Resolve a slug (or raw `0x…` conditionId) to full market identity — works for live **and** closed markets. Matching is fuzzy: exact → parsed pattern → prefix → substring. `btc-updown-5m` resolves to the *current* live BTC 5-minute market; `btc-updown-5m-1785881100` a specific window (trailing epoch = window **start**, not expiry). Long coin names are accepted (`bitcoin` → BTC). Closed markets return `active: false, expired: true` with full metadata (question, `end_date`, `event_title`, `neg_risk_id`, token ids).

Caveat: looking up a **currently-live** market by raw conditionId resolves through durable metadata and reports `active: false` — use the slug, or take live status from `/v1/markets/live`.

`GET /v1/markets/by-slug/:slug/orderbook` — the live orderbook addressed by slug. **Active markets only** (closed slugs → 404).

### GET /v1/markets/:id/orderbook — 1 credit

Live orderbook for both tokens. Response: market identity + `up` and `down` objects, each with `bestBid`, `bestAsk`, `midPrice`, `spread`, `bidDepth`, `askDepth`, full `bids[]`/`asks[]` as `{price, size}` (bids high→low, asks low→high), `sequenceNumber`, epoch-ms `timestamp`/`eventTimestamp`/`captureTimestamp`. Crypto markets add `crypto_price` (live spot: Binance; HYPE from Hyperliquid) and `cryptoPriceAgeMs`. `crypto`/`crypto_price` are **omitted on non-crypto markets**. Unknown market → `404 {"error":"Market not found"}`.

### GET /v1/markets/:id/snapshots — 5 credits/page

The core historical endpoint: paginated snapshot time-series for one market.

| Param | Notes |
|---|---|
| `side` | `UP` or `DOWN` — use it whenever one side suffices |
| `from` / `to` | UTC bounds — ISO 8601, `YYYY-MM-DD HH:MM:SS[.mmm]`, or bare date all accepted |
| `order` | `desc`/`newest` (default) or `asc`/`oldest` |
| `limit` | default 500, max 5000 — **2000** with `includebook=true`, **50000** with `interval=`. Over the cap is a `400`, never a silent clamp, so the rows you get back always match the page you asked for |
| `offset` | pagination offset |
| `includebook` | `true` → full `bids[]`/`asks[]` per row |
| `touchsize` | `true` → adds `best_bid_size`/`best_ask_size`: size resting AT the touch, in **shares**. Off by default (older partitions compute it from the book arrays, ~3x a scalar read); free and automatic with `includebook=true`; `400` if combined with `interval` (a candle has no single touch level). Dollars at the touch = `best_bid_size × best_bid` |
| `interval` | OHLC downsampling: `1s` `5s` `15s` `30s` `1m` `5m` `15m` `30m` `1h` `4h` `1d` |
| `count` | `false` → skip total count (`total: null`), faster |

Raw rows: `timestamp`, `token_side`, `outcome_index`, `category`, `subcategory`, `label`, `timeframe`, `best_bid`, `best_ask`, `mid_price`, `spread`, `bid_depth_total`, `ask_depth_total`, plus fidelity fields `event_timestamp`, `capture_timestamp`, `sequence_number`, `crypto_price_age_ms` (`-1` = not tracked, e.g. some backfilled rows). Crypto markets add `crypto`/`crypto_price`; non-crypto rows omit them.

**Rules that matter:**
- Default order is **newest-first**. Page 0 is the market's *close*; for the opening minutes use `order=asc`, and for the settlement book use the default with `offset=0`.
- **On a live market, an unwindowed query is served from a recent default window (~36 h), not full history.** Explicit `from`/`to` reaches any stored range. Always pass bounds on long-running markets.
- **Use `interval=` once one side exceeds 5,000 rows** (one raw page). Capture is sub-second, so multi-day markets hold 100k+ raw rows; `interval=1m`/`1h` collapses them to one candle per bucket × side in one call. Candle rows: `bucket`, `token_side`, `open/high/low/close` (of mid), `vwap_mid`, `avg_spread`, `avg_best_bid/ask`, `avg_bid/ask_depth`, `crypto_price`, `snapshot_count`. `total` = bucket count. Candles carry no book arrays and no fidelity fields.
- `includebook=true` cannot combine with `interval` → `400` with an explanatory message.
- **`interval=` is only worth it above one page.** Measured whole-market, one side: a 1d crypto market is 37,150 raw rows = 8 pages = 40 credits, versus 1 candle call = 5 credits (**8×**); a weather daily is 3×; a **5m window is 2,077 rows = 1 page, so candles cost exactly the same** and lose detail. `snapshot_count` on `history/recent` (1 credit) tells you the page count before you spend. `limit` with `interval=` is a ceiling only — you get `window ÷ interval` candles regardless.
- **`touchsize=true` costs ~1.08× a plain row** (measured across six markets in five categories) — add it freely rather than reaching for `includebook=true`.
- **The three page caps are enforced, not clamped.** `limit` above the cap for the mode you're in returns `400` with the applicable ceiling in the message — `5000` raw, `2000` with `includebook=true` (measured 1.9–5.5× the bytes of a plain row — the halved cap, not the bytes, is what makes it 2.5× the credits per row), `50000` with `interval=` (candles are tiny, so a wide window fits in one call). Nothing is silently truncated, so a pager that steps by the limit it requested can never skip rows. The one route that *does* clamp silently is `/v1/markets/metadata`, whose own cap is 1,000.
- Unwindowed pulls or `/summary` on markets that have been live for **months** can hit the server-side query timeout (`500`, or `total: null` when only the count timed out — the rows are still valid). Windowed queries return fast.

```bash
# Whole market as 1-minute candles, one call:
curl -H "X-API-Key: $KEY" \
  "https://api.resolvedmarkets.com/v1/markets/$ID/snapshots?side=UP&interval=1m"
# Opening seconds of a market:
curl -H "X-API-Key: $KEY" \
  "https://api.resolvedmarkets.com/v1/markets/$ID/snapshots?side=UP&order=asc&limit=100&count=false"
```

### GET /v1/markets/:id/trades — 5 credits/page

Executed-fill tape (`last_trade_price` events) for one market. Params: `side`, `from`/`to`, `order` (`desc` default), `limit` (max 5000), `offset`, `count=false`. Rows: `asset_id` (= snapshot `token_id`), `timestamp` (our capture time — there is no separate exchange event time), `price`, `size`, `side` (`BUY`/`SELL` aggressor), `token_side`, `category`, `subcategory` (may be empty string on some rows).

Coverage caveats: this is the tape **as observed live** — trade capture started later than snapshot capture and collector outages leave gaps. A market with no captured trades returns `200` with `total: 0` (not an error); a completely unknown market returns `404`. No `transaction_hash`. `token_side` may be `null` on closed markets queried without `?side=` — map it yourself from `asset_id`.

### GET /v1/markets/:id/summary — 3 credits

Lifetime aggregates: `snapshot_count`, `first_seen`/`last_seen`, avg/min/max of mid price and spread, avg depths, and per-side (`UP`/`DOWN`) sub-aggregates (`avg_bid`, `avg_ask`, `avg_mid`, `max_bid`, `min_ask`, snapshot counts). Crypto markets add `avg_/min_/max_crypto_price`. Cached 15 s. Works for markets of any age — but for markets live for **months**, prefer `/snapshots?interval=` (summary can time out).

### GET /v1/markets/metadata — 1 credit

Durable descriptive metadata, **including for closed markets** — and the settlement result:

- `resolution_status`: `resolved` / `unresolved`; `resolved_outcome`: the **winning** label (`Up` / `Down` / `Yes` / team name); `outcome_prices` aligned to `outcomes` (`["0","1"]` = second outcome won); `resolved_at`. Live markets: `unresolved` + `null`. A 50/50 split in `outcome_prices` with empty `resolved_outcome` is a voided/50-50 settlement, not a bug. A market that closed minutes ago is normally still `unresolved` briefly.
- Filters: `market_id` (repeat or comma-separate), `neg_risk_id`, `slug`, `category`, `subcategory`, `crypto`, `timeframe`, `resolution_status`, `group_by_event` (nest legs under their shared `neg_risk_id` — reassembles a fixture's three legs, a temperature bucket ladder, a strike ladder), `limit` (≤1000).
- `neg_risk_id` is the key shared by every leg of one event. For sports, `end_date` is scheduled **kickoff** (anchor in-game windows from it).

```bash
# Which way did recent BTC 5m windows settle?
curl -H "X-API-Key: $KEY" \
  "https://api.resolvedmarkets.com/v1/markets/metadata?crypto=BTC&timeframe=5m&resolution_status=resolved&limit=20"
```

### GET /v1/markets/history/recent — 1 credit

Browse stored markets (live + closed) from the pre-aggregated stats table, newest-first by default. Filters: `category`, `subcategory`, `crypto`, `timeframe`, `since`, `before` (`YYYY-MM-DD` or ISO; a market matches if it was *active* in the range), `order` (`newest` default / `oldest`), `status` (`live` / `closed` / `all` default), `limit` (≤500). Cached 10 s.

Rows: `market_id`, `slug`, `question`, `first_seen`, `last_seen`, `snapshot_count` (string), `is_live`, `end_date`, `category`, `subcategory`, `crypto`, `timeframe`, `event_title`, `neg_risk_id`, `replay_locked`.

**Reading the envelope:** with `status=all` the `limit` is split across both kinds — `limit=60` returns 30 live + 30 closed, `limit=61` returns 30 + 31. `returned_live` / `returned_closed` tell you the actual split of *this page*, while `total_markets` / `live_count` / `closed_count` describe the whole filtered set. If a page looks like it has "too many" live markets, read `returned_live` rather than counting `is_live` by hand. Note the envelope totals are **not** tier-scoped even when the rows are — on a Free key an out-of-tier `category` filter still reports the global totals while every row comes back `replay_locked: true`. **Null-guard the identity fields**: on occasional older rows (~1 in 1,500) `slug`, `question`, `event_title`, and `neg_risk_id` all come back `null` — a pager that assumes them non-null crashes deep into history. When any date filter is set, only stored/historical markets are returned.

**Pagination trap: there is no `offset` here.** The route accepts `offset` without erroring but **ignores it** — repeating a request with `offset=1` returns identical rows. Page through deep history with a **`before` cursor** instead (see the recipes below).

`GET /v1/markets/history` — the full unpaginated listing (same `category`/`subcategory`/`crypto`/`timeframe` filters only). Heavy; cached 30 s; for dataset builds. Hyperliquid series appear as `market_id` like `exchange:hyperliquid_perp:BTC`.

### GET /api/snapshot — 3 credits

Closest snapshot at-or-before a timestamp (searches up to 1 h back; use `/snapshots` with `from`/`to` for anything older-range). Params: `timestamp` (required; UTC — ISO 8601 or `YYYY-MM-DD HH:MM:SS[.mmm]`), `marketId` (with it → `{market_id, …, up, down}`; without → array of 2 most recent matching rows), `crypto`, `timeframe`, `includebook=true` for full arrays. Cached 5 s.

Settlement-book recipe: take `last_seen` from `/v1/markets/history/recent`, then `GET /api/snapshot?timestamp=<last_seen>&marketId=<id>&includebook=true` — the winning side's mid reads ≈ 0.995+ (clamped, bids-only book).

### GET /api/snapshot/latest — 1 credit

5 most recent snapshots across all markets (optional `crypto`/`timeframe`/`includebook`), bounded to the last 10 min. Cached 3 s. Good freshness pulse.

### Exchange data (Hyperliquid) — Scale/Enterprise only, 1 credit each

Free/Pro receive `403 tier_not_allowed`. Only `exchange=hyperliquid_perp` is valid (anything else → `400 {"error":"Invalid exchange","valid":["hyperliquid_perp"]}`). Symbols collected: `BTC`, `ETH`, `SOL`, `XRP`, `DOGE`, `HYPE`, `BNB` — every coin with collected Polymarket markets also has a perp book (case-insensitive; anything else returns 404/empty).

- `GET /v1/exchange/orderbook?exchange=hyperliquid_perp&symbol=BTC` — latest snapshot with full 20-level `bids`/`asks` as **`[price, size]` pairs** (note: pairs here, not `{price,size}` objects). Only rows from the last 60 s count as live — `404 "No recent data"` means the collector is catching up; retry, don't treat as permanent. Cached 1 s.
- `GET /v1/exchange/snapshots?exchange=hyperliquid_perp&symbol=ETH&from=…&to=…&limit=…` — historical top-of-book rows (no depth arrays), newest-first, default last 24 h, limit ≤5000. Captured ~1/sec but **deduplicated** (unchanged books aren't re-written; a row lands at least every ~5 s) — fewer rows than 1 Hz in quiet periods is normal, not data loss.

