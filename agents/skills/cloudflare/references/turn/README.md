# Cloudflare Realtime TURN

TURN relays WebRTC traffic when peers cannot connect directly. STUN discovers public addresses; TURN, signaling, and an SFU are separate components.

Create a TURN key in the Realtime dashboard, keep its secret on your server, and issue expiring ICE credentials to authenticated, authorized callers. The browser receives `iceServers`, never the TURN key secret.

- [Configuration](configuration.md): key storage and application endpoint requirements.
- [API](api.md): credential generation, validation, and revocation.
- [Patterns](patterns.md): browser setup, renewal, and relay diagnostics.
- [Gotchas](gotchas.md): port filtering, TTL, lifecycle, and quota failures.

Credentials have a maximum TTL of 48 hours. Choose a TTL that covers the expected session, with a renewal plan for longer calls. Expiration and revocation affect credential validity; do not assume a JavaScript timer proves that existing allocations have ended.

Use the URLs returned by the service, retaining UDP, TCP, and TLS alternatives. If filtering browser-blocked port 53, match the port exactly; `includes(":53")` also removes TLS port 5349.

[TURN documentation](https://developers.cloudflare.com/realtime/turn/) · [Credential API](https://developers.cloudflare.com/realtime/turn/generate-credentials/) · [Current limits](https://developers.cloudflare.com/realtime/turn/)
