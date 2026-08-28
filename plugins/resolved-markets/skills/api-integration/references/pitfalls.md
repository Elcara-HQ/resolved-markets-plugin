# Pitfalls checklist

Documented behaviors that look like bugs. Check here before reporting missing or wrong data.

- `/snapshots` default order is **DESC** (newest first) — paging "to the end" reaches the market *open*, not its settlement.
- Unwindowed `/snapshots` on a live market covers only ~36 h — pass `from`/`to` for full history.
- Two live markets per crypto slot near window boundaries — disambiguate by `expiresIn`.
- `crypto` = `""` on non-crypto rows; `crypto`/`crypto_price` fields are omitted entirely from non-crypto snapshot/orderbook/summary responses.
- Clamped mid convention: never "fix" a 0.995 mid on a one-sided book — that's the correct settled-market reading, and a raw `(bid+ask)/2` over a missing side is wrong. **`spread` is clamped the same way**, so a one-sided book reports a tight-looking spread that is not liquidity — require `best_bid > 0 && best_ask > 0` first.
- **A `sequence_number` jump is NOT a missed update** — it counts book events applied, and capture stores ~1 row per 50 ms, so 98.4% of adjacent rows jump by more than 1. It also resets on re-subscribe and is `0` on backfilled rows. Never build gap detection on it.
- **`X-Credits-Remaining` is a gauge, not a ledger** — it rises on refresh/top-up and settles a few credits late under load. Sum `X-Credits-Cost` for an exact spend; trust the `402` as the real limit.
- `limit` over a page cap is a **400, not a clamp** (5000 raw / 2000 `includebook` / 50000 `interval`) — so a page never comes back quietly short.
- Big counters are JSON strings (`snapshot_count`, `sequence_number`).
- Unknown query params → 400, not silently ignored. Exception: `offset` on `/v1/markets/history/recent` is accepted but **ignored** — page with a `before` cursor.
- Slug epochs are window **start** times — take expiry from `endDate`/`end_date`, never derive it from the slug.
- The trade tape is as-observed: empty (`total: 0`) tapes on old markets are normal; verify coverage before treating it as complete.
- Exchange books use `[price, size]` pairs; Polymarket books use `{price, size}` objects.
- Deep out-of-the-money hit-price strikes legitimately have one-sided or empty books — market structure, not missing data.
- **Candle `open`/`high`/`low`/`close`/`vwap_mid` are all mid-derived** — filling a backtest at `close` assumes a zero spread. Use `avg_best_ask` to buy and `avg_best_bid` to sell; below mid 0.10 the round-trip spread exceeds most edges.
- **`subcategory` + `timeframe` is not unique in equities** — `SPX`+`1d` is two different instruments (`spx-up-or-down-on-…` settles on the 4pm close, `spx-opens-up-or-down-on-…` on the 9:30 open) sharing an identical `end_date`. Disambiguate on `slug`.
- **Equities dailies list 26–32 h early (≈77 h over a weekend)** — window from `end_date`, never from `first_seen`, or a day of pre-session stub quoting contaminates the sample.
- **An out-of-tier list filter returns `200 []`, not `403`** — an empty result means "no markets" *or* "not your tier". Read `X-RateLimit-Limit`/`X-Credits-Remaining` to know which.
- **Check keys with `/v1/api-keys/validate` (0 credits)**, not `/v1/categories` (1 credit per run).

## Triage — diagnose before concluding "no data"

**When a result looks wrong, diagnose before concluding "no data":**

| Symptom | Most likely cause | Fix |
|---|---|---|
| `200` with empty array/list | Filter value has wrong case or spelling (`nyc`, `hong kong`, `btc`) — filters are exact, case-sensitive | Copy the exact string from the catalog or from an unfiltered pull |
| `200`, empty `data[]` on `/snapshots` with `from`/`to` set | Your window falls outside the market's stored `[first_seen, last_seen]` — even by seconds — and **no error is raised** | Clamp the window to `first_seen`/`last_seen` from `history/recent` before pulling |
| `200`, trades `total: 0` | Market predates trade capture or had no fills | Normal — report an empty tape, don't retry |
| `200`, `total: null` on snapshots | `count=false` was set, or the count sub-query timed out — `data` rows are still valid | Use the rows; don't discard them |
| Snapshots stop ~36 h back on a live market | Unwindowed default window | Pass explicit `from`/`to` |
| Two markets for one crypto slot | Boundary pre-subscribe | Take the smaller `expiresIn` |
| `by-slug` says a live market is `active: false` | Looked it up by raw conditionId | Look up by slug, or use `/v1/markets/live` for status |
| Mid price 0.5 on a market that should be decided | You recomputed mid yourself from a one-sided book | Use the API's `mid_price` (clamp convention) |
