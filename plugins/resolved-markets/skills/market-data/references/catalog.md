# Category catalog

Verified against production, August 2026. Subcategory and timeframe values are **case-sensitive exact strings** — URL-encode spaces (`subcategory=Hong%20Kong`). A wrong-case value (`hong kong`, `nyc`) returns an **empty 200, not an error** — it looks like "no data" but means "wrong filter string". The catalog evolves — when a filter unexpectedly returns nothing, confirm current values with `/v1/categories` plus an unfiltered `/v1/markets/live` pull rather than guessing.

| Category | Subcategories | Timeframes |
|---|---|---|
| `crypto` | `BTC`, `ETH`, `SOL`, `XRP`, `DOGE`, `HYPE`, `BNB` | `5m`, `15m`, `1h`, `4h`, `1d` (up/down windows, all 7 coins) + `hit-price` (daily strike ladders, BTC/ETH/SOL/XRP) |
| `sports` | Live: `ATP`, `WTA` (tennis), `NBA`, `NFL`, `EPL`. Historical-only: `FIFA` (World Cup, Jun–Jul 2026), `IPL` (cricket, ended Jun 2026) | `game` |
| `economics` | `FOMC` | `rates` (live), `meeting` (historical) |
| `weather` | 54 cities/regions by full name — `NYC`, `London`, `Tokyo`, `Seoul`, `Paris`, `Moscow`, `Miami`, `Chicago`, `Denver`, `Dallas`, `Austin`, `Houston`, `Atlanta`, `Seattle`, `Toronto`, `Madrid`, `Milan`, `Munich`, `Amsterdam`, `Helsinki`, `Warsaw`, `Ankara`, `Istanbul`, `Jeddah`, `Karachi`, `Lucknow`, `Kuala Lumpur`, `Singapore`, `Manila`, `Taipei`, `Busan`, `Beijing`, `Shanghai`, `Guangzhou`, `Shenzhen`, `Chengdu`, `Chongqing`, `Wuhan`, `Qingdao`, `Jinan`, `Zhengzhou`, `Tel Aviv`, `Cape Town`, `Wellington`, and multi-word `Hong Kong`, `Buenos Aires`, `Los Angeles`, `San Francisco`, `Mexico City`, `Panama City`, `Sao Paulo` — plus `Hurricane`, `Global`, `Arctic` | `daily-high`, `daily-low`, `event`, `seasonal` |
| `social` | `Elon` (weekly tweet-count ladders) | `weekly` |
| `equities` | `SPX`, `Index`, `StockUpDown`, `StockPrice`, `StockAbove`, `StockEvent`, `Earnings`, `KPI`, `IPO`, `Acquisition`, `Private`, `PredictionMarket`, `Commodity`, `Forex` | `1d`, `daily`, `weekly`, `monthly`, `quarterly`, `annual`, `earnings`, `event`, `comparison`, `leaderboard`, `valuation` |

Notes: crypto up/down series are continuous back-to-back windows (a new 5m market every 5 minutes, 288 per coin per day — history is large). Weather cities run one grouped event per day with temperature-bucket legs (`daily-high`/`daily-low`); `Hurricane`/`Global`/`Arctic` are event/seasonal markets. Equities `Commodity`/`Forex` cover WTI/gold/EURUSD-style up/down markets. Free/Pro tiers can only access `crypto`.

### Equities daily series — subcategory alone does not identify an instrument

`subcategory` + `timeframe` is **not** a unique key in equities. `SPX` + `1d` returns two economically different instruments that share every timestamp field, and picking the wrong one silently produces a wrong backtest:

| Slug pattern | Question | Outcome determined at | `end_date` |
|---|---|---|---|
| `spx-up-or-down-on-<month>-<day>-<year>` | "S&P 500 (SPX) Up or Down on Aug 6?" | The **4pm ET cash close** vs the prior close — the full session | `20:00Z` (16:00 ET) |
| `spx-opens-up-or-down-on-<month>-<day>-<year>` | "S&P 500 (SPX) **Opens** Up or Down on Aug 6?" | The **9:30 ET opening print** vs the prior close | `20:00Z` (16:00 ET) — *identical* |

Both carry the **same `end_date`** and (measured over 18 settled pairs) the same ~2.5 h resolution lag, so **no timestamp field separates them** — only the slug and `question` text do. Two consequences:

- Always disambiguate on `slug`/`question`, never on `end_date` or `timeframe`.
- On the `opens` series the outcome is **decided at 09:30 ET but the market keeps trading until 16:00 ET**. Every snapshot after the open is trading an already-settled question. If you are backtesting entries, that whole post-open period is not a forecast — filter it out or you are "predicting" a known result.

Other SPX series under the same subcategory: `spx-close-dec-<year>` (`timeframe=annual`, year-end close ladder) and `spx-hit-dec-<year>` (`timeframe=monthly`, threshold ladder). The same shape recurs across equities — one subcategory spans several slug families:

| Subcategory | Typical slug families | Timeframes |
|---|---|---|
| `SPX`, `Index` | `spx-up-or-down-on-…`, `spx-opens-up-or-down-on-…`, `spx-close-dec-…`, `spx-hit-dec-…` | `1d`, `annual`, `monthly` |
| `StockUpDown` | `<ticker>-up-or-down-on-…` | `1d` |
| `StockPrice`, `StockAbove` | `what-price-will-<ticker>-hit-…`, `will-<ticker>-close-above-…` | `monthly`, `daily` |
| `Earnings` | `<ticker>-earnings-…` | `earnings` |
| `IPO`, `Acquisition`, `Private`, `PredictionMarket` | event/valuation slugs | `event`, `valuation`, `comparison`, `leaderboard` |
| `Commodity`, `Forex` | `wti-…`, `xauusd-…`, `eurusd-…` up/down | `1d`, `daily`, `weekly`, `monthly`, `annual` |

**Enumerate before you trust a filter**: pull `/v1/markets/live?category=equities&subcategory=<X>` once and group by `slug` pattern. One filter pair can hide several instruments.

### Equities daily markets are pre-listed by a day or more — their lifetime is not their session

The stored lifetime of a daily equities market is **mostly pre-session**. Measured across stored SPX daily instances:

| Session day | Listed before `end_date` |
|---|---|
| Typical weekday | **26–32 h** (previous day, ~12:00–18:00 UTC) |
| Monday (weekend gap) | **≈77 h** — Monday's market lists on **Friday** |

So an unwindowed pull, or a `from`/`to` spanning `first_seen → last_seen`, blends a day or more of pre-session quoting into "intraday" data. On the listing day we measured only **5–9 snapshots/hour** with mid pinned at exactly `0.505` (a 0.50/0.51 stub), against **1,000–1,900/hour** during the session. Aggregated by hour, activity runs 328–408 snapshots/day/hour across 12:00–19:00Z and collapses to ~115 at 20:00Z — the close.

**Rule: window from `end_date`, never from `first_seen`.** For a US cash session (`end_date` = 20:00Z = 16:00 ET during EDT):

```bash
# The regular session only: 09:30–16:00 ET
"…/snapshots?from=2026-08-06 13:30:00&to=2026-08-06 20:00:00&side=UP&interval=5m"
# Include pre-market price discovery: end_date − 8h
```

`first_seen` is *our capture* time, not Polymarket's listing time — a collector gap can make it later than the true listing (one stored instance shows only 2 h of lead for that reason). Treat it as a lower bound on the market's life, and derive the session from `end_date`.

**Ladder structure — this governs every quantitative use:**
- **Weather temperature ladders are categorical**: the bucket legs of one event are mutually exclusive and **exactly one resolves Yes**. The per-leg Yes base rate is therefore **1/N** (~9% on an 11-leg NYC ladder, measured ≈91 Yes per 1,000 legs). "Backtest on 10 weather markets" means 10 lottery tickets, not 10 coin flips — model the ladder as one categorical outcome, or condition on the leg's price, never on a 50% prior.
- **Hit-price strike ladders are monotone thresholds, not categorical**: an ↑ strike resolves Yes if the price reached it, so *every* strike at-or-below the period's extreme resolves Yes together. Multiple Yes outcomes per ladder are normal; deep-OTM strikes sit near 0 with one-sided books by design.

