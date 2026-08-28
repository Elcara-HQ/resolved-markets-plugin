Score whether the response distinguishes "not covered" from "not in my snapshot". This case
pairs a category that IS collected (tennis: ATP and WTA) with one that is NOT (Formula 1),
so a response cannot score well by answering yes to everything or no to everything.

MUST:
- Answer **yes** for tennis, and name ATP and/or WTA. Saying tennis is unavailable fails.
- Answer **no**, or explicitly "not found / not collected", for Formula 1. Inventing F1
  markets, subcategories, or slugs fails outright.

SHOULD (each adds credit):
- Verify against the live service (`list_categories` / `list_markets`, or `/v1/categories`)
  rather than answering purely from memory or a static table.
- Note that coverage grows over time and the shipped catalog is a snapshot, so the live API
  is authoritative when the two disagree.
- Mention that non-crypto categories such as sports require the Scale tier or above.

MUST NOT:
- State flatly that a category "does not exist" without having checked, when checking was
  available.
- Substitute a different sport for Formula 1 and present it as what the user asked for.
