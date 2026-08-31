Score whether the response knows what things actually cost and picks the cheap path. Both halves
have a large, verifiable gap between the naive and the efficient answer, and a Free plan has only
5,000 credits per month, so a wrong recommendation is not a rounding error.

MUST:
- For the **continuous monitoring** half, not recommend polling `/v1/markets/:id/orderbook` as the
  ongoing solution without flagging its cost. That route is 1 credit per call and is **not
  cached**, so a 2-second poll is ~43,200 credits/day — over eight times the Free monthly
  allowance. Credit any response that quantifies this.
- Say that the **WebSocket** streams for **0 credits per message**, and that it requires **Pro or
  above** — Free has no WebSocket access. A response that recommends the WebSocket without noting
  Free can't use it fails, as does one that never mentions the socket at all.
- For the **history** half, recommend `interval=` candles over paging raw rows, and be right about
  why: a 1d crypto market is tens of thousands of rows per side, so raw needs ~8 pages (≈40
  credits) versus one 5-credit candle call.
- Not overstate `includebook=true`. If it comes up at all, the cost driver is the page cap
  dropping 5,000 → 2,000 (2.5× the credits per row). Claiming rows are "~10× heavier" is a
  measured falsehood — the real payload multiplier is roughly 1.9–5.5×.

SHOULD (each adds credit):
- Quote correct per-route costs: snapshots/trades 5 per page; summary and `/api/snapshot` 3;
  live/orderbook/by-slug/metadata/categories/history 1; `/health`, `/v1/public-stats` and
  `/v1/api-keys/validate` 0.
- Note that a cached response (`X-Cache: HIT`) still costs full price, so polling faster than a
  route's TTL buys nothing.
- Suggest `side=UP` (exactly 2× cheaper, and DOWN mid ≈ 1 − UP mid).
- Mention `touchsize=true` as the cheap way to get size at the best price (~1.08× a plain row)
  instead of the full ladder.
- Give the user a concrete credit estimate against their 5,000/month budget.
- Point out that on Free the practical live option is polling at a slow interval, or upgrading —
  rather than silently proposing something the tier forbids.

MUST NOT:
- Invent credit costs that contradict the published table (e.g. calling `/snapshots` 1 credit, or
  claiming Free is credit-exempt — every tier is metered).
- Claim Free can open a WebSocket connection.
- Recommend `count=false` as a way to save credits or time — it changes neither.
