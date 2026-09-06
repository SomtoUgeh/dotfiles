# RealtimeKit Patterns

## Custom React Controls

These hooks require a `RealtimeKitProvider` with an initialized meeting (see [README](README.md)).

```tsx
import { useRealtimeKitMeeting, useRealtimeKitSelector } from '@cloudflare/realtimekit-react';

export function AudioToggle() {
  const { meeting } = useRealtimeKitMeeting();
  const enabled = useRealtimeKitSelector(m => m.self.audioEnabled);
  async function toggle() {
    try {
      if (enabled) await meeting.self.disableAudio();
      else await meeting.self.enableAudio();
    } catch (error) {
      console.error('Audio device change failed', error);
    }
  }
  return <button onClick={toggle}>{enabled ? 'Mute' : 'Unmute'}</button>;
}
```

Use UI Kit participant/audio components for a complete grid and remote audio playback. A muted `<video>` for every participant is not a complete meeting implementation. For custom rendering subscribe to participant `videoUpdate`/`audioUpdate` and clear element `srcObject` on cleanup.

## Events and Cleanup

```typescript
import type { RTKParticipant } from '@cloudflare/realtimekit';
const onJoined = (participant: RTKParticipant) => console.log('Participant joined', participant.id);
meeting.participants.joined.on('participantJoined', onJoined);
// On screen teardown:
meeting.participants.joined.off('participantJoined', onJoined);
await meeting.leave();
```

Register listeners before triggering the action. When manually initializing in an effect, handle initialization finishing after unmount and release that instance; avoid duplicate joins during React Strict Mode. The full UI supports `leaveOnUnmount`.

## Plugins

```typescript
const plugin = meeting.plugins.all.get(pluginId);
if (plugin) {
  await plugin.activate();
  // Later:
  await plugin.deactivate();
}
```

Activation belongs to a plugin, not `meeting.plugins.activate(id)`. Use typed plugin state events for updates.

## Waitlists, Recording, and Scheduling

Use preset permissions plus documented participant/waitlist APIs for admission; do not call an invented `/waitlist/approve` endpoint. Scheduling belongs to your application: store meeting IDs and planned times, then authenticate and authorize a user before issuing credentials. Recording/livestream actions require the appropriate preset permissions and a valid meeting/session state.

For audio-only meetings initialize with `video: false, audio: true`. Device switching uses `getAllDevices()` and `setDevice(device)`. Handle permission denial and device removal in UI.

## Token Handling

Return credentials only through an authenticated endpoint with `Cache-Control: no-store`. Keep them out of URLs, logs, analytics, and shared storage. Do not share a participant token between users. Follow actual token expiry/refresh behavior; a token is not universally single-use or guaranteed to expire after 24 hours.

[API](api.md) · [Configuration](configuration.md) · [Troubleshooting](gotchas.md)
