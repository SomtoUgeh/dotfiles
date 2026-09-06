# Patterns & Use Cases

## Architecture

```
Client (WebRTC) <---> CF Edge <---> Backend (HTTP)
                           |
                    CF Backbone (310+ DCs)
                           |
                    Other Edges <---> Other Clients
```

Anycast routing selects Cloudflare edges; measure actual network and media latency.

Illustrative distribution topology:
```
Publisher -> Edge A -> Edge B -> Sub1
                    \-> Edge C -> Sub2,3
```

## Use Cases

**1:1:** A creates session+publishes, B creates+subscribes to A+publishes, A subscribes to B
**N:N:** All create session+publish, backend broadcasts track IDs, all subscribe to others
**1:N:** Publisher creates+publishes, viewers each create+subscribe (subject to transport/client/service constraints)
**Breakout:** Same PeerConnection! Backend closes/adds tracks, no recreation

## PartyTracks

Verified with `partytracks` 0.0.56. Its entrypoints are `partytracks/client`, `partytracks/react`, and `partytracks/server`; it has no root export.

```typescript
import { PartyTracks, getCamera } from 'partytracks/client';
import { of } from 'rxjs';

const pt = new PartyTracks({ prefix: '/api/partytracks' });
const camera = getCamera({ broadcasting: true });
const publishing = pt.push(camera.broadcastTrack$).subscribe({
  next: metadata => { /* Share authorized metadata through your room service. */ },
  error: error => console.error('Publication failed', error),
});
const receiving = pt.pull(of({ trackName: remoteTrackName, sessionId: remoteSessionId })).subscribe({
  next: track => { videoElement.srcObject = new MediaStream([track]); },
  error: error => console.error('Subscription failed', error),
});
// On leave:
receiving.unsubscribe();
publishing.unsubscribe();
camera.disableSource();
videoElement.srcObject = null;
```

React observable hooks are exported from `partytracks/react`. Use stable observables and clean up subscriptions; camera/screen helpers are functions, not methods on PartyTracks.

## Backend

```typescript
import { routePartyTracksRequest } from 'partytracks/server';
// After authenticating the caller and authorizing room/track access:
const response = await routePartyTracksRequest({
  request, prefix: '/api/partytracks',
  appId: env.CALLS_APP_ID, token: env.CALLS_APP_SECRET,
});
```

Keep session locking enabled (the default). The library's session lock does not replace application membership or authorization for subscribing to other users' tracks. Secrets stay on the backend.

## Audio Level Detection

```typescript
// Attach analyzer to audio track
function attachAudioLevelDetector(track: MediaStreamTrack) {
  const ctx = new AudioContext();
  const analyzer = ctx.createAnalyser();
  const src = ctx.createMediaStreamSource(new MediaStream([track]));
  src.connect(analyzer);

  const data = new Uint8Array(analyzer.frequencyBinCount);
  let frame = 0;
  const checkLevel = () => {
    analyzer.getByteFrequencyData(data);
    const level = data.reduce((a, b) => a + b) / data.length;
    if (level > 30) console.log('Speaking:', level); // Trigger UI update
    frame = requestAnimationFrame(checkLevel);
  };
  checkLevel();
  return () => { cancelAnimationFrame(frame); src.disconnect(); void ctx.close(); };
}
```

## Connection Quality Monitoring

```typescript
pc.getStats().then(stats => {
  stats.forEach(report => {
    if (report.type === 'inbound-rtp' && report.kind === 'video') {
      const {packetsLost, packetsReceived, jitter} = report;
      const total = packetsLost + packetsReceived;
      const lossRate = total > 0 ? packetsLost / total : 0;
      if (lossRate > 0.05) console.warn('High packet loss:', lossRate);
      if (jitter > 0.1) console.warn('High jitter:', jitter);
    }
  });
});
```

## Stage Management (Limit Visible Participants)

Choose the top N participants first, then diff against active remote subscriptions. Serialize additions/removals and close remote tracks through the SFU API using their mids (or unsubscribe the PartyTracks pull observable). `pc.getSenders()` contains local senders; stopping those tracks does not unsubscribe a remote participant. Handle failures before updating the active subscription set.

## Advanced

Bandwidth mgmt:
```ts
const s = pc.getSenders().find(s => s.track?.kind === 'video');
if (!s) throw new Error("No video sender");
const p = s.getParameters();
if (!p.encodings) p.encodings = [{}];
p.encodings[0].maxBitrate = 1200000; p.encodings[0].maxFramerate = 24;
await s.setParameters(p);
```

Simulcast (publish layers; configure subscriber preferredRid/fallback per the API):
```ts
pc.addTransceiver('video', {direction: 'sendonly', sendEncodings: [
  {rid: 'high', maxBitrate: 1200000},
  {rid: 'med', maxBitrate: 600000, scaleResolutionDownBy: 2},
  {rid: 'low', maxBitrate: 200000, scaleResolutionDownBy: 4}
]});
```

DataChannels require the SFU establish/new APIs; see [api.md](api.md). Stream WHIP/WHEP is a separate integration, not interchangeable raw SFU signaling.

Recording requires capturing/encoding media or a supported recording service before storing bytes in R2. A bare `R2.put()` does not record a live call. Measure join latency, packet loss, and end-to-end media delay in your application rather than treating illustrative figures as guarantees.
