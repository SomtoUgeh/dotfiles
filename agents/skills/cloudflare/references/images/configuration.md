# Configuration

## Wrangler Integration

### Workers Binding Setup

Add to `wrangler.toml`:

```toml
name = "my-image-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[images]
binding = "IMAGES"
```

Access in Worker:

```typescript
interface Env {
  IMAGES: ImagesBinding;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (!request.body) return new Response("Image body required", { status: 400 });
    const result = await env.IMAGES.input(request.body)
      .transform({ width: 800 })
      .output({ format: "image/avif", quality: 85 });
    return result.response();
  }
};
```

### Upload via Script

A Node script can use native fetch/FormData with a Blob, or the current hosted-image binding/API. Do not pass the legacy form-data package directly to native fetch:

```typescript
// scripts/upload-image.ts
import { readFile } from 'node:fs/promises';

async function uploadImage(filePath: string, accountId: string, apiToken: string) {
  const form = new FormData();
  form.append('file', new Blob([await readFile(filePath)]), 'image.jpg');
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v1`,
    { method: 'POST', headers: { Authorization: `Bearer ${apiToken}` }, body: form }
  );
  if (!response.ok) throw new Error(`Upload failed: ${response.status}`);
  return response.json(); // Validate success/result from the returned envelope.
}
```

### Environment Variables

Store account hash for URL construction:

```toml
[vars]
IMAGES_ACCOUNT_HASH = "your-account-hash"
ACCOUNT_ID = "your-account-id"
```

Access in Worker:

```typescript
const imageUrl = `https://imagedelivery.net/${env.IMAGES_ACCOUNT_HASH}/${imageId}/public`;
```

## Variants Configuration

Variants are named presets for transformations.

### Create Variant (Dashboard)

1. Navigate to Images → Variants
2. Click "Create Variant"
3. Set name (e.g., `thumbnail`)
4. Configure: `width=200,height=200,fit=cover`

### Create Variant (API)

```bash
curl -X POST \
  https://api.cloudflare.com/client/v4/accounts/{account_id}/images/v1/variants \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "thumbnail",
    "options": {
      "width": 200,
      "height": 200,
      "fit": "cover"
    },
    "neverRequireSignedURLs": false
  }'
```

### Use Variant

```
https://imagedelivery.net/{account_hash}/{image_id}/thumbnail
```

### Common Variant Presets

```json
{
  "thumbnail": {
    "width": 200,
    "height": 200,
    "fit": "cover"
  },
  "avatar": {
    "width": 128,
    "height": 128,
    "fit": "cover",
    "gravity": "face"
  },
  "hero": {
    "width": 1920,
    "height": 1080,
    "fit": "cover",
    "quality": 90
  },
  "mobile": {
    "width": 640,
    "fit": "scale-down",
    "quality": 80,
    "format": "avif"
  }
}
```

## Authentication

### API Token (Recommended)

Generate at: Dashboard → My Profile → API Tokens

Required permissions:
- Account → Cloudflare Images → Edit

```bash
curl -H "Authorization: Bearer {api_token}" \
  https://api.cloudflare.com/client/v4/accounts/{account_id}/images/v1
```

### API Key (Legacy)

```bash
curl -H "X-Auth-Email: {email}" \
     -H "X-Auth-Key: {api_key}" \
  https://api.cloudflare.com/client/v4/accounts/{account_id}/images/v1
```

## Signed URLs

For private images, enable signed URLs:

```bash
# Upload with signed URLs required
curl -X POST \
  https://api.cloudflare.com/client/v4/accounts/{account_id}/images/v1 \
  -H "Authorization: Bearer {api_token}" \
  -F file=@private.jpg \
  -F requireSignedURLs=true
```

Generate signed URL:

```typescript
import { createHmac } from 'node:crypto';

function signUrl(accountHash: string, imageId: string, variant: string, expirySeconds: number, key: string): string {
  if (!Number.isSafeInteger(expirySeconds) || expirySeconds <= Math.floor(Date.now() / 1000)) {
    throw new RangeError('Expiry must be a future Unix timestamp in seconds');
  }
  const path = [accountHash, imageId, variant].map(encodeURIComponent).join('/');
  const url = new URL(`https://imagedelivery.net/${path}`);
  url.searchParams.set('exp', String(expirySeconds));
  const signature = createHmac('sha256', key)
    .update(url.pathname + '?' + url.searchParams.toString()).digest('hex');
  url.searchParams.set('sig', signature);
  return url.toString();
}

// Sign only images/variants the authenticated caller is authorized to view.
const expiry = Math.floor(Date.now() / 1000) + 3600;
```

## Local Development

```bash
npx wrangler dev --remote
```

Check the current binding development support. A local Worker can use a hosted Images binding with `remote: true`; this requires authentication and incurs service usage. Local mocks do not prove hosted transformations or delivery.

Signing source: [private image URLs](https://developers.cloudflare.com/images/optimization/hosted-images/serve-private-images/). The signed message includes the account hash, complete path, question mark, and `exp` query string. A variant with `neverRequireSignedURLs: true` intentionally bypasses private-image signing.
