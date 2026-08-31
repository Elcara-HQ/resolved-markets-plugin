Score whether the response scopes an expensive, under-specified request **before** spending the
user's credits. "BTC data for last week" is ambiguous in every dimension that sets cost: BTC 5m
alone is 288 markets a day (~2,016 for a week), and the answer differs by orders of magnitude
depending on whether the user wants top-of-book or the full orderbook ladder.

MUST:
- Ask clarifying questions **before** running a large pull. A response that immediately fans out
  across a week of markets, or that silently picks one interpretation and presents the result as
  *the* answer, fails.
- Ask **how much data** — which timeframe(s), and how many markets — rather than assuming. Credit
  any concrete framing of the scale problem (288 windows/day, ~2,016 markets/week).
- Ask whether the user needs the **orderbook** (depth levels) or just prices/top-of-book. A
  response that defaults to `includebook=true` without asking fails; defaulting to top-of-book and
  *saying so* is acceptable.
- Offer a **concrete default** with each question, so the user can accept the whole set at once.
  Bare open questions with no proposed answer ("what do you want?") score poorly.

SHOULD (each adds credit):
- Batch the questions into **one round** rather than asking serially, using a structured
  multiple-choice question tool where the host provides one (`AskUserQuestion`).
- Ask what the deliverable is — a written answer, a table, a file, a chart.
- State or estimate the **credit cost** of the options ("~5 credits with 1-minute candles vs a few
  hundred paging raw rows"), especially against Free's 5,000/month.
- Propose `interval=` candles as the cheap default for a week-long window instead of raw pages.
- Ask which timeframe series is meant (5m / 15m / 1h / 4h / 1d / hit-price), since "BTC" alone
  names six live series.

MUST NOT:
- Ask questions it could answer with a cheap lookup (whether BTC markets exist, what the current
  slug is, which subcategories are live) — those are 1-credit discovery calls, not questions.
- Interrogate the user with more than about four questions, or ask a second round before doing any
  work.
- Ask clarifying questions and then *also* run the expensive pull anyway before getting an answer.
