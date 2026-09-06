# Cloudflare RealtimeKit

RealtimeKit supplies meeting state, media transport, and UI components for web/mobile audio-video applications. Use raw [Realtime SFU](../realtime-sfu/) when you need direct WebRTC signaling control.

## Concepts

An app groups meetings, presets, participants, and recordings. A meeting is reusable; a session is a live instance. A participant credential authenticates one participant; do not share it between users. Presets assign permissions and UI defaults. Keep staging and production apps separate.

## Quick Start

1. Create an API token with Realtime / Realtime Admin permissions.
2. Create an app and preset in the dashboard, then create a meeting and add a participant through the backend REST API.
3. Pass the returned participant token as the client SDK's `authToken` option.
4. Initialize a meeting object and pass that object to the UI component.

```bash
npm install @cloudflare/realtimekit-react @cloudflare/realtimekit-react-ui
```

```tsx
import { useState } from 'react';
import { useRealtimeKitClient, RealtimeKitProvider } from '@cloudflare/realtimekit-react';
import { RtkMeeting } from '@cloudflare/realtimekit-react-ui';

export function MeetingPage({ authToken }: { authToken: string }) {
  const [meeting, initMeeting] = useRealtimeKitClient();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string>();
  async function start() {
    setPending(true);
    setError(undefined);
    try {
      await initMeeting({ authToken, defaults: { audio: true, video: true } });
    } catch {
      setError('Could not initialize the meeting. Please try again.');
    } finally {
      setPending(false);
    }
  }
  if (!meeting) return <div>
    <button disabled={pending} onClick={start}>Join meeting</button>
    {error && <p role="alert">{error}</p>}
  </div>;
  return <RealtimeKitProvider value={meeting}>
    <RtkMeeting meeting={meeting} showSetupScreen={true} leaveOnUnmount={true} />
  </RealtimeKitProvider>;
}
```

Keep this component keyed by participant/meeting identity so changing credentials creates a fresh lifecycle. The setup screen handles joining; avoid joining a second time yourself.

## Reading Order

- [configuration.md](configuration.md): packages, credentials, media settings, branding.
- [api.md](api.md): SDK methods and backend token creation.
- [patterns.md](patterns.md): custom controls, events, plugins, cleanup.
- [gotchas.md](gotchas.md): initialization, permissions, reconnects and verification.

[Official quickstart](https://developers.cloudflare.com/realtime/realtimekit/quickstart/) · [API reference](https://developers.cloudflare.com/api/resources/realtime_kit/)
