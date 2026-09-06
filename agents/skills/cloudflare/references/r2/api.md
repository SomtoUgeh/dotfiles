# R2 API Reference

## PUT (Upload)

```typescript
// Basic
await env.MY_BUCKET.put(key, value);

// With metadata
await env.MY_BUCKET.put(key, value, {
  httpMetadata: {
    contentType: 'image/jpeg',
    contentDisposition: 'attachment; filename="photo.jpg"',
    cacheControl: 'max-age=3600'
  },
  customMetadata: { userId: '123', version: '2' },
  storageClass: 'Standard', // or 'InfrequentAccess'
  sha256: arrayBufferOrHex, // Integrity check
  ssecKey: arrayBuffer32bytes // SSE-C encryption
});

// Value types: ReadableStream | ArrayBuffer | string | Blob
```

## GET (Download)

```typescript
const object = await env.MY_BUCKET.get(key);
if (!object) return new Response('Not found', { status: 404 });

// Body: arrayBuffer(), text(), json(), blob(), body (ReadableStream)

// Ranged reads
const object = await env.MY_BUCKET.get(key, { range: { offset: 0, length: 1024 } });

// Conditional GET
const object = await env.MY_BUCKET.get(key, { onlyIf: { etagMatches: 'abc123' } });
```

## HEAD (Metadata Only)

```typescript
const object = await env.MY_BUCKET.head(key); // Returns R2Object without body
```

## DELETE

```typescript
await env.MY_BUCKET.delete(key);
await env.MY_BUCKET.delete([key1, key2, key3]); // Batch (max 1000)
```
## LIST

```typescript
const listed = await env.MY_BUCKET.list({
  limit: 1000,
  prefix: 'photos/',
  cursor: cursorFromPrevious,
  delimiter: '/',
  include: ['httpMetadata', 'customMetadata']
});

// Iterate pages without dropping prefix/delimiter/include filters.
const options: R2ListOptions = { prefix: 'photos/', delimiter: '/', include: ['httpMetadata', 'customMetadata'] };
let cursor: string | undefined;
do {
  const page = await env.MY_BUCKET.list({ ...options, cursor });
  for (const object of page.objects) console.log(object.key);
  // Also process page.delimitedPrefixes when listing virtual directories.
  cursor = page.truncated ? page.cursor : undefined;
} while (cursor);

```

## Multipart Uploads

```typescript
const multipart = await env.MY_BUCKET.createMultipartUpload(key, {
  httpMetadata: { contentType: 'video/mp4' }
});

const uploadedParts: R2UploadedPart[] = [];
for (let i = 0; i < partCount; i++) {
  const part = await multipart.uploadPart(i + 1, partData);
  uploadedParts.push(part);
}

const object = await multipart.complete(uploadedParts);
// OR: await multipart.abort();

// Resume
const multipart = env.MY_BUCKET.resumeMultipartUpload(key, uploadId);
```

## Presigned URLs (S3 SDK)

```typescript
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId: env.R2_ACCESS_KEY_ID, secretAccessKey: env.R2_SECRET_ACCESS_KEY }
});

const uploadUrl = await getSignedUrl(s3, new PutObjectCommand({ Bucket: 'my-bucket', Key: key }), { expiresIn: 3600 });
return Response.json({ uploadUrl });
```

## TypeScript Types

Run `wrangler types` and use the generated runtime types. R2 `get` has overloads: a conditional read can return metadata without a body. Narrow with `"body" in object` before accessing it. `R2Objects` is a discriminated union: `cursor` exists only when `truncated` is true. SSE-C accepts a 32-byte ArrayBuffer or a hex string. Do not replace these types with partial local interfaces.

[Current Workers API reference](https://developers.cloudflare.com/r2/api/workers/workers-api-reference/)

## CLI Operations

```bash
wrangler r2 object put my-bucket/file.txt --file=./local.txt --remote
wrangler r2 object get my-bucket/file.txt --file=./download.txt --remote
wrangler r2 object delete my-bucket/file.txt --remote
# List objects using the Workers binding or S3 ListObjectsV2.
```
