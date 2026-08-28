# Resolved Markets — Claude plugin

Prediction-market orderbook data for Claude. Ask about Polymarket odds in plain English, pull
high-frequency price history, or backtest a strategy — without wiring up an API by hand.

Powered by [Resolved Markets](https://resolvedmarkets.com), which captures Polymarket CLOB
orderbooks at up to ~20 Hz per token and stores every snapshot, trade, and settlement result.

> Resolved Markets is an independent data platform and is **not affiliated with Polymarket**.

## What you get

- **A hosted connector** — 14 tools and 3 resources over MCP. Sign in once with OAuth; no API key
  to copy or paste.
- **Four skills** that Claude loads only when they're relevant:
  - `market-data` — odds, market discovery, price history, trades, settlement outcomes
  - `backtesting` — how to simulate a strategy without fooling yourself on fills
  - `api-integration` — writing code against the REST API and WebSocket
  - `/resolved-markets:setup` — connect and verify

Coverage: crypto up/down and hit-price markets (BTC, ETH, SOL, XRP, DOGE, HYPE, BNB), sports,
weather, economics, social, and equities — plus Hyperliquid perpetual-futures orderbooks.

## Install

### In the Claude app

**Customize → Plugins → Add from a repository**, then paste this repository's URL. Turn on
**Sync automatically** to get updates.

Or download a release `.zip` and use **Upload a plugin**.

### In Claude Code

```bash
claude plugin marketplace add Elcara-HQ/resolved-markets-plugin
claude plugin install resolved-markets@resolved-markets-plugins
```

Then run `/resolved-markets:setup`.

## Try it

```
What are the current odds on the BTC 5-minute Polymarket market?
How did last night's NBA prediction markets settle?
Chart the last hour of the ETH 15m market as 1-minute candles.
I want to backtest buying at 0.20 and exiting at 0.60 — what data do I need?
```

## Account and pricing

A free account covers every crypto market — 5,000 credits/month, 300 requests/min, unlimited
history, and full orderbook depth. Sports, weather, economics, social and equities markets start
at the Scale tier.

Sign up at [resolvedmarkets.com](https://resolvedmarkets.com) · plans at
[resolvedmarkets.com/pricing](https://resolvedmarkets.com/pricing) ·
API docs at [resolvedmarkets.com/docs](https://resolvedmarkets.com/docs)

## Repository layout

```
.claude-plugin/marketplace.json     the marketplace manifest
plugins/resolved-markets/           the plugin
  .claude-plugin/plugin.json        manifest
  .mcp.json                         hosted connector (OAuth)
  skills/                           four skills
  references/                       loaded on demand, not up front
scripts/build-zip.sh                build an uploadable archive
scripts/prepublish-check.sh         secret + portability + validation checks
```

## Development

```bash
claude plugin validate --strict plugins/resolved-markets
claude --plugin-dir ./plugins/resolved-markets      # load it in a session
./scripts/prepublish-check.sh                       # run before every release
./scripts/build-zip.sh                              # produce dist/*.zip
```

Bump `version` in `plugins/resolved-markets/.claude-plugin/plugin.json` on **every** release —
installs are cached by version, so an unchanged version means users never see the update.
