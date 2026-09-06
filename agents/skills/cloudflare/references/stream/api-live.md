# Stream Live Streaming API

Live input creation, status checking, simulcast, and WebRTC streaming.

## Create Live Input

### Using Cloudflare SDK

```typescript
import Cloudflare from 'cloudflare';

const client = new Cloudflare({ apiToken: env.CF_API_TOKEN });

const liveInput = await client.stream.liveInputs.create({
  account_id: env.CF_ACCOUNT_ID,
  recording: { mode: 'automatic', timeoutSeconds: 30 },
  deleteRecordingAfterDays: 30
});

// Returns: { uid, rtmps, srt, webRTC }
```

### Read Live Status

```typescript
const liveInput = await client.stream.liveInputs.get(liveInputId, { account_id: env.CF_ACCOUNT_ID });
const isConnected = liveInput.status === 'connected' || liveInput.status === 'reconnected';
```

`status` is a nullable string, not `status.current.state`. Treat connection state separately from recording/playback readiness. Keep RTMPS/SRT keys and `webRTC.url` private to the broadcaster.

## Simulcast (Live Outputs)

### Create Output

```typescript
await client.stream.liveInputs.outputs.create(liveInputId, {
  account_id: env.CF_ACCOUNT_ID,
  url: 'rtmp://a.rtmp.youtube.com/live2',
  streamKey: youtubeStreamKey,
  enabled: true,
});
```

Pass the destination URL and stream key separately. Do not concatenate the key onto the URL as well. This is a real external broadcast destination; configure only the intended authorized output.

## WebRTC Streaming (WHIP/WHEP)

Use the exact `webRTC.url` returned for publishing: it contains a secret and cannot be reconstructed from the live input ID. Use `webRTCPlayback.url` for playback. Use a WHIP/WHEP client that implements SDP, ICE gathering/trickle, response status checks, session Location handling, and teardown. For browser implementation follow the [official tutorial](https://developers.cloudflare.com/stream/examples/browser-based-webrtc/); a single bare SDP POST without lifecycle handling is incomplete.

As checked 2026-09-05, WHIP and WHEP must be used together: RTMP/SRT inputs cannot be played via WHEP, and WHIP inputs cannot be recorded, simulcast via RTMP/SRT, or played through HLS/DASH. See [current WebRTC capabilities](https://developers.cloudflare.com/stream/webrtc-beta/).

## Recording Settings

| Mode | Behavior |
|------|----------|
| `automatic` | Record all live streams |
| `off` | No recording |
| `timeoutSeconds` | Stop recording after N seconds of inactivity |

```typescript
const recordingConfig = {
  mode: 'automatic',
  timeoutSeconds: 30, // Auto-stop 30s after stream ends
  requireSignedURLs: true, // Require token for VOD playback
  allowedOrigins: ['yourdomain.com']
};
```

## In This Reference

- [README.md](./README.md) - Overview and quick start
- [api.md](./api.md) - On-demand video APIs
- [configuration.md](./configuration.md) - Setup and config
- [patterns.md](./patterns.md) - Full-stack flows, best practices
- [gotchas.md](./gotchas.md) - Error codes, troubleshooting

## See Also

- [workers](../workers/) - Deploy live APIs in Workers
