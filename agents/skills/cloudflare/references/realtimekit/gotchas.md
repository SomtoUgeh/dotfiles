# RealtimeKit Gotchas

- **Initialization fails:** `new RealtimeKitClient(...)` is invalid; await `RealtimeKitClient.init(...)` or use `useRealtimeKitClient` from `@cloudflare/realtimekit-react`.
- **UI never joins:** pass `meeting={meeting}` to `RtkMeeting`; `authToken` is a client initialization option. Decide whether the setup screen or your own code calls `join()`.
- **Token missing:** check HTTP/API success and the actual response envelope. The Cloudflare SDK participant response exposes `data.token`; the client calls this `authToken`.
- **Unexpected permissions:** resolve the preset from the authenticated server role. Never trust a caller-provided host preset or arbitrary meeting ID.
- **No camera/microphone:** require a secure context, request user permission, inspect devices, and handle another application owning the device.
- **No remote audio:** a muted video grid does not render audio. Use UI Kit media components or the SDK's audio playback system; browser autoplay may require user interaction.
- **Stale tracks/events:** register typed listeners before joining, react to media changes as well as membership changes, and remove listeners when leaving.
- **Echo:** use headphones, echo cancellation, and avoid multiple active speakers/microphones in one room. Lowering video resolution does not fix acoustic feedback.
- **Blocked network:** consult current [RealtimeKit documentation](https://developers.cloudflare.com/realtime/realtimekit/) for platform network requirements. Arbitrary Wrangler TURN variables do not configure the SDK.
- **Screen share:** launch from a user gesture and handle unsupported browser/platform permissions and ended tracks.
- **Recording failure:** check session state and current preset schema. Do not invent flat permission flags or assume an R2 binding automatically stores recordings.

## Limits and Verification

Verify current plan, SDK, and API limits in the official docs. Do not hardcode unverified limits such as 100 participants, 1000 concurrent sessions, 6-hour recording, 24-hour meeting/token lifetime, or broad UDP port ranges.

Validate with two separate participant credentials in two browser sessions: join/leave, audio both directions, video, permission denial, reconnect, device switching, and cleanup. Package type checks confirm method signatures but do not prove hosted media transport, recording, or billing behavior.

[Overview](README.md) · [API](api.md) · [Configuration](configuration.md) · [Patterns](patterns.md)
