---
name: market-data
description: >-
  Look up prediction-market odds, prices, and history on Polymarket via Resolved Markets.
  Use for: the current implied probability of a market, finding markets by category or coin,
  price history and OHLC candles, executed trades, aggregate stats, and how a settled market
  resolved. Covers crypto up/down and hit-price markets (BTC, ETH, SOL, XRP, DOGE, HYPE, BNB),
  sports, weather, economics, social, and equities, plus Hyperliquid perpetual-futures books.
  Trigger on questions about Polymarket odds or prices, what a prediction market is trading at,
  implied probability of an outcome, prediction-market price history, who won a market, or
  finding which prediction markets exist.
---

# Resolved Markets — market data

Resolved Markets captures Polymarket CLOB orderbooks at high frequency (event-driven, up to
~20 Hz per token) and stores every snapshot, trade, and settlement result. This skill covers
reading that data and interpreting it correctly.

**What it is:** market microstructure and price history for prediction markets — implied
probabilities over time, liquidity, spreads, fills, outcomes.
**What it is not:** a trading venue (read-only; no orders, no wallet actions), a complete
Polymarket mirror (politics/elections are **not** collected), or an on-chain explorer.
If a market the user wants is outside the catalog, say so plainly rather than substituting a
similar one.

Resolved Markets is an independent data platform and is **not affiliated with Polymarket**.

## Which access path do you have?

Check once, at the start, then stay on that path.

1. **MCP tools available** (names like `list_markets`, `get_orderbook` from the `resolvedmarkets`
   server) — **use them**. Each tool description already carries its full parameter list, output
   shape, tier gates, and credit cost. Do not restate those here; this skill supplies the
   judgment layer instead: which tool answers which question, and how to read the result.
2. **No MCP tools** — call the REST API directly over HTTPS with an `X-API-Key: rm_...` header
   against `https://api.resolvedmarkets.com`. Read `references/endpoints.md`
   before your first call, and `references/response-shapes.md` before
   parsing a response.
3. **Neither** (no connector, no key) — run `/resolved-markets:setup`.

Everything below applies to both paths. Where a step differs, the REST equivalent is named in
parentheses.

## Scope the request before you spend

**Answer simple questions immediately.** "What are the BTC 5m odds?", "who won last night's
game?", "what markets exist?" are unambiguous — resolve and answer. Asking a clarifying question
there is friction, not diligence.

**Ask first when a wrong guess would waste the user's credits or produce the wrong artifact.**
Concretely, ask before you run when the request:

- spans **more than a few hours**, or **more than one market** ("BTC 5m for last week" is 2,016
  markets, not one);
- would need the **full orderbook ladder** (`includebook=true`) rather than top-of-book;
- is **vague about the artifact** — "get me BTC data", "analyse this market", "export the
  history";
- would be run more than a handful of times.

**Ask with the `AskUserQuestion` tool when it is available** — one batched call, up to 4
questions, 2–4 concrete options each, the recommended default first and marked
`(Recommended)`, with the credit cost in the option description where it differs materially.
One round, then commit and do the work. Where the tool isn't available, ask as a single short
numbered block naming the default for each.

The two that are wrong most often, so ask them explicitly rather than assuming:

- **"Do you need the orderbook itself, or just the price?"** — top of book *(default)* / size at
  the touch (`touchsize=true`, ~1.08× the bytes — effectively free) / full ladder
  (`includebook=true`, page cap drops 5,000→2,000, so 2.5× the credits per row).
- **"How many markets?"** — just this one *(default)* / the last 20–50 settled windows / a date
  range. BTC 5m alone is 288 markets a day.

| Decision | Ask | Default if they don't care |
|---|---|---|
| **Which market** | Coin + timeframe, a slug, or a date/event? | Current window of the named series |
| **Time span** | Live now, one past instant, or a range? | Live for prices; the market's full lifetime for history |
| **Resolution** | One summary number, a candle series, or every stored tick? | `interval=1m` candles **when one side exceeds 5,000 rows** (8× cheaper on a 1d market); raw is the same price and more detailed below that |
| **Depth** | Best bid/ask only, size at the touch, or the full ladder? | Top-of-book. `touchsize=true` is ~1.08× the bytes, so add it freely; **only add `includebook=true` if they need levels** — the page cap drops 5,000→2,000, i.e. 2.5× the credits per row |
| **Side** | UP only, or both legs? | `side=UP` — DOWN mid ≈ 1 − UP mid on the same tick |
| **Scale** | One market, or a series across many windows? | One, then confirm before fanning out — BTC 5m alone is 288 markets/day |

Ready-made option sets, phrased for `AskUserQuestion` and covering output format too:
`references/clarifying-questions.md`.

**Never ask what you can look up.** Whether a subcategory exists, what the current window's slug
is, whether a market settled — those are 1-credit calls, not questions.

**Say what it will cost before a large pull.** Discovery is 1 credit; snapshots and trades are 5
per page. "That's about 40 pages, roughly 200 credits — want me to narrow the window or sample
with candles instead?" is a better move than silently spending it.

Full verified cost table, rows-per-credit, and the cheapest route for each job:
`references/cost-model.md`. Four things from it that change what you
call, every time:

- **Continuous live prices belong on the WebSocket, not a poll.** `/orderbook` is 1 credit per
  call and is **not cached**, so polling one market every 2 s is 43,200 credits/day; the socket is
  0 per message.
- **A cache `HIT` still costs full price** — polling faster than a route's TTL buys nothing.
- **`/api/snapshot` (3) beats a 1-row `/snapshots` page (5)** for the book at one past instant,
  and **`/api/snapshot/latest` is only 1**.
- **`/v1/exchange/snapshots` returns up to 5,000 rows for 1 credit** — the cheapest time series in
  the API, 5× the rows per credit of `/v1/markets/:id/snapshots`.

**Check tier scope before promising anything.** Free and Pro are crypto-only. If someone asks for
sports or weather data on a Free key, say so up front rather than after a `403`.

## Task router

Match the question to the call before improvising.

| The user wants | Do this | Credits |
|---|---|---|
| Current price/odds of a market | `get_market` (slug) → `get_orderbook`; quote the UP `midPrice` | 2 |
| "What markets exist?" / counts | `list_categories`, then filtered `list_markets` | 1–2 |
| Price history / a chart | `query_snapshots` with `side=UP` and an `interval` (`1m`, `15s`, …) | 5 |
| Book state at an exact past moment | `get_snapshot` (`timestamp`, ≤1 h lookback) or `query_snapshots` with `from`/`to` | 3–5 |
| Who won / settlement result | `get_market_metadata` → `resolved_outcome` | 1 |
| Executed trades | `get_trades` | 5 |
| One-number stats (avg spread, price range) | `get_market_summary` | 3 |
| Find old markets (last week, a specific day) | `list_historical_markets` — **but see the paging gap below** | 1/page |
| All legs of an event (fixture, temperature ladder, strike ladder) | `get_market_metadata` with `neg_risk_id`, or `group_by_event` | 1 |
| Hyperliquid perp book (compare to spot) | `get_exchange_orderbook` / `get_exchange_snapshots` (Scale+) | 1 |
| Is data flowing / pipeline freshness | `get_system_stats` | 1 |

**Known gap — deep history paging.** `list_historical_markets` does **not** expose `since`,
`before`, `status`, or `order`. Cursor-paging months back therefore requires REST:
`GET /v1/markets/history/recent` with a shrinking `before` cursor. If the user needs history
older than the tool's default window and you only have MCP, say so and either fall back to REST
with a key or narrow the request. Do not fake it with `offset` — that parameter is accepted and
**silently ignored** on this route.

## Resolving a market's identity

Never invent or recall an ID. Get it from a lookup, every time.

- Markets are keyed by **`conditionId`** (`0x…`); tokens by **`tokenId`**.
- **One ID, four spellings.** The same condition ID is `conditionId` on live surfaces,
  `market_id` in historical rows and metadata queries, bare `:id` in REST paths, and `marketId`
  on `/api/snapshot`. Live surfaces use camelCase, stored surfaces snake_case. Different names,
  same value.
- Slugs (`btc-updown-5m`) are human-friendly aliases — resolve with `get_market`.
- **Slug epochs are the window's START time.** Never derive an expiry from a slug; take it from
  `endDate` / `end_date`.

Chain discovery output straight into data calls:

| Value you hold | Comes from | Feed into |
|---|---|---|
| `conditionId` / `market_id` | live list, metadata, by-slug, history rows | every per-market tool |
| `neg_risk_id` | metadata, live `negRiskMarketID` | `get_market_metadata` → all legs of an event |
| `first_seen` / `last_seen` | history rows, summary | `from`/`to` windows; `last_seen` is the settlement book |
| `tokenId` / `token_id` / `asset_id` | live, snapshots, trades | all one ID space — the snapshot↔trade join key |

**Timestamps round-trip as-is.** Response timestamps (`"2026-08-04 22:06:01.192"`) are UTC and
can be passed straight back as `from`/`to`/`timestamp`. ISO 8601 and bare dates (`2026-08-04`)
are equally accepted. Malformed values return `400`, not wrong data.

## Core data model

- Every market has two tokens: **UP** (`outcome_index` 0) and **DOWN** (`outcome_index` 1),
  each with its own orderbook. **UP is always `outcomes[0]`** — on a Yes/No market `side=UP`
  *is* Yes; on a team-name market UP is the first-listed team.
- Prices are probabilities in [0, 1]. Sizes are shares. Depth totals are notional dollars.
- **A token's mid price IS the market-implied probability.** UP `midPrice` 0.605 = "60.5%
  chance of Up". Quote the UP/first-outcome token by default.
- UP and DOWN **mids** complement (`up.mid + down.mid ≈ 1.0`), but their **books do not
  mirror** — depths, spreads and levels are independent. Never derive one side's liquidity
  from the other.
- Very large integers arrive as **JSON strings** (`snapshot_count`, `sequence_number`, per-side
  `snapshots` in summary). Parse accordingly.

### Reading the numbers honestly

- **A missing book side clamps to the outcome bound** — Polymarket's own convention, and it
  applies to `spread` as well as `mid`:
  `mid = (bestBid‖0 + bestAsk‖1) / 2` and `spread = (bestAsk‖1) − (bestBid‖0)`.
  Near settlement a winning token is bids-only around 0.99 → mid ≈ 0.995 and spread ≈ 0.01.
  `best_bid`/`best_ask` stay **raw**, where `0` means *that side was unquoted*, not "free".
  Never recompute either number as a raw average of the quoted sides.
- **Gate on `best_bid > 0 && best_ask > 0` before calling a spread "tight".** On a one-sided
  book the spread is a distance to the outcome bound, not a dealer's bid–ask. A bids-only book
  at 0.99 reports spread 0.01 — arithmetically tight, economically meaningless: there is no
  offer.
- Tight spread + deep book = liquid and trustworthy. Wide spread = the quote is soft; **say so
  when you report it.**
- A mid pinned near 0.995 / 0.005 means the market is effectively decided. That is signal.
- `crypto_price` on crypto rows is the underlying spot at capture time — use it to explain
  *why* a market moved.
- **A `sequence_number` jump is NOT a missed update.** It counts book events *applied*, not rows
  stored; capture keeps at most one row per 50 ms and drops unchanged books, so 98.4% of adjacent
  stored rows jump by more than 1. It resets to 1 on re-subscribe and is `0` on backfilled rows.
  Never build gap detection on it — it would report ~98% loss on healthy data. To see what
  happened inside a gap, read the trade tape (`get_trades`), which is unthrottled and independent.

## Categories and filters

Six categories: `crypto`, `sports`, `economics`, `weather`, `social`, `equities`.
Full subcategory and timeframe lists: `references/catalog.md`.

**The catalog is a snapshot; the live API is the source of truth.** These files ship with the
plugin and change only when it is updated, while coverage grows continuously — new sports leagues,
new weather cities, new equities series. So when the catalog and a live response disagree, the live
response wins: `list_categories` and an unfiltered `list_markets` are always current. Treat a
subcategory the catalog doesn't list as plausibly real rather than a typo, and check before telling
the user it doesn't exist.

Two rules that prevent most "there's no data" mistakes:

1. **Filter values are case-sensitive exact strings.** A wrong-case value (`nyc`, `hong kong`)
   returns an **empty 200, not an error**. On an empty result, suspect the filter string first —
   confirm with `list_categories` and an unfiltered `list_markets` before concluding the data
   doesn't exist.
2. **`timeframe` is a per-config discriminator, not a time cadence.** It is `5m`/`1h` for crypto
   up/down, but also `hit-price`, `game`, `rates`, `daily-high`, `event`, `earnings`,
   `valuation`, `quarterly`, `leaderboard`, and more. 21 distinct values are live. Discover them;
   don't assume.

**An out-of-tier list filter returns `200 []`, not `403`.** So an empty result means either
"no markets" or "not your tier". Free and Pro are **crypto-only** (all 7 coins, all timeframes —
not BTC-only); sports/weather/economics/social/equities and the Hyperliquid exchange endpoints
need Scale or Enterprise.

## Common workflows

Ten worked recipes — current price, the market live at a past instant, deep-history walking,
studying one market end to end, reassembling a grouped event, settlement audits, weather, sports,
market-vs-underlying, and building a resolved dataset — are in
`references/recipes.md`. Read it when a request needs more than a single
lookup.

Two lifecycle facts worth knowing before you quote a historical price at all:

- **`end_date` is not "data ends", and it does not mean the same thing in every category.**
  Crypto = expiry/settlement. Sports = scheduled kickoff (the market trades in-game after it).
  Weather = a nominal noon-UTC day marker, with settlement ≈17–24 h later. Take the real data
  range from `first_seen`/`last_seen`.
- **A window outside `[first_seen, last_seen]` returns an empty page with no error.** Clamp
  every `from`/`to` inside it.

Full lifecycle table (when each series opens, when its book becomes usable, when it settles):
`references/lifecycle.md`.

## Reporting rules

1. **Resolve identity first, never fabricate.** IDs and slugs come from a lookup.
2. **Quote the UP mid as the implied probability**, and qualify soft quotes — wide spread, thin
   book, one-sided book — rather than presenting them as firm.
3. **Report markets by identity**: slug + question + end date, not a bare hex ID, so the user can
   act on the answer.
4. **On an empty 200, suspect the filter string** before concluding the data doesn't exist.
5. **Window long-lived markets**, and use `interval=` candles once one side exceeds 5,000 rows —
   one call instead of dozens of pages (measured 8× cheaper on a 1d crypto market, but *no*
   saving on a 5m window, which fits in one page). `snapshot_count` from `history/recent` tells
   you which case you're in for 1 credit.
6. **Mind the user's credits.** Every call spends their allowance. Prefer 1-credit discovery
   calls; don't fan out speculatively. If they have their own pipeline for the same data and told
   you to use it, use that.
7. **Ask before a big or ambiguous pull, not after.** Depth (`includebook=true`?) and market count
   are the two that silently multiply cost — put them to the user with `AskUserQuestion` and a
   recommended default. One round of questions, then commit.
8. **When results look wrong, check `references/pitfalls.md`** before
   declaring data missing. Most anomalies there are documented, intended behavior.
