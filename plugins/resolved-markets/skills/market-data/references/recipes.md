# Navigation recipes

One-shot patterns for the common jobs (base URL and `X-API-Key` header implied on every call).

**R1 — Current live market of a crypto series.** `GET /v1/markets/by-slug/btc-updown-5m` (1 credit) resolves straight to the current window's full identity. Or pull `/v1/markets/live?crypto=BTC&timeframe=5m` — four rows come back (the in-flight window plus three pre-subscribed successors); take the one with `status: "live"`.

**R2 — The market that was live at a past instant T.** `GET /v1/markets/history/recent?crypto=BTC&timeframe=5m&since=<T-10min>&before=<T>` and pick the row whose `first_seen ≤ T ≤ last_seen` (for crypto windows, `end_date` tells you the exact window). Then pull its data windowed. Alternative when you just need the book state: `GET /api/snapshot?timestamp=<T>&crypto=BTC&timeframe=5m` (3 credits, no id needed, 1-hour lookback).

**R3 — Walk deep history (months back).** Use a shrinking `before` cursor, never `offset`:
1. `GET /v1/markets/history/recent?crypto=BTC&timeframe=5m&limit=500` → note the page's oldest `last_seen`.
2. Next page: same query + `before=<that last_seen>`. Repeat.
3. Expect ~1 row of overlap at each cursor boundary — dedupe by `market_id`.
Or jump straight to an era: `?before=2026-05-01&order=oldest` starts from the oldest stored markets active before May 1. For a full dataset build, `GET /v1/markets/history` lists every stored market for the filter in one **1-credit** call with no pagination — **but it has no cursor and times out on high-cardinality filters.** Measured: `crypto=BTC&timeframe=1d` (157 markets) 3 s, `category=sports&subcategory=ATP` (3,336) 19 s, `crypto=BTC&timeframe=1h` (3,745) 26 s — while `timeframe=15m` and `timeframe=5m` both time out. Use it for a low-cardinality filter; page `history/recent` (500/page, 1 credit, ~7 s) for a short-timeframe crypto series.

**R4 — Study one market end-to-end (works for any age).**
1. Identity/result: `GET /v1/markets/metadata?market_id=<id>` — question, outcomes, `end_date`, `resolved_outcome`.
2. Shape: `GET /v1/markets/:id/snapshots?side=UP&interval=1m` — whole lifetime as candles, one call.
3. Open: `…/snapshots?side=UP&order=asc&limit=100&count=false`. Close/settlement: default order, `offset=0`.
4. Fills: `GET /v1/markets/:id/trades?limit=500`. Lifetime stats: `GET /v1/markets/:id/summary`.

**R5 — Reassemble a grouped event** (sports fixture's 3 legs, a city's temperature buckets, a hit-price strike ladder): take `neg_risk_id` from any leg, then `GET /v1/markets/metadata?neg_risk_id=<id>` — or browse with `…metadata?category=sports&subcategory=FIFA&group_by_event=true`, which nests `legs[]` under each event. Sports `end_date` = scheduled kickoff (halftime ≈ kickoff + 45 min for in-game windows).

**R6 — Settlement audit of a series.** `GET /v1/markets/metadata?crypto=BTC&timeframe=5m&resolution_status=resolved&limit=100` gives winners (`resolved_outcome`, `outcome_prices`, `resolved_at`) in bulk. To see the closing book of any of them: `GET /api/snapshot?timestamp=<last_seen>&marketId=<id>&includebook=true` — winner mid reads ≈ 0.995.

**R7 — Weather, one city one day.** Live: `GET /v1/markets/live?category=weather&subcategory=NYC` — the day's bucket legs share `eventTitle`/`negRiskMarketID`. Historical: `…history/recent?category=weather&subcategory=NYC&before=<date>&order=oldest`; daily slugs look like `highest-temperature-in-nyc-on-april-8-2026-38-39f`. City names are case-sensitive with spaces (`Hong Kong`, `Buenos Aires`).

**R8 — A past sports match.** `GET /v1/markets/history/recent?category=sports&subcategory=FIFA&limit=500` (slugs like `fifwc-esp-arg-2026-07-19`), or resolve a known slug via `by-slug`. Match = one event: legs (TeamA/TeamB/Draw) share `neg_risk_id`; IPL cricket moneylines are instead a single two-outcome market whose outcomes are the two team names (first team = UP side).

**R9 — Prediction market vs. the underlying.** Crypto snapshot rows already embed spot `crypto_price` (+ `crypto_price_age_ms`) at capture time — for most "did the market track spot?" questions no second series is needed. For order-book-level comparison (Scale+): `GET /v1/exchange/snapshots?exchange=hyperliquid_perp&symbol=BTC&from=<open>&to=<close>` windowed to the market's lifetime (all 7 coins have a perp book).

**R10 — Build a resolved dataset (the history × metadata join).** `history/recent` has the `before` cursor but no resolution fields; `metadata` has resolution fields but **no cursor and a hard `limit` cap of 1000 (default 100!; values above the cap are silently clamped, not rejected)** — a filter-only metadata query silently truncates bulk pulls. Join the two:
1. Page `history/recent` with the `before` cursor (R3), collecting `market_id` + `first_seen`/`last_seen` for your date range.
2. Batch-resolve outcomes: `metadata?market_id=<id1>,<id2>,…` in chunks of ~50 ids, passing `limit` ≥ chunk size.
3. **Verify `count` equals the chunk size on every call** — a short count means truncation or unknown ids, not "no more data".
4. Join on `market_id`; use each market's `first_seen`/`last_seen` to clamp any snapshot windows you pull next.

