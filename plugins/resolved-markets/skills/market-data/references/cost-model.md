# Credit cost model and the cheapest way to get each thing

Costs below are the live `ROUTE_COSTS` table, confirmed against the production API by reading the
`X-Credits-Cost` header on every route. Figures marked *(measured)* were timed against
`api.resolvedmarkets.com` in August 2026 on real markets; treat them as representative, not exact.

## What every route costs

| Credits | Routes |
|---|---|
| **0** | `/health`, `/v1/public-stats`, `/v1/api-keys/validate`, `/v1/backtest/templates`, `/v1/backtest/runs/*` (status + SSE), `/v1/backtest/v2/agent/chats`, **and every WebSocket message** |
| **1** | `/v1/categories`, `/v1/markets/live`, `/v1/markets/by-slug/:slug`, `/v1/markets/:id/orderbook`, `/v1/markets/metadata`, `/v1/markets/history`, `/v1/markets/history/recent`, `/api/snapshot/latest`, `/v1/exchange/orderbook`, **`/v1/exchange/snapshots`**, `/v1/strategies`, `/v1/backtest/history`, and anything else metered |
| **3** | `/v1/markets/:id/summary`, `/api/snapshot` |
| **5** | `/v1/markets/:id/snapshots`, `/v1/markets/:id/trades`, `/v1/wallets/:address/fills` |
| **25** | `/v1/backtest/agent`, `/v1/backtest/run`, `/v1/backtest/v2/agent`, `/v1/backtest/v2/run` |

Note the two that surprise people: **`/api/snapshot/latest` is 1, while `/api/snapshot` is 3**, and
**`/v1/exchange/snapshots` is 1 despite being a time series** — see "cheap paths" below.

**Billing mechanics, all verified:**

- **Only `2xx` is charged.** A `400`/`403`/`404`/`500` sets `X-Credits-Cost` but deducts nothing,
  so the header on an error is the *would-be* price, not a charge.
- **A cache `HIT` still costs full price.** Confirmed: two consecutive `/summary` calls returned
  `X-Cache: MISS` then `X-Cache: HIT`, both `X-Credits-Cost: 3`. Polling faster than a route's TTL
  buys you nothing and bills you fully.
- **`402` is pre-checked** before the handler runs, so an unaffordable request costs no query.
- **`/v1/api-keys/validate` is not merely 0-cost, it is outside the metering middleware** — it
  returns *no* credit headers at all. That makes it the right start-up liveness check.

**Both credit headers are readable from browser JavaScript.**
`Access-Control-Expose-Headers` includes `X-Credits-Cost` and `X-Credits-Remaining` alongside
`X-RateLimit-Limit`/`-Remaining`/`-Reset`, `X-Cache`, `X-Total-Count`, `X-Limit`, `X-Offset`,
`X-Interval`, `X-Row-Count`, `X-Format`, `X-Onchain-Enriched`, `X-Tier-Scope-Filtered` and
`X-Key-Limit-Notice` — so a cross-origin `fetch()` can meter spend directly. Anything outside that
list is invisible to browser JS even though curl and any server-side client sees it.

**A `4xx` sends `X-Credits-Cost` but is never charged.** Only 2xx responses deduct (verified: 13
consecutive 400/404/410 responses left `X-Credits-Remaining` unchanged, each carrying a non-zero
`X-Credits-Cost`). Add the header to a spend tally only *after* checking the status code.

## Rows per credit — the number that actually decides cost

| Call | Page cap | Credits/page | Rows per credit |
|---|---|---|---|
| `/v1/exchange/snapshots` | 5,000 | 1 | **5,000** |
| `/v1/markets/:id/snapshots` with `interval=` | 50,000 | 5 | up to 10,000 |
| `/v1/markets/:id/snapshots` raw | 5,000 | 5 | 1,000 |
| `…/snapshots?includebook=true` | 2,000 | 5 | 400 |

The page cap is the whole story for `includebook`: it doesn't cost more per call, it costs **2.5×
more calls** for the same number of rows.

All three caps are **enforced with a `400`, never a silent clamp** — the message names the ceiling
that applies. The one route that *does* clamp silently is `/v1/markets/metadata`: `limit=5000`
returns `200` with 1,000 rows (verified). Check the returned count there.

## When candles actually save credits — and when they save nothing

`interval=` is the biggest lever available, but only when a market's history exceeds one page.
Measured, one side (`side=UP`), whole market:

| Market | UP rows | Raw pages → credits | `interval=1m` | Saving |
|---|---|---|---|---|
| BTC **1d** (74k snapshots) | 37,150 | 8 → **40** | 1 call → **5** | **8×** |
| Weather daily (28k) | 13,966 | 3 → **15** | 1 call → **5** | **3×** |
| BTC **5m** (4.2k) | 2,077 | 1 → **5** | 1 call → **5** | **none** |

So the rule is **not** "use candles for anything over a few hours" — it is **"use candles when one
side exceeds 5,000 rows"**, i.e. when raw would need more than one page. On a 5m crypto window,
candles cost exactly the same and throw away detail.

**You can know before you spend.** `/v1/markets/history/recent` (1 credit) returns
`snapshot_count` per market. Halve it for one side, divide by 5,000 → the raw page count. If that
is 1, pull raw; if it's 8, use `interval=`.

`interval=` also composes with `from`/`to` (a 1-hour slice at `interval=1m` returned exactly 60
candles) and is **rejected with a `400` alongside `includebook=true`** — candles carry no ladder.
Note `limit` with `interval=` is only a *ceiling*: you get `window ÷ interval` candles, so raising
it to 50,000 on a 24-hour market still returns ~1,433. Set it high enough, not high for its own sake.

## Payload weight — measured, and smaller than folklore

200 rows, `side=UP`, six markets across five categories, bytes relative to a plain row:

| Mode | Multiplier | Verdict |
|---|---|---|
| `touchsize=true` | **1.08–1.09×** | Effectively free. Use it freely — it answers "how much size is at the best price" without the ladder. |
| `includebook=true` | **1.9× – 5.5×** (median ≈2.8×; heaviest on liquid crypto short-timeframe books, lightest on thin sports books) | Real but not enormous. The page-cap drop to 2,000 costs more than the bytes do. |

Some API error strings and older docs say `includebook` rows are "~10× heavier". **They are not** —
that figure was never measured. Quote the range above instead.

`side=UP` is exactly **2×** cheaper than both sides (1,433 vs 2,866 candles; 894 KB vs 1.79 MB) and
loses nothing when you only need the probability, since `DOWN mid ≈ 1 − UP mid` on the same tick.

`count=false` is **not** a cost lever. It doesn't change credits, and an interleaved timing test
(4 pairs, 2,000 rows) put it at **94% of `count=true` latency — inside the noise**. Its only
guaranteed effect is `total: null`. Use it when you don't need the total, not as an optimization.

## Cheapest path per job

| Job | Cheapest way | Cost |
|---|---|---|
| Live price of one market | `by-slug` → `/orderbook` | 2 |
| **Continuous** live prices | **WebSocket** (Pro+). Polling `/orderbook` is 1 credit per call and it is **not cached** — every 2 s for a day is **43,200 credits**, versus **0** on the socket. This is the single largest saving available. | 0/msg |
| Whole history of a long market | `interval=` candles, `side=UP`, one call | 5 |
| Whole history of a 5m window | raw, one page — candles save nothing here | 5 |
| Book at one past instant | `/api/snapshot` (3) beats a 1-row `/snapshots` page (5) | 3 |
| Settlement of many markets | `/v1/markets/metadata?market_id=id1,id2,…` — up to 1,000 markets in **one** call | 1 |
| Bulk market discovery | `/v1/markets/history` — unpaginated, unlimited rows, 1 credit (3,336 ATP markets in 19 s) | 1 |
| Deep history of a *high-cardinality* series | `/v1/markets/history/recent` + shrinking `before` cursor, 500/page | 1/page |
| Hyperliquid perp series | `/v1/exchange/snapshots` — 5,000 rows for **1** credit | 1 |
| Is the key alive? | `/v1/api-keys/validate` | 0 |

**The bulk-discovery ceiling is real.** `/v1/markets/history` has no pagination and **times out on
high-cardinality filters**. Measured: `crypto=BTC&timeframe=1d` (157 markets) 3 s ✅ ·
`category=sports&subcategory=ATP` (3,336) 19 s ✅ · `crypto=BTC&timeframe=1h` (3,745) 26 s ✅ ·
`timeframe=15m` ❌ >75 s · `timeframe=5m` ❌ >100 s. Rule of thumb: fine up to a few thousand
markets; for a short-timeframe crypto series page `history/recent` instead (500 rows, 1 credit,
~7 s per page).

## Budgeting a job before you run it

Free is **5,000 credits/month**, so the arithmetic matters:

- One 1d crypto market as candles: **5** credits. As raw pages: **40**.
- 50 settled 5m windows, raw, one side: 50 × 5 = **250**.
- A month of BTC 5m (≈8,640 markets) at one page each: **43,200** — 8.6× Free's whole allowance,
  and most of Pro's 50,000. Sample instead, or pull one candle series per day rather than per window.
- One backtest agent compile **and** run: 25 + 25 = **50**.

State the estimate before running anything above ~100 credits, and offer the cheaper shape.
