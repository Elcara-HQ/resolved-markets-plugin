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

**Credit-aware by design.** Simple questions get answered straight away. But before an expensive
or under-specified pull, Claude asks — as a single batched multiple-choice round with a
recommended default on each — the questions that actually change the cost: do you need the
**orderbook ladder** or just the price, **how many markets**, over what span, at what resolution.
"BTC 5m for last week" is 2,016 markets, and the two answers above swing the credit cost by
orders of magnitude.

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

### Keep it updated — this matters more than for most plugins

**Turn auto-update on.** In the Claude app that's **Sync automatically** when you add the
repository; in Claude Code, open `/plugin`, select this plugin, and enable auto-update. Without it
you keep whatever version you installed, forever.

That matters here because the plugin ships a **snapshot of what markets exist** — coins,
leagues, cities, series. Coverage grows continuously on our side with no change on yours, so a
stale copy doesn't fail loudly: it confidently tells you a market isn't covered when it is. Tennis
went live between two releases and the shipped catalog was wrong until the next version.

To pull updates by hand at any time:

```bash
claude plugin marketplace update resolved-markets-plugins
```

The skills also tell Claude that the live API wins whenever it disagrees with the bundled catalog,
so a stale install degrades gracefully rather than lying — but updating is better.

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
