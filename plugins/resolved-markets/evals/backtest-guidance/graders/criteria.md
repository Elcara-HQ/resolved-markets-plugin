Score whether the response prevents the errors that make a prediction-market backtest report
profits that were never obtainable.

MUST:
- Say fills come from the executable side of the book — buy at the ask (`avg_best_ask` /
  `best_ask`), sell at the bid (`avg_best_bid` / `best_bid`). A response that fills at candle
  `close`, `mid_price`, or `vwap_mid` fails outright: those are all mid-derived and assume a
  zero spread.
- Warn that at a 0.20 entry the spread is a material cost, not a rounding error. Credit any
  concrete framing (round-trip cost roughly a third of mid in the 0.20–0.50 band, or a
  recommendation to restrict the universe to mid > 0.20).

SHOULD (each adds credit):
- Say to exclude rows where one side of the book is unquoted (`best_bid` or `best_ask` = 0).
- Say to window queries with `from`/`to` bounded by the market's `first_seen`/`last_seen`,
  rather than pulling unwindowed.
- Warn that a handful of 5m windows proves nothing — BTC 5m produces 288 windows per day, so
  the sample should be large.
- Mention resolving outcomes via market metadata (`resolved_outcome`) to score the trades.

MUST NOT:
- Present a fill at the mid or at `close` as acceptable.
- Claim the snapshot stream captures every price change — it is a ~50 ms sample that drops
  unchanged books, so a stop can be crossed between stored rows.
