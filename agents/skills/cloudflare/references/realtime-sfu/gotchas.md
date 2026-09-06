# Gotchas & Troubleshooting

## Common Errors

### "Slow initial connect (~1.8s)"

**Cause:** First STUN delayed during consensus forming (normal behavior)
**Solution:** Subsequent connections are faster. CF detects DTLS ClientHello early to compensate.

### "No media flow"

**Cause:** SDP exchange incomplete, connection not established, tracks not added before offer, browser permissions missing
**Solution:**
1. Verify SDP exchange complete
2. Check `pc.connectionState === 'connected'`
3. Ensure tracks added before creating offer
4. Confirm browser permissions granted
5. Use `chrome://webrtc-internals` for debugging

### "Track not receiving"

**Cause:** Track not published, track ID not shared, session IDs mismatch, `pc.ontrack` not set, renegotiation needed
**Solution:**
1. Verify track published successfully
2. Confirm track ID shared between peers
3. Check session IDs match
4. Set `pc.ontrack` handler before answer
5. Trigger renegotiation if needed

### "ICE connection failed"

Use the library's reconnection flow or rebuild the peer connection/session and republish/resubscribe. Calling `restartIce()` alone does not exchange the new SDP; do not send an unverified offer to an endpoint documented for answering SFU renegotiation. Check the current connection API before implementing a raw restart flow.

### "Track stuck/frozen"

**Cause:** Sender paused track, network congestion, codec mismatch, mobile browser backgrounded
**Solution:**
1. Check `track.enabled` and `track.readyState === 'live'`
2. Verify sender active: `pc.getSenders().find(s => s.track === track)`
3. Check stats for packet loss/jitter (see patterns.md)
4. On mobile: Re-acquire tracks when app foregrounded
5. Test with different codecs if persistent

### "Network change disconnects call"

Handle peer-connection state changes and reconnect through the client library. Avoid unsafe `navigator as any` casts or relying solely on the Network Information API, which is not universally available.

## Retry Policy

Serialize signaling and distinguish read-only calls from mutations. Retrying session/track creation after an ambiguous network result can create duplicates; reconcile server state before replaying. Check both HTTP status and API/per-track error fields.

## Debugging with chrome://webrtc-internals

1. Open `chrome://webrtc-internals` in Chrome/Edge
2. Find your PeerConnection in the list
3. Check **Stats graphs** for packet loss, jitter, bandwidth
4. Check **ICE candidate pairs**: Look for `succeeded` state, relay vs host candidates
5. Check **getStats**: Raw metrics for inbound/outbound RTP
6. Look for errors in **Event log**: `iceConnectionState`, `connectionState` changes
7. Export data with "Download the PeerConnection updates and stats data" button
8. Common issues visible here: ICE failures, high packet loss, bitrate drops

## Limits

As checked 2026-09-05: up to 50 API calls/second per session, up to 64 tracks per API call. There is no app-wide rate limit stated in the [current limits](https://developers.cloudflare.com/realtime/sfu/limits/). Track resources expire after 30 seconds without media. Account free egress is 1,000 GB/month; verify current SFU/TURN pricing separately. Do not describe TURN as universally free or promise fixed connection latency.

## Security Checklist

- ✅ **Never expose** `CALLS_APP_SECRET` to client
- ✅ **Validate user identity** in backend before creating sessions
- ✅ **Implement auth tokens** for session access (JWT in custom header)
- ✅ **Rate limit** session creation endpoints
- ✅ **Expire sessions** server-side after inactivity
- ✅ **Validate track IDs** before subscribing (prevent unauthorized access)
- ✅ **Use HTTPS** for all signaling (API calls)
- ✅ **Enable DTLS-SRTP** (automatic with Cloudflare, encrypts media)
- ⚠️ **Consider E2EE** for sensitive content (implement client-side with Insertable Streams API)
