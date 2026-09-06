# API Reference

## Authentication

```bash
curl -X POST "https://rtc.live/v1/apps/${CALLS_APP_ID}/sessions/new" \
  -H "Authorization: Bearer ${CALLS_APP_SECRET}"
```

## Core Concepts

**Sessions:** PeerConnection to Cloudflare edge
**Tracks:** Media/data channels (audio/video/datachannel)
**No rooms:** Build presence via track sharing

## Client Libraries

**PartyTracks (Recommended):** Observable-based client library for production use. Handles device changes, network switches, ICE restarts automatically. Push/pull API with React hooks. See patterns.md for full examples.

```bash
npm install partytracks rxjs
```

**Raw API:** Direct HTTP + WebRTC for custom requirements (documented below).

## Endpoints

### Create Session
```http
POST /v1/apps/{appId}/sessions/new
→ {sessionId, sessionDescription?}
```

### Add Track (Publish)
```http
POST /v1/apps/{appId}/sessions/{sessionId}/tracks/new
Body: {
  sessionDescription: {sdp, type: "offer"},
  tracks: [{location: "local", trackName: "my-video", mid: "<transceiver-mid>"}]
}
→ {sessionDescription, tracks: [{trackName}]}
```

### Add Track (Subscribe)
```http
POST /v1/apps/{appId}/sessions/{sessionId}/tracks/new
Body: {
  tracks: [{
    location: "remote",
    trackName: "remote-track-id",
    sessionId: "other-session-id"
  }]
}
→ {sessionDescription} (server offer)
```

### Renegotiate
```http
PUT /v1/apps/{appId}/sessions/{sessionId}/renegotiate
Body: {sessionDescription: {sdp, type: "answer"}}
```

### Close Tracks
```http
PUT /v1/apps/{appId}/sessions/{sessionId}/tracks/close
Body: {tracks: [{mid: "<transceiver-mid>"}], force: true}
→ {requiresImmediateRenegotiation: boolean}
```

### Get Session
```http
GET /v1/apps/{appId}/sessions/{sessionId}
→ {sessionId, tracks: TrackMetadata[]}
```

## TypeScript Types

```typescript
interface TrackMetadata {
  trackName: string;
  location: "local" | "remote";
  sessionId?: string; // For remote tracks
  mid?: string; // WebRTC mid
}
```

## WebRTC Flow

Create a session on the backend and return its `sessionId`. Add media transceivers before creating an offer, then publish their `mid` and track names with the offer through `tracks/new`. A session created without an SDP has no answer to apply. Serialize signaling changes; check top-level and per-track API errors before updating local state.

Your authenticated proxy must preserve the official `sessionDescription: { type, sdp }` body shape. Do not forward a bare `{sdp}` object to Cloudflare.

## Publishing

```typescript
const transceiver = pc.addTransceiver(localTrack, { direction: 'sendonly' });
await pc.setLocalDescription(await pc.createOffer());
if (!pc.localDescription || transceiver.mid === null) throw new Error('Missing local SDP/mid');
const res = await fetch(`/api/sessions/${sessionId}/tracks`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    sessionDescription: pc.localDescription,
    tracks: [{ location: 'local', trackName: localTrack.id, mid: transceiver.mid }]
  })
});
if (!res.ok) throw new Error('Track publication failed');
// Validate the JSON against the OpenAPI schema and apply its answer.
```

[Connection API and OpenAPI schema](https://developers.cloudflare.com/realtime/sfu/https-api/)

## Subscribing

Register `pc.ontrack` before applying the remote description. A received track may have no `event.streams`; attach `new MediaStream([event.track])` in that case. Request a remote track using `{location: "remote", sessionId, trackName}`. Check `requiresImmediateRenegotiation` and the returned SDP type before creating/applying an answer. Send the answer as `{sessionDescription: {type: "answer", sdp}}` to `/renegotiate`.

DataChannels use `/datachannels/establish` and `/datachannels/new` after establishing their transport; `pc.createDataChannel()` alone does not publish a channel through the SFU. Follow the current OpenAPI for channel negotiation and closure.
