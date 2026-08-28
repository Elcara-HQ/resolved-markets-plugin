# Response shapes

Verified skeletons captured from live production responses (values are real; `…` marks truncation/repetition; `//` notes are annotations, not JSON). Fields marked *(crypto-only)* are absent on non-crypto markets.

**GET /health**
```jsonc
{ "status": "healthy", "clickhouse": true, "redis": true, "event_loop_lag_ms": 155,
  "event_loop_lag_ema_ms": 79, "event_loop_ok": true, "dep_check_latency_ms": 23,
  "pipeline_ready": true, "uptime": 492, "ws_clob": true, "ws_trade": false }
```

**GET /v1/public-stats**
```jsonc
{ "snapshot_count": "2506534662",              // string!
  "active_markets": 3553,
  "prices": { "BTC": 64152.97, "ETH": 1870.05, "SOL": 74.02, "XRP": 1.075,
              "DOGE": 0.0702, "BNB": 593.51, "HYPE": 55.21 },
  "exchange": { "snapshots_last_5min": 244, "latest_snapshot": "2026-08-04 22:04:06.711" } }
```

**GET /v1/categories** — array of:
```jsonc
{ "id": "crypto-updown", "category": "crypto", "displayName": "Crypto Up/Down",
  "activeMarkets": 35, "captureIntervalMs": 100, "refreshIntervalMs": 30000 }
```

**GET /v1/markets/live** — array of:
```jsonc
{ "category": "crypto", "subcategory": "BTC",
  "label": "Bitcoin Up or Down - August 4, 6PM ET",         // same as question
  "timeframe": "1h", "conditionId": "0xe1502203…",
  "question": "Bitcoin Up or Down - August 4, 6PM ET",
  "slug": "bitcoin-up-or-down-august-4-2026-6pm-et",
  "tokenIds": ["7637523728…", "4268334680…"],               // [up, down]
  "outcomes": ["Up", "Down"],
  "endDate": "2026-08-04T23:00:00.000Z",                    // ISO
  "active": true, "expired": false, "inPlay": false,
  "expiresIn": 3275771,                                     // ms until endDate
  "configId": "crypto-updown",
  "crypto": "BTC",                                          // "" on non-crypto items
  "tokenIdUp": "7637523728…", "tokenIdDown": "4268334680…",
  "priceToBeat": 64180.5,          // crypto up/down STRIKE. Set on 1d and 4h; null on 5m/15m/1h
  "twapLookbackSeconds": 60 }      // settlement TWAP window. 60 on 5m/15m/4h; null on 1h/1d
// Both fields are crypto up/down only and may be null — null means "not applicable to this
// timeframe", not "unknown". A market with twapLookbackSeconds settles on a time-weighted
// average over that trailing window, not a single spot print.
// Grouped markets (weather buckets, fixtures) add: "eventTitle", "negRiskMarketID"
```

**GET /v1/markets/by-slug/:slug** — same identity in snake_case:
```jsonc
{ "market_id": "0x5bed2aa5…", "category": "crypto", "subcategory": "BTC",
  "label": "…", "crypto": "BTC", "timeframe": "5m", "slug": "btc-updown-5m-1785881100",
  "question": "…", "token_ids": ["…", "…"], "outcomes": ["Up", "Down"],
  "token_id_up": "…", "token_id_down": "…", "end_date": "2026-08-04T22:10:00.000Z",
  "active": true, "expired": false, "expires_in": 272121 }
// Closed markets: active:false, expired:true, expires_in:0; adds event_title, neg_risk_id
```

**GET /v1/markets/:id/orderbook**
```jsonc
{ "market_id": "0xe1502203…", "marketId": "0xe1502203…",    // both aliases present
  "category": "crypto", "subcategory": "BTC", "label": "…", "question": "…",
  "timeframe": "1h", "slug": "…",
  "crypto": "BTC", "crypto_price": 64152.74, "cryptoPrice": 64152.74,   // (crypto-only)
  "up": {
    "tokenId": "7637523728…", "marketId": "0xe1502203…",
    "timestamp": 1785881125576,                             // epoch ms (all three)
    "eventTimestamp": 1785881125576, "captureTimestamp": 1785881126803,
    "sequenceNumber": 16124,
    "cryptoPrice": 64152.74, "cryptoPriceAgeMs": -1,        // -1 = not tracked this tick
    "crypto": "BTC", "timeframe": "1h", "category": "crypto", "subcategory": "BTC",
    "label": "…", "outcomeIndex": 0,
    "bids": [{ "price": 0.6, "size": 797 }, "…"],           // high→low
    "asks": [{ "price": 0.61, "size": 53 }, "…"],           // low→high
    "bestBid": 0.6, "bestAsk": 0.61, "midPrice": 0.605, "spread": 0.01,
    "bidDepth": 3962.65, "askDepth": 32456.49 },
  "down": { "…same shape, outcomeIndex 1…": 0 } }
```

**GET /v1/markets/:id/snapshots** — envelope `{ "market_id", "total", "limit", "offset", "data": [...] }`. Raw row:
```jsonc
{ "timestamp": "2026-08-04 22:05:02.192",                   // UTC
  "token_side": "UP", "outcome_index": 0,
  "crypto": "BTC", "crypto_price": 64152.765,               // (crypto-only)
  "category": "crypto", "subcategory": "BTC", "label": "…", "timeframe": "1h",
  "best_bid": 0.56, "best_ask": 0.57, "mid_price": 0.565, "spread": 0.01,
  "bid_depth_total": 3656.57, "ask_depth_total": 28678.74,
  "event_timestamp": "2026-08-04 22:05:02.192", "capture_timestamp": "2026-08-04 22:05:03.760",
  "sequence_number": "14059",                               // string!
  "crypto_price_age_ms": 330 }                              // -1 = not tracked
// includebook=true adds "bids"/"asks" arrays of {price, size} to each row
```
With `interval=` the envelope gains `"interval"`, `total` = bucket count, and rows become candles:
```jsonc
{ "bucket": "2026-08-04 22:05:00", "token_side": "UP", "outcome_index": 0,
  "crypto": "BTC", "category": "crypto", "subcategory": "BTC", "label": "…", "timeframe": "1h",
  "open": 0.545, "high": 0.565, "low": 0.545, "close": 0.565,   // of mid_price
  "vwap_mid": 0.5502, "avg_spread": 0.0099,
  "avg_best_bid": 0.5452, "avg_best_ask": 0.5552,
  "avg_bid_depth": 3361.03, "avg_ask_depth": 28978.81,
  "crypto_price": 64152.765, "snapshot_count": "17" }        // string!
```

**GET /v1/markets/:id/trades** — envelope `{ "market_id", "total", "limit", "offset", "data": [...] }`. Row:
```jsonc
{ "market_id": "0xe1502203…", "asset_id": "7637523728…",     // = snapshot token_id
  "timestamp": "2026-08-04 22:05:16.725", "price": 0.6, "size": 5,
  "side": "BUY",                                             // aggressor: BUY | SELL
  "category": "crypto", "subcategory": "",                   // subcategory may be ""
  "token_side": "UP" }                                       // may be null (map via asset_id)
```

**GET /v1/markets/:id/summary**
```jsonc
{ "market_id": "0xe1502203…", "category": "crypto", "crypto": "BTC", "timeframe": "1h",
  "subcategory": "BTC", "label": "…", "question": "…",
  "snapshot_count": 1482, "first_seen": "2026-08-04 21:59:05.002", "last_seen": "…",
  "avg_mid_price": 0.4999, "min_mid_price": 0.355, "max_mid_price": 0.645,
  "avg_spread": 0.0106, "min_spread": -0.01, "max_spread": 0.06,  // can be briefly NEGATIVE (crossed book ticks)
  "avg_crypto_price": 64169.09, "min_crypto_price": 64152.74, "max_crypto_price": 64199.99,  // (crypto-only)
  "avg_bid_depth": 2725.06, "avg_ask_depth": 32740.29,
  "sides": [
    { "token_side": "UP", "snapshots": "741",                // string!
      "avg_bid": 0.4612, "avg_ask": 0.4719, "avg_mid": 0.4665,
      "max_bid": 0.6, "min_ask": 0.36 },
    { "token_side": "DOWN", "…": 0 } ] }
```

**GET /v1/markets/metadata** — `{ "count", "markets": [...] }` (or `"events"` with `group_by_event=true`). Market row:
```jsonc
{ "market_id": "0x7ec59412…", "slug": "btc-updown-5m-1785879900",
  "question": "…", "label": "…", "category": "crypto", "subcategory": "BTC",
  "crypto": "BTC", "timeframe": "5m",
  "end_date": "2026-08-04 21:50:00.000",
  "event_title": null, "neg_risk_id": null,                  // set on grouped markets
  "outcomes": ["Up", "Down"], "token_ids": ["…", "…"],
  "resolved_outcome": "Down",                                // null while unresolved
  "resolution_status": "resolved",                           // "resolved" | "unresolved"
  "outcome_prices": ["0", "1"],                              // strings, aligned to outcomes
  "resolved_at": "2026-08-04 21:55:17.000",                  // null while unresolved
  "updated_at": "2026-08-04 22:06:32.458" }
// group_by_event=true: events: [{ neg_risk_id, event_title, slug, category,
//   subcategory, end_date, legs: [ market rows minus the event fields ] }]
```

**GET /v1/markets/history/recent**
```jsonc
{ "total_markets": 55934, "total_snapshots": 223930418,      // whole filtered set
  "live_count": 1, "closed_count": 55933,
  "returned_live": 0, "returned_closed": 3,                  // this page
  "limit": 3, "status": "closed",
  "replay_quota": { "unlimited": true },                     // Free tier: quota details
  "markets": [
    { "crypto": "BTC", "timeframe": "5m", "market_id": "0x0a76fb53…",
      "first_seen": "2026-08-04 21:59:04.217", "last_seen": "2026-08-04 22:06:01.192",
      "snapshot_count": "2260",                              // string!
      "category": "crypto", "subcategory": "BTC", "is_live": false,
      "end_date": "2026-08-04 22:05:00.000", "question": "…",
      "slug": "btc-updown-5m-1785880800",
      "event_title": null, "neg_risk_id": null, "replay_locked": false } ] }
```
`GET /v1/markets/history` (full listing) returns `{ total_markets, total_snapshots, live_count, closed_count, markets }`; its rows are slimmer — **no `slug` / `event_title` / `neg_risk_id` / `replay_locked`**, and `end_date` is ISO format there.

**GET /api/snapshot** (with `marketId`)
```jsonc
{ "market_id": "0x0a76fb53…", "category": "crypto", "subcategory": "BTC", "label": "…",
  "timestamp": "2026-08-04 22:06:01.192",
  "crypto": "BTC", "crypto_price": 64219.39,                 // (crypto-only)
  "timeframe": "5m",
  "up":   { /* one full snapshot row (see /snapshots) + "token_id", "token_side",
               and "bids"/"asks" ([] unless includebook=true) */ },
  "down": { /* same shape */ } }
// Without marketId: an ARRAY of the 2 most recent matching rows in a SLIMMER shape —
// market_id, token_id, token_side, timestamp, category, subcategory, label, timeframe,
// best_bid, best_ask, mid_price, spread, bid/ask_depth_total, crypto, crypto_price —
// no fidelity fields and no outcome_index
```

**GET /api/snapshot/latest** — array of ≤5 snapshot rows (same shape as `/snapshots` rows) plus `token_id` and `bids`/`asks` (`[]` unless `includebook=true`).

**GET /v1/exchange/orderbook**
```jsonc
{ "exchange": "hyperliquid_perp", "symbol": "BTC", "timestamp": "2026-08-04 22:06:33.979",
  "best_bid": 64190, "best_ask": 64191, "mid_price": 64190.5, "spread": 1,
  "bid_depth_total": 5529233.91, "ask_depth_total": 4723250.57,
  "bids": [[64190, 1.1215], "…"],                            // [price, size] PAIRS, ≤20 levels
  "asks": [[64191, 13.052], "…"] }
```

**GET /v1/exchange/snapshots** — `{ "exchange", "symbol", "count", "data": [...] }`; rows are the orderbook shape **minus** `bids`/`asks`.

**WebSocket messages** — `{"type":"auth","status":"ok"}` · `{"type":"markets","data":[…live items…]}` · `{"type":"orderbook","markets":[{ "marketId", "crypto", "timeframe", "question", "cryptoPrice", "up": {…}, "down": {…} }]}` (sides = REST orderbook side shape) · `{"type":"error","code":4003,"message":"…"}`.

