---
name: setup
description: >-
  Connect this session to Resolved Markets and verify it works. Walks through authorizing the
  hosted connector, or creating an API key if you prefer key-based access, then runs a free
  check and a first real query.
disable-model-invocation: true
---

# Connect to Resolved Markets

Walk the user through this in order. Stop at the first step that already succeeds — most people
only need step 1.

Don't open with a questionnaire — **check step 1 first**, because it usually answers everything.
Only if the connector isn't available, ask (with `AskUserQuestion`, options not prose) how they
want to connect: **the hosted connector via OAuth** *(recommended — sign in once, no key to
paste)*, or **an API key** *(only needed for scripts, or a client that can't do OAuth)*.

## Step 1 — Is the connector already working?

Try `list_categories` from the `resolvedmarkets` MCP server.

- **It returns a list of categories** → they're connected. Skip to *Verify* below.
- **It asks them to authorize** → have them approve. The server runs standard OAuth: they sign in
  with their existing Resolved Markets account, approve once, and the session is authenticated.
  **No API key to copy or paste.**
- **There are no `resolvedmarkets` tools at all** → the connector isn't enabled in this
  environment. Go to step 2.

If they don't have an account yet, they sign up at `https://resolvedmarkets.com` — the Free tier
needs no payment details and covers every crypto market.

## Step 2 — Enable the connector

**In the Claude app** (web, desktop, or Cowork): the connector ships with this plugin. If the
tools aren't showing, check the plugin is enabled under **Customize → Plugins**, then start a new
chat.

**In Claude Code**, add it directly:

```bash
claude mcp add --transport http resolvedmarkets https://mcp.resolvedmarkets.com/mcp
```

Then run `/mcp`, pick **resolvedmarkets**, and choose **Authenticate**.

## Step 3 — API key instead (optional)

Only needed for writing scripts, or for a client that can't do OAuth.

1. Sign in at `https://resolvedmarkets.com/api-keys`.
2. **Create key**, label it (e.g. `claude-code`), and copy the `rm_…` value — **it is shown
   once**.
3. Store it in an environment variable, never in a file that gets committed:

   ```bash
   export RESOLVED_MARKETS_API_KEY="rm_your_key_here"
   ```

Offer to add it to their shell profile. **Never** echo the key back into the conversation, into
generated code, into logs, or into a URL query string — the API takes it in the `X-API-Key`
header only.

To use a key with the MCP connector instead of OAuth:

```bash
claude mcp add --transport http resolvedmarkets https://mcp.resolvedmarkets.com/mcp \
  --header "X-API-Key: rm_your_key_here"
```

## Verify

Two checks, in order:

1. **Free check** — `GET https://api.resolvedmarkets.com/v1/api-keys/validate` with the
   `X-API-Key` header returns `{"valid": true, …}`. This costs **0 credits**; it is not metered
   at all. Skip it if they're on OAuth with no key.
2. **A real query** — call `list_categories` (or `GET /v1/categories`). It costs 1 credit and
   confirms the whole path works. The response headers carry `X-Credits-Remaining` and
   `X-RateLimit-Limit`, which is also how you read their tier: 300/min is Free or Pro, 1,000 is
   Scale, 3,000 is Enterprise.

## Before you finish — turn auto-update on

Worth thirty seconds, because this plugin ships a **snapshot of what markets exist** and coverage
grows continuously. A stale copy doesn't error; it confidently reports a market as uncovered when
it isn't.

- **Claude app**: enable **Sync automatically** on the repository under Customize → Plugins.
- **Claude Code**: `/plugin` → select **resolved-markets** → enable auto-update. Or update by hand
  any time with `claude plugin marketplace update resolved-markets-plugins`.

If the user's catalog ever disagrees with a live response, the live response is right — say so and
re-check with `list_categories` rather than trusting the bundled table.

## What they can do now

- Ask for live odds in plain English — *"what are the BTC 5-minute Polymarket odds right now?"*
- Pull price history, executed trades, and settlement outcomes.
- Backtest a strategy against historical orderbook data.

A new account starts on **Free**: 5,000 credits/month, 300 requests/min, unlimited history, full
orderbook depth, and every crypto market (BTC, ETH, SOL, XRP, DOGE, HYPE, BNB). Sports, weather,
economics, social and equities markets start at the Scale tier —
`https://resolvedmarkets.com/pricing`.
