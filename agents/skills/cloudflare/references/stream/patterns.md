# Stream Patterns

Common workflows, full-stack flows, and best practices.

## React Stream Player

`npm install @cloudflare/stream-react`

```tsx
import { Stream } from '@cloudflare/stream-react';

export function VideoPlayer({ videoId, token }: { videoId: string; token?: string }) {
  return <Stream controls src={token ?? videoId} responsive />;
}
```

## Full-Stack Upload Flow

**Backend API (Workers/Pages)**
```typescript
import Cloudflare from 'cloudflare';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
    // Authenticate and enforce per-user upload quotas before provisioning.
    const body: unknown = await request.json();
    if (typeof body !== 'object' || body === null || !('videoName' in body) ||
        typeof body.videoName !== 'string' || body.videoName.length > 200) {
      return new Response('Invalid video name', { status: 400 });
    }
    const videoName = body.videoName;
    const client = new Cloudflare({ apiToken: env.CF_API_TOKEN });
    const { uploadURL, uid } = await client.stream.directUpload.create({
      account_id: env.CF_ACCOUNT_ID,
      maxDurationSeconds: 3600,
      requireSignedURLs: true,
      meta: { name: videoName }
    });
    if (!uploadURL || !uid) return new Response("Upload provisioning failed", { status: 502 });
    return Response.json({ uploadURL, uid }, { headers: { "Cache-Control": "no-store" } });
  }
};
```

**Frontend upload helper**

```typescript
async function uploadBasicVideo(file: File, uploadURL: string, onProgress: (value: number) => void) {
  if (file.size > 200 * 1024 * 1024) throw new Error('Use TUS for files over 200 MB');
  await new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.upload.onprogress = event => {
      if (event.lengthComputable && event.total > 0) onProgress(event.loaded / event.total * 100);
    };
    xhr.onload = () => xhr.status >= 200 && xhr.status < 300 ? resolve() : reject(new Error(`Upload failed: ${xhr.status}`));
    xhr.onerror = () => reject(new Error('Upload network error'));
    xhr.onabort = () => reject(new Error('Upload cancelled'));
    xhr.ontimeout = () => reject(new Error('Upload timed out'));
    xhr.timeout = 300000;
    xhr.open('POST', uploadURL);
    const data = new FormData();
    data.append('file', file);
    xhr.send(data);
  });
}
```

The UI must reset its loading flag in `finally`, show errors, and cancel an active upload on teardown. Navigate to the UID returned by your backend only after upload success; uploaded does not yet mean encoded/ready.

## TUS Resumable Upload

For files over 200 MB or unreliable connections. `npm install tus-js-client`.

Provision a TUS resource on the backend with `POST /stream?direct_user=true`, `Tus-Resumable: 1.0.0`, a validated Upload-Length, and server-defined Upload-Metadata constraints. Return the successful response Location as `tusUploadURL`. This is not the basic POST direct-upload URL. Keep the separately issued Stream UID rather than deriving it from an opaque URL.

```typescript
import * as tus from 'tus-js-client';

async function uploadWithTUS(file: File, tusUploadURL: string, onProgress?: (pct: number) => void) {
  return new Promise<void>((resolve, reject) => {
    const upload = new tus.Upload(file, {
      uploadUrl: tusUploadURL,
      retryDelays: [0, 3000, 5000, 10000, 20000],
      chunkSize: 50 * 1024 * 1024,
      onError: reject,
      onProgress: (up, total) => { if (total > 0) onProgress?.((up / total) * 100); },
      onSuccess: () => resolve()
    });
    upload.start();
  });
}
```

## Video State Polling

```typescript
async function waitForVideoReady(client: Cloudflare, accountId: string, videoId: string) {
  for (let i = 0; i < 60; i++) {
    const video = await client.stream.get(videoId, { account_id: accountId });
    if (video.status?.state === 'error') throw new Error('Video processing failed');
    if (video.readyToStream) return video;
    await new Promise(resolve => setTimeout(resolve, 5000));
  }
  throw new Error('Video processing timeout');
}
```

## Webhook Handler

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const signature = request.headers.get('Webhook-Signature');
    const body = await request.text();
    if (!signature || !await verifyWebhook(signature, body, env.WEBHOOK_SECRET)) {
      return new Response('Unauthorized', { status: 401 });
    }
    let payload: unknown;
    try { payload = JSON.parse(body); } catch { return new Response('Invalid JSON', { status: 400 }); }
    if (typeof payload !== 'object' || payload === null || !('uid' in payload) || typeof payload.uid !== 'string') {
      return new Response('Invalid event', { status: 400 });
    }
    // Persist an idempotent state update keyed by uid and event/version before acknowledging.
    if ('readyToStream' in payload && payload.readyToStream === true) console.log(`Video ${payload.uid} ready`);
    return new Response('OK');
  }
};

async function verifyWebhook(sig: string, body: string, secret: string): Promise<boolean> {
  const parts = Object.fromEntries(sig.split(',').map(part => part.trim().split('=')));
  const time = parts.time;
  const signature = parts.sig1;
  if (!time || !/^\d+$/.test(time) || !signature || !/^[0-9a-f]{64}$/i.test(signature)) return false;
  const timestamp = Number(time);
  if (!Number.isSafeInteger(timestamp) || Math.abs(Date.now() / 1000 - timestamp) > 300) return false;
  const bytes = new Uint8Array(32);
  for (let i = 0; i < bytes.length; i++) bytes[i] = Number.parseInt(signature.slice(i * 2, i * 2 + 2), 16);
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']
  );
  return crypto.subtle.verify('HMAC', key, bytes, new TextEncoder().encode(`${time}.${body}`));
}
```

## Self-Sign JWT (High Volume Tokens)

Self-sign when API token requests become a scaling bottleneck. Prerequisites: create a signing key (see configuration.md). Authorize playback before minting tokens; use a maintained JWT library when supporting broader claims/keys.

```typescript
async function selfSignToken(keyId: string, jwkBase64: string, videoId: string, expiresIn = 3600) {
  if (!Number.isInteger(expiresIn) || expiresIn <= 0) throw new Error('Invalid token lifetime');
  const key = await crypto.subtle.importKey(
    'jwk', JSON.parse(atob(jwkBase64)), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']
  );
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: 'RS256', kid: keyId })).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const payload = btoa(JSON.stringify({ sub: videoId, kid: keyId, exp: now + expiresIn, nbf: now }))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const message = `${header}.${payload}`;
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(message));
  const b64Sig = btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  return `${message}.${b64Sig}`;
}

// With access rules (geo-restriction)
const payloadWithRules = {
  sub: videoId, kid: keyId, exp: now + 3600, nbf: now,
  accessRules: [{ type: 'ip.geoip.country', action: 'allow', country: ['US'] }, { type: 'any', action: 'block' }]
};
```

## Best Practices

- **Use Direct Creator Uploads** - Avoid proxying through servers
- **Enable requireSignedURLs** - Control private content access
- **Self-sign tokens at scale** - Use signing keys for >1k/day
- **Set allowedOrigins** - Prevent hotlinking
- **Use webhooks over polling** - Efficient status updates
- **Set maxDurationSeconds** - Prevent abuse
- **Enable live recordings** - Auto VOD after stream

## In This Reference

- [README.md](./README.md) - Overview and quick start
- [configuration.md](./configuration.md) - Setup and config
- [api.md](./api.md) - On-demand video APIs
- [api-live.md](./api-live.md) - Live streaming APIs
- [gotchas.md](./gotchas.md) - Error codes, troubleshooting

## See Also

- [workers](../workers/) - Deploy Stream APIs in Workers
- [pages](../pages/) - Integrate Stream with Pages
