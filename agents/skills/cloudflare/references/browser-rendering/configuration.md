# Configuration & Setup

## Installation

```bash
npm install @cloudflare/puppeteer  # or @cloudflare/playwright
```

**Use Cloudflare packages** - standard `puppeteer`/`playwright` won't work in Workers.

## wrangler.json

```json
{
  "name": "browser-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01",
  "compatibility_flags": ["nodejs_compat"],
  "browser": {
    "binding": "MYBROWSER"
  }
}
```

**Required:** `nodejs_compat` flag and `browser.binding`.

## TypeScript

```typescript
interface Env {
  MYBROWSER: Fetcher;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // ...
  }
} satisfies ExportedHandler<Env>;
```

## Development

```bash
wrangler dev  # Set browser.remote: true to use the hosted browser binding
```

The Worker can run locally with a hosted browser through `"browser": { "binding": "MYBROWSER", "remote": true }`. This requires account authentication and consumes remote browser usage. See [remote binding setup](https://developers.cloudflare.com/browser-run/get-started/).

## REST API

No wrangler config needed. Get API token with "Browser Rendering - Edit" permission.

```bash
curl -X POST \
  'https://api.cloudflare.com/client/v4/accounts/{accountId}/browser-rendering/screenshot' \
  -H 'Authorization: Bearer TOKEN' \
  -d '{"url": "https://example.com"}' --output screenshot.png
```

## Requirements

| Requirement | Value |
|-------------|-------|
| Node.js compatibility | `nodejs_compat` flag |
| Compatibility date | Use a tested modern date supporting the installed package and nodejs_compat |
| Module format | ES modules only |
| Browser | Hosted Chromium; inspect the current browser version |

**Not supported:** WebGL, WebRTC, extensions, `file://` protocol, Service Worker syntax.

## Troubleshooting

| Error | Solution |
|-------|----------|
| `MYBROWSER is undefined` | Check the browser binding name and use `remote: true` for hosted browser access |
| `nodejs_compat not enabled` | Add to `compatibility_flags` |
| `Module not found` | `npm install @cloudflare/puppeteer` |
| `Browser Rendering not available` | Enable in dashboard |

Current product name: **Browser Run**. The REST path remains `/browser-rendering`. [Official documentation](https://developers.cloudflare.com/browser-run/).
