---
name: backtesting
description: >-
  Backtest or simulate a Polymarket prediction-market strategy using Resolved Markets historical
  orderbook data, and evaluate whether a proposed strategy is testable at all. Use when asked to
  backtest, simulate, or historically evaluate a trading idea on prediction markets; to model
  entries, exits, fills, slippage or transaction costs; to pick a market universe for a study; or
  to check whether a historical edge is real. Prevents the two errors that silently produce
  confident wrong results: filling at candle `close` (which is mid-derived and assumes a zero
  spread) and entering at a market's first snapshot (which is often a placeholder book, not a
  tradeable price).
---

# Backtesting with Resolved Markets data

Read `references/lifecycle.md` and
`references/pitfalls.md` before designing any study. The failure mode here
is not an error message — it is a backtest that runs cleanly and reports profits that were never
obtainable.

**Access path:** if `resolvedmarkets` MCP tools are available use them (`query_snapshots`,
`get_trades`, `get_market_metadata`, `list_historical_markets`); otherwise call REST and read
`references/endpoints.md` first. Resolved Markets also ships a hosted
visual Strategy Builder and an AI Backtest Agent at `https://resolvedmarkets.com/backtest` —
point the user there when they want a UI rather than code.

## Understand the strategy before you test it

A backtest request is almost never fully specified, and the unstated parts are exactly the ones
that decide the result. **Ask before running, not after** — a simulation built on the wrong
assumptions looks just as convincing as a correct one.

Work through these. Propose a concrete default for each so the user can accept the whole set at
once rather than answering six questions:

| What you need | Ask | Reasonable default |
|---|---|---|
| **The claim being tested** | What do you believe the market gets wrong? | — no default; if they can't say it, the test has no hypothesis and you should say so |
| **Direction** | Buying UP or DOWN — and is that fixed, or chosen per market? | UP |
| **Entry trigger** | A price level, a spread/liquidity condition, elapsed time in the window, or an underlying move? | price threshold on `mid_price` |
| **Exit** | Take-profit, stop-loss, time stop, or hold to settlement? | take-profit + stop-loss; hold-to-settlement if unstated |
| **Universe** | Which coin/category, which timeframe, how many markets, what date range? | one coin, one timeframe, most recent 20–50 settled markets |
| **Position size** | Fixed stake per trade, or scaled? | fixed $10–100 — enough that depth matters, small enough to fill |
| **Costs** | Include taker fees? What latency between signal and fill? | fees on; ~1s lag |
| **Success bar** | What result would make this worth trading? | — ask; it stops a −2% result being reported as "promising" |

**Push back on three things specifically, before running anything:**

1. **A strategy that buys below ~0.10.** The round-trip spread there is 46–99% of mid (see Rule 2).
   Say so up front — it usually changes the strategy rather than the backtest.
2. **A sample of a handful of markets.** BTC 5m produces 288 windows a day; ten of them prove
   nothing. Agree a sample size before spending credits, not after seeing a flattering number.
3. **An unstated exit.** "Buy at 0.20" without an exit is not a strategy. Hold-to-settlement is a
   legitimate answer, but make it an explicit choice — it has a completely different risk profile
   from a 0.60 take-profit.

**Confirm the shape of the answer too.** A win rate, a P&L curve, a per-trade table, and "is this
edge real?" need different work. Ask which one they want before producing all four.

## Rule 1 — candle OHLC is mid-only. Never fill at `close`.

On an `interval=` response, `open`, `high`, `low`, `close` and `vwap_mid` are **all computed from
`mid_price`**. The only fields carrying real quotes are `avg_best_bid` and `avg_best_ask`.
A backtest that fills at `close` assumes you crossed a zero spread. It will not error — it will
report confident, wrong profits.

| Action | Field (candles) | Field (raw rows) |
|---|---|---|
| Buy / enter long | `avg_best_ask` | `best_ask` |
| Sell / take profit / exit | `avg_best_bid` | `best_bid` |
| Mark-to-market only | `close` / `vwap_mid` | `mid_price` |

## Rule 2 — on cheap tokens the spread *is* the trade

Measured over ~1.4 M two-sided snapshots across all categories:

| Mid price band | Avg spread | Selling at bid loses (% of mid) | Round-trip cost (spread ÷ mid) |
|---|---|---|---|
| < 0.05 | 0.019 | **49.4 %** | **98.7 %** |
| 0.05 – 0.10 | 0.053 | 37.8 % | 75.5 % |
| 0.10 – 0.20 | 0.065 | 23.3 % | 46.5 % |
| 0.20 – 0.50 | 0.118 | 16.9 % | 33.8 % |
| 0.50 – 0.80 | 0.126 | 10.4 % | 20.8 % |
| > 0.80 | 0.044 | 2.5 % | 4.9 % |

Read the last column as: on a sub-0.05 token, a buy-then-sell round trip costs ~99% of the
position's mid value — the probability must roughly **double** just to break even. A take-profit
written as "exit at mid 0.10" can fill near 0.04.

**Below ~0.10, spread almost always exceeds any edge a signal provides.** Either model fills at
bid/ask explicitly, or restrict the universe to mid > 0.20. If a user's strategy buys long-shot
tokens, say this before running anything.

## Rule 3 — gate on book *quality*, not book existence

- **Skip rows where `best_bid = 0` or `best_ask = 0`.** That side was unquoted. A `mid_price` of
  0.9965 on a bids-only book is not a fill you can get, and a position cannot be closed on a row
  with no bid at any price.
- **Skip placeholder books.** Several series open with a stub quote long before they are
  tradeable — weather ladders sit at 0.01/0.99 for the first ~2 h, equities dailies sit at a
  0.505 stub for hours at 5–9 snapshots/h versus 1,000+/h in session. A naive "buy at open"
  backtest buys Yes at 0.99 or 0.505 and calls it an entry.
- Practical filters: drop snapshots with `spread` > ~0.1, or start the entry window at
  `end_date − N h` for the category. See `references/lifecycle.md` for per-category timing.

## Rule 4 — size against real depth, not against the touch price

`avg_bid_depth`/`avg_ask_depth` (candles) and `bid_depth_total`/`ask_depth_total` (raw) are
**whole-book totals in dollars**. For "how much could I actually fill at the best price", request
`touchsize=true` → `best_bid_size` / `best_ask_size`, **in shares**. That is far lighter than
pulling ladders. Only use `includebook=true` when your size genuinely exceeds the touch — those
rows are ~10× heavier and the page cap drops to 2000.

The best level is thinner than people assume: at stop-crossing instants it holds a median of ~54
shares. A $10 stake exceeds it 19% of the time, $100 74%, $1,000 99.7%. If the user is modelling
anything above a token stake, walk the ladder or say the fill assumption is optimistic.

## Rule 5 — the snapshot stream is a sample; the trade tape is the record

Capture stores at most one row per 50 ms per token and drops unchanged books. The median
consecutive row pair is **109 ms apart and spans ~28 applied book events**; 26% of pairs are
>150 ms with 10+ events. So a backtest walking stored rows steps *over* prices that genuinely
existed — a stop can be crossed and never observed.

`get_trades` (`/v1/markets/:id/trades`) is a genuinely independent instrument: a separate
unthrottled stream carrying Polymarket's own event timestamps. **Merge it into any exit walk.**
Structurally, the tape can only move an exit *earlier*, never later — so if adding it makes
results worse, that is over-optimism being removed, not a regression.

Caveat: the tape is as-observed. An empty tape (`total: 0`) on an old market is normal; verify
coverage before treating it as complete.

## Rule 6 — pick the universe from stats, and window every query

- Select markets from `list_historical_markets` / `get_market_summary`, which read pre-aggregated
  stats. Leave a settle buffer of ~1 day so `resolved_outcome` exists.
- **Always pass `from`/`to` bounded by the picked markets' `first_seen`/`last_seen`.** Unwindowed
  pulls on long-lived markets are slow, may time out (`500`), and on a live market silently cover
  only ~36 h.
- Resolve outcomes in bulk with `get_market_metadata` (comma-separated IDs, ~50 per call), and
  **verify the returned count equals the batch size** — a short count means truncation or unknown
  IDs, not "no more data". That endpoint has a hard `limit` cap of 1000 (default 100) and
  **silently clamps** above it.

## Sanity checks before reporting a result

Run these against any backtest output, including one the user wrote themselves:

- Were fills taken at `best_ask` (buy) and `best_bid` (sell), or at a mid? A mid-filled result is
  not a result.
- What fraction of entries were below mid 0.20? If it is high, restate the P&L after spread.
- Were one-sided-book rows excluded?
- Did the entry window start at a placeholder phase for that category?
- Does the trade count look implausibly high for the window? Over-trading is the usual symptom of
  an entry condition that matches nearly every snapshot.
- Is the sample one market or many? Crypto up/down series produce 288 windows per coin per day —
  a single window proves nothing.
