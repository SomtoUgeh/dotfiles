# RealtimeKit API Reference

Use installed SDK types as the source of method and event signatures. The core package exports `RTKParticipant`, `RTKSelf`, and other `RTK*` types; do not shadow them with handwritten partial classes.

## Core SDK

```typescript
import RealtimeKitClient from '@cloudflare/realtimekit';
const meeting = await RealtimeKitClient.init({ authToken, defaults: { audio: true, video: true } });
await meeting.join();
await meeting.self.enableAudio();
await meeting.self.disableAudio();
await meeting.self.enableVideo();
await meeting.self.disableVideo();
await meeting.self.enableScreenShare();
await meeting.self.disableScreenShare();
const devices = await meeting.self.getAllDevices();
const camera = devices.find(device => device.kind === 'videoinput');
if (camera) await meeting.self.setDevice(camera);
const remoteParticipants = meeting.participants.joined.toArray();
const countIncludingSelf = meeting.participants.joined.size + 1;
await meeting.chat.sendTextMessage('Hello');
await meeting.polls.create('Ready?', ['Yes', 'No'], false, false);
await meeting.leave();
```

`joined`, `active`, `waitlisted`, and `pinned` are SDK collections, not native Maps. Use their typed APIs (`size`, `get()`, `toArray()`). Remote participants and self are different types. Subscribe to media events to render track changes, not just joins/leaves.

## Server API

Base: `https://api.cloudflare.com/client/v4/accounts/{account_id}/realtime/kit/{app_id}`.

- `POST /meetings`: create a meeting.
- `POST /meetings/{meeting_id}/participants`: add a participant with server-selected `preset_name` and `custom_participant_id`.
- `POST /meetings/{meeting_id}/participants/{participant_id}/token`: refresh its token.
- Sessions, recordings, livestreams, presets, and webhooks have separate resource APIs. Use the [current API reference](https://developers.cloudflare.com/api/resources/realtime_kit/) for their paths and bodies.

The Cloudflare SDK unwraps the outer API envelope; the RealtimeKit response still has its own `success` and `data`. A participant token is `data.token` in that response, mapped to `authToken` when initializing the client.

```typescript
import Cloudflare from 'cloudflare';

interface Env { CLOUDFLARE_API_TOKEN: string; CLOUDFLARE_ACCOUNT_ID: string; REALTIMEKIT_APP_ID: string; }
// Inputs below must come from your authenticated, authorized application session.
async function addParticipant(env: Env, meetingId: string, userId: string, name: string, preset: string) {
  const client = new Cloudflare({ apiToken: env.CLOUDFLARE_API_TOKEN });
  const result = await client.realtimeKit.meetings.addParticipant(meetingId, {
    account_id: env.CLOUDFLARE_ACCOUNT_ID,
    app_id: env.REALTIMEKIT_APP_ID,
    name,
    preset_name: preset,
    custom_participant_id: userId,
  });
  if (!result.success || !result.data?.token) throw new Error('Participant creation failed');
  return { authToken: result.data.token };
}
```

Authorize meeting membership before calling this function. Never let a request body choose a host preset. Handle SDK/network errors at the route boundary and return a generic error response without exposing credentials or upstream payloads.

[Configuration](configuration.md) · [Patterns](patterns.md) · [Overview](README.md)
