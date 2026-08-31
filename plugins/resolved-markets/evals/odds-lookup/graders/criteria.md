Score the response on whether it reads prediction-market data correctly. Each point is
pass/fail; a response that answers fluently but violates any MUST is wrong, not merely
incomplete.

MUST:
- Report the probability from the UP token's **mid price**, stated as a percentage or an
  explicit 0–1 probability. A response that quotes only a raw bid or ask as "the odds" fails.
- Identify *which* market it is beyond a bare hex id — slug, question, or expiry time. A
  response that answers with only a `0x…` conditionId fails.
- If it mentions the spread or liquidity at all, it must not describe a one-sided book as
  tight or liquid. A book with `best_bid` or `best_ask` equal to 0 means that side is
  **unquoted**, not free.

SHOULD (each adds credit):
- Qualify how firm the quote is — spread width, depth at the touch, or whether the book is
  thin — rather than presenting a bare number as certain.
- Note that BTC 5m windows roll continuously, or disambiguate when more than one market is
  live for the slot (the sooner `expiresIn` is the current window).

MUST NOT:
- Stop to ask clarifying questions instead of answering. This request is unambiguous and cheap
  (~2 credits) — resolving the current window and quoting it is the correct behavior. Asking about
  depth, market count, or time span here is friction, not diligence, and fails this criterion.
- Recompute a mid as a plain average of bid and ask when one side is missing.
- Claim Resolved Markets is affiliated with Polymarket.
- Invent a conditionId, slug, or price not present in tool output.
