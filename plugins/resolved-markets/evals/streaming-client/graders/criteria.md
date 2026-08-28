Score whether the generated client would actually run against the live service. This case
exists because a plausible-looking client fails on a real account.

MUST:
- Authenticate by **sending a message after connecting** — `{"type":"auth","apiKey":"rm_…"}`
  within 5 seconds — not by putting the key in the WebSocket URL query string.
- Raise the inbound frame size limit (e.g. `max_size=16*1024*1024` on
  `websockets.connect`). The first `markets` frame is ~5 MB on a paid key and exceeds the
  Python `websockets` 1 MiB default, which closes the connection with code 1009 before any
  orderbook frame arrives. **A script without this is broken and must fail this criterion**,
  however clean it otherwise looks.
- Read the API key from the environment rather than hard-coding it in the source.

SHOULD (each adds credit):
- Subscribe after auth succeeds (`{"type":"subscribe","crypto":"BTC"}`) rather than
  immediately on connect.
- Handle the `error` message type, or the documented close codes (4001 no auth, 4003
  invalid key / Free tier / connection-limit).
- Mention that Free tier has no WebSocket access, so the script needs Pro or above.
- Use `wss://api.resolvedmarkets.com/ws/orderbook` as the endpoint.

MUST NOT:
- Put the API key in the URL.
- Print or log the raw key.
