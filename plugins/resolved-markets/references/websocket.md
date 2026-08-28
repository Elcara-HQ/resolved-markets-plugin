# WebSocket stream

`wss://api.resolvedmarkets.com/ws/orderbook`. Message-based auth — do **not** put the key in the URL.

1. Connect. 2. Within 5 s send `{"type":"auth","apiKey":"rm_…"}`. 3. Receive `{"type":"auth","status":"ok"}` followed by a `{"type":"markets","data":[…]}` list (tier-scoped, same item shape as `/v1/markets/live`; re-sent when the list changes, checked every 10 s). 4. Send `{"type":"subscribe","crypto":"BTC"}` (case-insensitive).

Then every 2 s: `{"type":"orderbook","markets":[…]}` covering **all** live markets of the subscribed coin — every up/down timeframe plus its hit-price strikes — each with `up`/`down` sides in the same shape as the REST orderbook (`bestBid`, `bestAsk`, `midPrice`, `spread`, `bidDepth`, `askDepth`, `bids`/`asks` as `{price,size}`, epoch-ms timestamps, `cryptoPrice`).

Close codes: `4001` = no auth within 5 s; `4003` = invalid/revoked key, **Free tier** (no WS access), or tier connection limit already in use — do not auto-reconnect on 4003. The server pings every 30 s; unresponsive clients are dropped (standard libraries auto-pong). Reconnect with exponential backoff 1s → 2s → 4s → 8s → 16s max; reset after 30 s of stable connection.

**Size the first frame for.** The `markets` frame is sent immediately after auth and covers every market your tier can see — measured **~5 MB / 5,345 items** on a full-access key. That exceeds the default inbound frame limit in several WebSocket clients (Python `websockets` defaults to 1 MiB and closes with code **1009 "message too big"**). Raise the limit before connecting, as the example does.

```python
import asyncio, json, websockets

URL = "wss://api.resolvedmarkets.com/ws/orderbook"

async def stream(key, coin="BTC"):
    # max_size: the first "markets" frame carries every market your tier can see —
    # ~5 MB on a full-access key, well over the library's 1 MB default, which
    # otherwise closes the connection with 1009 "message too big".
    async with websockets.connect(URL, max_size=16 * 1024 * 1024) as ws:
        await ws.send(json.dumps({"type": "auth", "apiKey": key}))
        async for raw in ws:
            msg = json.loads(raw)
            if msg["type"] == "auth" and msg.get("status") == "ok":
                await ws.send(json.dumps({"type": "subscribe", "crypto": coin}))
            elif msg["type"] == "orderbook":
                for m in msg["markets"]:
                    print(m["timeframe"], m["up"]["bestBid"], m["up"]["bestAsk"])
            elif msg["type"] == "error":
                raise RuntimeError(f"{msg['code']}: {msg['message']}")
```

