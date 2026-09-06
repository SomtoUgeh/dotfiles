# RealtimeKit Configuration

## Packages and Initialization

React uses `@cloudflare/realtimekit-react` for hooks/provider and `@cloudflare/realtimekit-react-ui` for components. Web Components use the core SDK plus `@cloudflare/realtimekit-ui`; Angular uses its corresponding SDK/UI wrappers. Follow the [current platform quickstart](https://developers.cloudflare.com/realtime/realtimekit/quickstart/) for platform dependencies.

The core class has a private constructor. Use asynchronous initialization:

```typescript
import RealtimeKitClient from '@cloudflare/realtimekit';

const meeting = await RealtimeKitClient.init({
  authToken,
  defaults: {
    audio: true,
    video: true,
    autoSwitchAudioDevice: true,
    mediaConfiguration: {
      video: { width: { ideal: 1280 }, height: { ideal: 720 }, frameRate: { ideal: 30 } },
      audio: { echoCancellation: true, noiseSupression: true, autoGainControl: true },
      screenshare: { width: { max: 1920 }, height: { max: 1080 }, frameRate: { ideal: 15, max: 30 } }
    }
  }
});
// Custom UI only; the full meeting component can handle its own setup/join flow.
await meeting.join();
```

The current SDK spells its audio option `noiseSupression` (one p after Su); use the installed SDK type rather than the browser constraint spelling.

For Web Components assign `element.meeting = meeting`; for Angular bind `[meeting]="meeting"`. `authToken` is an initialization option, not an `RtkMeeting` prop. Register Web Components with the package loader before rendering.

## Backend Configuration

```jsonc
{
  "name": "realtimekit-backend",
  "main": "src/index.ts",
  "compatibility_date": "2026-09-05",
  "vars": { "CLOUDFLARE_ACCOUNT_ID": "<account-id>", "REALTIMEKIT_APP_ID": "<app-id>" }
}
```

```bash
wrangler secret put CLOUDFLARE_API_TOKEN
```

Create presets in the dashboard or use the current [preset API schema](https://developers.cloudflare.com/api/resources/realtime_kit/subresources/presets/methods/create/). Do not invent flat `canRecord`/`canShareAudio` flags; permission structures are versioned. Select a preset server-side from the authenticated user's role.

D1/KV can store application meeting metadata. An R2 binding alone does not configure SDK recording exports. Adding `TURN_SERVICE_ID` to Wrangler variables does not configure the SDK; use RealtimeKit's documented connectivity settings and platform network requirements.

## Branding and Localization

Use the UI package's exported types and current [UI Kit documentation](https://developers.cloudflare.com/realtime/realtimekit/ui-kit/). Pass `config` and `t` to the meeting component with its `meeting` object. UI configuration is not a core SDK type; inspect the installed UI version before choosing tokens or locale APIs. Avoid undocumented `setLocale` calls or a hardcoded supported-language list.

[Overview](README.md) · [API](api.md) · [Patterns](patterns.md) · [Troubleshooting](gotchas.md)
