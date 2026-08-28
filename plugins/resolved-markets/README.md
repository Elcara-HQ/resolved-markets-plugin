# Resolved Markets plugin

Live and historical Polymarket prediction-market orderbook data for Claude.

## Components

| Path | What it is |
|---|---|
| `.mcp.json` | The hosted connector at `https://mcp.resolvedmarkets.com/mcp`, authenticated with OAuth — no API key required. |
| `skills/market-data/` | Odds, market discovery, price history, trades, settlement outcomes, and how to read the numbers honestly. |
| `skills/backtesting/` | Designing a strategy simulation that doesn't fill at prices nobody could get. |
| `skills/api-integration/` | Calling the REST API and WebSocket from code: auth, credits, rate limits, pagination, retries. |
| `skills/setup/` | `/resolved-markets:setup` — connect and verify. |
| `references/` | Endpoint reference, response shapes, category catalog, recipes, lifecycle, WebSocket protocol, pitfalls. Loaded on demand. |

## Design notes

**The skills own judgment; the MCP tools own parameters.** Each connector tool already documents
its own inputs, outputs, tier gates and credit cost. The skills deliberately don't restate that —
they cover which tool answers which question, how to interpret the result, and the traps.

**Every skill works with or without the connector.** If MCP tools are present they're used; if
not, the same workflow runs against the REST API with an `X-API-Key` header. That's why
`references/endpoints.md` exists alongside the connector.

**Progressive disclosure.** Each `SKILL.md` stays small and points at `references/` for detail, so
a question about odds doesn't load the WebSocket protocol or the response-shape catalog.
