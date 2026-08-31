# Asking before you spend

Every metered call spends the user's credit allowance, and a wrong guess about *depth* or *how
many markets* is the difference between a 5-credit answer and a 2,000-credit one. This file is
the mechanics of asking well: when to ask, how to ask, and the exact option sets to offer.

## When to ask — and when not to

**Do not ask when the request already names the answer.** "What are the BTC 5m odds?", "who won
last night's Arsenal game?", "what categories exist?" are complete requests. Resolve and answer.
A clarifying question there is friction dressed up as diligence, and it is the more common
failure of the two.

**Ask before running when any of these is true:**

- The pull spans **more than a few hours** of market time.
- It would use **`includebook=true`** (full ladder), which is ~10× heavier per row and drops the
  page cap to 2,000.
- It covers **more than one market** — "BTC 5m for last week" is 2,016 markets, not one.
- The request is **vague about the artifact**: "get me BTC data", "analyse this market",
  "export the history", "backtest this idea".
- It is a **backtest** (see the second bank below — an unstated exit or universe decides the
  result, not the data).
- You would run it **more than a handful of times**, or write code that runs forever.

**Ask once, then commit.** One round of questions, then do the work. If the user answers "just
do whatever's sensible", take every default in this file and say which ones you took.

**Never ask a question whose answer you can look up.** Whether a subcategory exists, what the
current window's slug is, whether a market has settled — those are 1-credit calls, not questions.

## How to ask

**Use the `AskUserQuestion` tool when it is available.** Structured options let the user click
through in one pass; a prose wall of six questions usually gets one vague sentence back, or
nothing.

- **One call, batched.** Up to 4 questions per call. Ask everything that changes the request
  together — never one question, one answer, one more question.
- **2–4 options each**, concrete and mutually exclusive. Not "how much data?" but "one window /
  last 20 settled / last 7 days".
- **Put the recommended default first** and mark it `(Recommended)`. The user can always pick
  *Other*.
- **Say the cost in the option's `description`** where it differs materially — "≈5 credits" vs
  "≈200 credits" is the whole point of asking.
- **Header ≤ 12 characters** (`Depth`, `How many`, `Time span`, `Resolution`).

**When `AskUserQuestion` is not available** (plain API/chat context), ask as one short numbered
block, name the default for each, and end with "say *go* and I'll take the defaults."

## Question bank — data pulls

Pick only the rows that are actually undetermined. Defaults are the first option.

| Header | Question | Options (first = default) |
|---|---|---|
| `Depth` | **Do you need the orderbook itself, or just the price?** | **Top of book** — best bid/ask + mid, ~5 cr/page (Recommended) · **Touch size** — `touchsize=true`, adds shares available at the best price, still light · **Full ladder** — `includebook=true`, every level; ~10× heavier rows, page cap drops to 2,000 |
| `How many` | **How many markets?** | **Just this one** (Recommended) · **Last 20–50 settled windows** — enough for a distribution · **A date range** — say which; BTC 5m alone is 288 markets/day · **Every market in the category** |
| `Time span` | **Which period?** | **Live now** (Recommended for prices) · **This market's full lifetime** — `first_seen`→`last_seen` (Recommended for history) · **One exact past instant** · **A from/to range I'll give you** |
| `Resolution` | **How fine-grained?** | **1-minute candles** — one call, 5 cr (Recommended) · **15-second candles** · **Every stored tick** — ~20 Hz; dozens of pages, 5 cr each · **Just one summary number** — 3 cr |
| `Side` | **One side or both?** | **UP only** (Recommended — DOWN mid ≈ 1 − UP mid on the same tick) · **Both legs** — doubles the rows; only needed if you want each side's own liquidity |
| `Output` | **What should I hand you?** | **A written answer** (Recommended) · **A table** · **A CSV/JSON file** · **A chart** |

**Then state the cost before you run it.** Discovery is 1 credit; `/snapshots` and `/trades` are
5 per page. "That's roughly 40 pages — about 200 credits. Want me to narrow the window or sample
with candles instead?" is the sentence that saves a Free user 4% of their month.

**And check tier scope in the same breath.** Free and Pro are crypto-only. If the request is
sports, weather, economics, social, equities, or Hyperliquid exchange data, say Scale is required
*before* running it, not after a `403`.

## Question bank — backtests

A backtest request is almost never fully specified, and the unstated parts decide the result.
Propose the whole set at once so the user can accept it in one click rather than answering eight
questions in sequence.

| Header | Question | Options (first = default) |
|---|---|---|
| `Direction` | **Buying UP or DOWN?** | **UP** (Recommended) · **DOWN** · **Chosen per market by the signal** |
| `Exit` | **How does a position close?** | **Take-profit + stop-loss** (Recommended) · **Hold to settlement** — completely different risk profile · **Time stop** — close N seconds/minutes in · **Whatever the signal says — I'll specify** |
| `Universe` | **What's the sample?** | **Most recent 20–50 settled windows, one coin, one timeframe** (Recommended) · **A specific date range** · **Several coins/timeframes** — costs multiply |
| `Costs` | **Model fees and latency?** | **Yes — taker fees on, ~1s signal→fill lag** (Recommended) · **Fees only** · **Neither — idealised** (say so in the result) |

**Two things to state rather than ask**, because they change the strategy and not just the run:

- **A hypothesis is required.** If the user cannot say what they think the market gets wrong,
  the test has no hypothesis — say so before running it.
- **Below ~0.10 the spread is the trade.** Round-trip cost there is 46–99% of mid. Raise it
  before spending, not in the results section.

Also ask **what result would make this worth trading** — without a bar, a −2% result gets
reported as "promising".

## Question bank — writing code

Two answers decide most of the code, and guessing wrong means a rewrite:

| Header | Question | Options (first = default) |
|---|---|---|
| `Live/hist` | **Streaming or a finite pull?** | **Historical pull** — REST with `from`/`to` (Recommended) · **Live stream** — WebSocket, Pro+ required, 2s push, no per-message credits · **Both** — genuinely two code paths |
| `Scale` | **How much data does it move?** | **A single lookup** (Recommended) · **A months-long backfill** — sets pagination + retry policy · **A process that runs forever** — needs reconnect + rate-limit handling |
| `Language` | **What should I write it in?** | **Python** (Recommended) · **TypeScript/Node** · **Shell/curl** |
| `Key` | **Where does the API key live?** | **`RESOLVED_MARKETS_API_KEY` env var** (Recommended) · **A secret manager** · **A CI secret** |

Give a credit estimate **before** writing a backfill — "500 markets × ~3 pages ≈ 7,500 credits"
is worth saying while the design is still changeable, since Free only has 5,000 a month.
