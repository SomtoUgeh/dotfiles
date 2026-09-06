# TURN integration patterns

## Browser initialization

Use `parseIceServers` from [api.md](api.md) on the response from your authenticated application endpoint:

```typescript
const response = await fetch("/api/ice-servers", {
  method: "POST", credentials: "same-origin",
  // Include the application's CSRF protection when using cookie authentication.
});
if (!response.ok) throw new Error("Could not obtain ICE credentials");
const payload: unknown = await response.json();
const pc = new RTCPeerConnection({ iceServers: parseIceServers(payload) });
```

Add media tracks and exchange descriptions and ICE candidates through your existing signaling layer. TURN does not provide signaling or create SFU sessions. See the [Realtime SFU API](https://developers.cloudflare.com/realtime/sfu/) for that separate integration.

## Renewing credentials

Before expiry, call the authenticated endpoint again, validate its response, and use `pc.setConfiguration({ ...pc.getConfiguration(), iceServers })`. When an ICE restart is needed, call `pc.restartIce()` and let your existing `negotiationneeded` handler perform the offer/answer exchange. Do not create a second competing offer loop.

A temporary `disconnected` state may recover; debounce recovery and prevent overlapping renewal/restart attempts. Use bounded retries with backoff. Cancel timers, abort pending requests, and remove listeners when the call ends. Do not keep renewing credentials after `pc.close()`.

## Verify relay use

For a controlled test, create the connection with `iceTransportPolicy: "relay"`. Confirm the selected candidate pair through `getStats()`: find a transport report with `selectedCandidatePairId`, resolve that pair, then inspect its local/remote candidate types. A generic candidate-pair `selected` property is not a portable selection API.

Test UDP availability and TCP/TLS fallback on representative networks. Keep relay-only mode only when the product requires it; it increases relayed traffic.
