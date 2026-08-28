# Market lifecycle — when the numbers are real

A market's stored life has phases, and two naive assumptions silently corrupt analysis: "enter at the first snapshot" and "`end_date` = trading stops." Measured behavior (August 2026; treat figures as ≈):

| Series | Opens (before `end_date`) | Book becomes usable | `end_date` means | Resolution (`resolved_at`) lands | Capture continues |
|---|---|---|---|---|---|
| Crypto up/down (5m–1d) | Window length + ~50 s (pre-subscribe; these markets trade pre-open) | Immediately | Window **expiry** = settlement | Minutes after expiry | ~1 min past expiry |
| Crypto hit-price | Listed for the day (settles midnight ET) | Immediately; deep-OTM strikes stay one-sided/empty **by design** | Settlement | After midnight ET | Through settlement |
| Weather daily-temp | ≈35 h (today + tomorrow are listed) | **Not at open.** First ~2 h the book is a 0.01/0.99 placeholder — a naive "buy at open" backtest buys Yes at 0.99. Prices converge to the outcome from ≈ `end_date` − 5 h | **Nominal day marker** (12:00 UTC on the labeled date) — trading and capture continue well past it | ≈17–24 h **after** `end_date` | ≈17 h past `end_date`, until resolution |
| Sports game | Days–weeks ahead | Liquid well before kickoff | Scheduled **kickoff**, not game end — the market trades in-game after it | ≈2–3 h after kickoff | Through game end |
| Equities **daily** (`SPX`/`StockUpDown`/`Commodity`/`Forex`) | **26–32 h** before (≈77 h over a weekend) | Not at listing — first hours are a `0.505` stub at 5–9 snaps/h vs 1,000+/h in session | The **16:00 ET cash close** (`20:00Z`) | ≈2.5 h after `end_date` | To the close |
| Equities (event/valuation) / economics / social | Weeks–months ahead | Varies; thin far from the event | Event settlement date | At event settlement | Through settlement |

Practical rules that follow:
- **Equities dailies need their own handling** — see the two "Equities daily series" sections in `catalog.md` (same directory) — one subcategory hides several instruments, and these markets list 26-32 h before their session.
- **Backtests must gate on book quality, not existence**: skip snapshots where `spread` > ~0.1 or one side is a bound-clamp placeholder, or start the entry window at `end_date − N h` for the category.
- **Never use `end_date` as "data ends"** — take the real data range from `first_seen`/`last_seen` on `history/recent`, and clamp every `from`/`to` window inside it (an out-of-range window returns an empty page with **no error**).
- Post-`end_date` rows are real and meaningful for weather/sports (the in-game / pre-settlement phase) — not junk to filter.

