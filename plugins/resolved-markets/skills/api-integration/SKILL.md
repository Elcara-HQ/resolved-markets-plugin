---
name: api-integration
description: >-
  Write code against the Resolved Markets REST API or WebSocket for Polymarket prediction-market
  orderbook data. Use when building a script, service, notebook, or data pipeline that calls
  api.resolvedmarkets.com; when handling the `X-API-Key` header, `rm_` keys, credits, rate limits,
  pagination or retries; when streaming live orderbooks over WebSocket; or when debugging a 400,
  401, 402, 403, 429 or 500 from the API. Also covers choosing query shapes that stay cheap —
  interval candles instead of raw pages, `side=UP` instead of both sides, and windowing long-lived
  markets.
---

# Resolved Markets — REST and WebSocket integration

For interpreting the data you get back, use the `market-data` skill. This one is about calling
the API correctly from code.

| Surface | URL |
|---|---|
| REST | `https://api.resolvedmarkets.com` |
| WebSocket | `wss://api.resolvedmarkets.com/ws/orderbook` |
| Keys / dashboard | `https://resolvedmarkets.com/api-keys` |
| Interactive docs | `https://resolvedmarkets.com/docs` |
| OpenAPI 3.1 spec | `https://resolvedmarkets.com/openapi.json` |

Full endpoint reference: `references/endpoints.md`.
Response field shapes: `references/response-shapes.md`.
WebSocket protocol: `references/websocket.md`.

## Establish what they're building first

Two questions decide most of the code, and guessing wrong means a rewrite:

1. **Live or historical?** Continuous prices → WebSocket (Pro+, 2 s push, no per-message credits).
   A finite pull → REST with `from`/`to`. Both → say so, they're different code paths.
2. **How much data?** A single lookup, a backfill of months, or a process that runs forever? This
   sets pagination, retry policy, and whether credits are a real constraint.

**Put them to the user with the `AskUserQuestion` tool** — one batched call, concrete options,
the recommended default first — rather than guessing or asking in prose. Ready-made option sets
for both, plus language, key storage, and the depth/market-count questions that decide what the
script costs to run, are in `references/clarifying-questions.md`.
Don't ask what the request already answers: "stream BTC prices to a CSV" needs no questions.

Then, only if the answer isn't already obvious from what they've said:

| Decision | Ask | Default |
|---|---|---|
| Language / runtime | Python, TypeScript, shell, something else? | Python |
| Depth per row | **Do they need the orderbook levels?** Best bid/ask, size at the touch (`touchsize=true`), or the full ladder (`includebook=true`)? | best bid/ask; `touchsize` is ~1.08× the bytes so add it freely — the full ladder caps pages at 2,000, i.e. 2.5× the credits per row |
| Market count | **How many markets does it cover?** One, a fixed recent sample, or a whole category over a date range? | one — confirm before fanning out; BTC 5m alone is 288 markets/day |
| Granularity | Every stored tick, or downsampled candles (`interval=`)? | candles for anything wider than a few hours |
| Where output goes | Printed, a file, a dataframe, a database? | print, then adapt |
| Key storage | Environment variable, secret manager, CI secret? | `RESOLVED_MARKETS_API_KEY` env var |

**Give a credit estimate before writing a backfill.** Snapshots and trades are 5 credits per page,
so "500 markets × ~3 pages ≈ 7,500 credits" is worth stating while the design is still changeable —
Free only has 5,000 a month.

**Confirm their tier if the plan needs it.** WebSocket needs Pro or above; sports, weather,
economics, social, equities and the exchange endpoints need Scale. Better to raise it now than to
hand over code that 403s.

## Authentication

Pass the key in the **`X-API-Key`** header on every request. Never put it in a URL query string.

```bash
curl -H "X-API-Key: rm_your_key_here" \
  "https://api.resolvedmarkets.com/v1/markets/live?crypto=BTC&timeframe=5m"
```

- Keys start with `rm_` and are shown **once**, at creation, on the dashboard.
- Read the key from the environment (`RESOLVED_MARKETS_API_KEY`). Never hard-code it, never echo
  it into logs, shared code, or a URL.
- `GET /health` and `GET /v1/public-stats` need no key.
- **Account management is browser-only.** Creating/revoking keys, `/v1/user/tier`, and payment
  endpoints require a signed-in browser session and **cannot** be called with an `rm_` key. Don't try
  programmatically — send the user to the dashboard.

**Liveness check: `GET /v1/api-keys/validate`.** It returns `{"valid":true,"label":…}` and costs
**0 credits** — it isn't behind the metering middleware at all. Use it as a script's start-up
check. Do **not** use `/v1/categories` for that; it costs 1 credit every run, which is a real tax
on Free's 5,000/month.

## Credits and tiers

Every metered request costs credits from a monthly allowance. **All tiers are metered, including
Free.** Only successful (2xx) responses are charged — but `X-Credits-Cost` is still *sent* on a
4xx, so tally it only after the status check (the client below does).

| Request | Credits |
|---|---|
| `/v1/markets/:id/snapshots`, `/v1/markets/:id/trades`, `/v1/wallets/:address/fills` | 5 |
| `/v1/markets/:id/summary`, `/api/snapshot` | 3 |
| Everything else metered (live, orderbook, by-slug, metadata, categories, history, exchange) | 1 |
| `/health`, `/v1/public-stats`, `/v1/api-keys/validate`, `/v1/backtest/templates`, `/v1/backtest/runs/*`, **every WebSocket message** | **0** |
| `/v1/backtest/agent`, `/v1/backtest/run` (and their `/v2/` twins) | 25 |

| Tier | Price | Monthly credits | Rate limit | WS conns | API keys | Categories |
|---|---|---|---|---|---|---|
| Free | — | 5,000 | 300/min | 0 | 2 | crypto only |
| Pro | $17/mo ($126/yr) | 50,000 | 300/min | 1 | 5 | crypto only |
| Scale | $49/mo ($360/yr) | 500,000 | 1,000/min | 5 | 10 | all |
| Enterprise | $549/mo | 5,000,000 | 3,000/min | 10 | 20 | all + teams |

**Every tier gets full orderbook depth and unlimited history.** The gate is *category*, not depth
or time, and **Free is crypto-only, not BTC-only** — all 7 coins (BTC, ETH, SOL, XRP, DOGE, HYPE,
BNB) and all timeframes. Sports, weather, economics, social, equities and the Hyperliquid exchange
endpoints start at Scale.

Prepaid credit packs are available without changing tier: $5 → 4,000 credits, $10 → 10,000,
$50 → 100,000.

**Read your tier straight off the response headers** — there is no API-key-callable tier endpoint.
`X-RateLimit-Limit` pins the row (300 / 1000 / 3000) and `X-Credits-Remaining` separates Free from
Pro, which share 300.

Full route-by-route table, rows-per-credit, and the cheapest call for each job:
`references/cost-model.md`.

### Reading the meter from browser JavaScript

Both credit headers are in `Access-Control-Expose-Headers`, so a cross-origin `fetch()` reads them
directly — no server-side proxy needed for a browser credit meter:

```js
const r = await fetch(url, { headers: { 'X-API-Key': key } });
r.headers.get('X-Credits-Cost');       // "5"
r.headers.get('X-Credits-Remaining');  // "4926435"
```

The full exposed set is `X-RateLimit-Limit`/`-Remaining`/`-Reset`, `X-Credits-Cost`,
`X-Credits-Remaining`, `X-Cache`, `X-Total-Count`, `X-Limit`, `X-Offset`, `X-Interval`,
`X-Row-Count`, `X-Format`, `X-Onchain-Enriched`, `X-Tier-Scope-Filtered` and `X-Key-Limit-Notice`.
Anything outside that list is invisible to browser JS even though curl and any server-side client
sees it.

### `X-Credits-Remaining` is a gauge, not a ledger

Every response carries `X-Credits-Cost` (this request, exact) and `X-Credits-Remaining` (balance
after). The remaining count legitimately **rises** on monthly refresh, credit-pack top-up, and
tier change, and it is eventually consistent — a reading can sit a few credits high while recent
spending persists (settles within ~30 s).

So: **sum `X-Credits-Cost` for an exact spend total. Never difference consecutive
`X-Credits-Remaining`.** The only always-authoritative reading is a `402`.

## Error handling

| Code | Meaning | Action |
|---|---|---|
| 400 | Bad/unknown parameter — the body lists `unknown_parameters` and `allowed_parameters`. Also an over-cap `limit`, or `interval`+`includebook` together | Fix the request; never retry unchanged |
| 401 | Missing/invalid key | Check the `X-API-Key` header |
| 402 | Credits exhausted | Stop. Retries won't succeed until top-up or refresh |
| 403 | `tier_not_allowed` (category/exchange gate, includes `upgrade_url`), `replay_locked` (Free replay quota), or `account_suspended` | Expected, not retryable — upgrade or pick another market |
| 404 | Unknown market, closed slug on a live-only route, or no exchange data in the last 60 s | Verify the ID; for exchange, retry shortly |
| 429 | Rate limited | Wait until `X-RateLimit-Reset` (epoch seconds), then resume |
| 500 | Usually a query timeout on an unwindowed pull of a months-long market | **Fix the query** (add `from`/`to` or `interval=`) rather than retrying it |
| 503 | Degraded or transient overload | Retry with exponential backoff |

All data endpoints are idempotent GETs, so retrying is safe where the table says to.

**`limit` over the page cap is a `400`, not a silent clamp.** The cap is mode-dependent:
5,000 raw · 2,000 with `includebook=true` · 50,000 with `interval=`. The error message names the
ceiling that applies. A page therefore never comes back quietly short.

## Writing efficient clients

- **Wide time windows → `interval=` candles**, one 5-credit call, never dozens of raw pages — but
  only once one side exceeds 5,000 rows (one page). Measured whole-market, one side: a 1d crypto
  market is 8 raw pages (40 credits) versus one candle call (5) — **8×**; a 5m window is a single
  page, so candles cost **exactly the same** and lose detail. `snapshot_count` from
  `history/recent` (1 credit) tells you which case you're in before you spend.
- **One side is usually enough** → `side=UP` (DOWN mid ≈ 1 − UP mid on the same tick).
- **`includebook=true` only when you need depth levels** — the page cap drops 5,000→2,000, so it
  costs **2.5× the credits** for the same row count (bytes are a milder 1.9–5.5×, measured). For
  "how much is at the touch", `touchsize=true` costs ~1.08× and is effectively free.
- **`count=false` is not a cost lever** — same credits, and measured at 94% of `count=true`
  latency, inside the noise. Use it when you don't need `total`, not to go faster.
- **Always window long-lived markets** with `from`/`to`. Unwindowed pulls on a live market
  silently cover only ~36 h.
- **Batch identity lookups**: `metadata?market_id=id1,id2,id3` in one 1-credit call instead of N —
  up to 1,000 markets. It is also the one route that **clamps silently** (`limit=5000` returns
  1,000 rows with a `200`), so check the returned count against your batch size.
- **Hyperliquid series are the cheapest data in the API**: `/v1/exchange/snapshots` returns up to
  5,000 rows for **1** credit — 5× the rows per credit of `/v1/markets/:id/snapshots`.
- **Bulk discovery**: `/v1/markets/history` is 1 credit for unlimited rows, but has no cursor and
  **times out on high-cardinality filters** (measured: ATP's 3,336 markets 19 s ✅, BTC 1h's 3,745
  26 s ✅, BTC 15m and 5m both time out). Page `history/recent` for those.
- **Page deep history with a `before` cursor, never `offset`** — `offset` is accepted and
  **ignored** on `/v1/markets/history/recent`. Expect ~1 row of overlap per cursor boundary;
  dedupe by `market_id`.

**Respect cache TTLs.** Polling faster than the TTL returns the same cached body (`X-Cache: HIT`)
and still costs credits: `/v1/public-stats` 5 s · `history/recent` 10 s · `/v1/markets/history`
30 s · `/summary` 15 s · `/api/snapshot` 5 s · `/api/snapshot/latest` 3 s ·
`/v1/exchange/orderbook` 1 s.

**The single largest saving in the API: stream instead of poll.** `/v1/markets/:id/orderbook` is
1 credit per call and is **not cached at all**, so polling one market every 2 s costs 43,200
credits/day — more than eight times Free's entire monthly allowance — while the WebSocket pushes
every 2 s for **0 credits per message**. Use it for anything continuous on Pro+. Protocol, auth
handshake, close codes and a working Python client: `references/websocket.md`.

## A minimal, correct client

```python
import os, requests

BASE = "https://api.resolvedmarkets.com"
S = requests.Session()
S.headers["X-API-Key"] = os.environ["RESOLVED_MARKETS_API_KEY"]

def rm_get(path, **params):
    r = S.get(f"{BASE}{path}", params=params, timeout=30)
    if r.status_code == 402:
        raise RuntimeError("Out of credits")
    if r.status_code == 429:
        raise RuntimeError(f"Rate limited until {r.headers.get('X-RateLimit-Reset')}")
    r.raise_for_status()
    rm_get.spent += int(r.headers.get("X-Credits-Cost", 0))   # exact; don't diff Remaining
    return r.json()

rm_get.spent = 0

# Start-up check — free, no credits burned.
assert S.get(f"{BASE}/v1/api-keys/validate", timeout=10).json()["valid"]
```

Before shipping anything, check `references/pitfalls.md` — several
documented behaviors (DESC ordering, empty 200s on wrong-case filters, ignored `offset`,
string-typed big integers) look like bugs and are not.
