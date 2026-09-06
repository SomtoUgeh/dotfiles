# R2 Gotchas & Troubleshooting

## List Truncation

```typescript
// ❌ WRONG: Don't compare object count when using include
while (listed.objects.length < options.limit) { ... }

// ✅ CORRECT: Always use truncated property
let page = await env.MY_BUCKET.list(options);
for (;;) {
  for (const object of page.objects) console.log(object.key);
  if (!page.truncated) break;
  page = await env.MY_BUCKET.list({ ...options, cursor: page.cursor });
}
```

**Reason:** `include` with metadata may return fewer objects per page to fit metadata.

## ETag Format

```typescript
// ❌ WRONG: Using etag (unquoted) in headers
headers.set('etag', object.etag); // Missing quotes

// ✅ CORRECT: Use httpEtag (quoted)
headers.set('etag', object.httpEtag);
```

## Checksum Limits

Only ONE checksum algorithm allowed per PUT:

```typescript
// ❌ WRONG: Multiple checksums
await env.MY_BUCKET.put(key, data, { md5: hash1, sha256: hash2 }); // Error

// ✅ CORRECT: Pick one
await env.MY_BUCKET.put(key, data, { sha256: hash });
```

## Multipart Requirements

- All parts must be uniform size (except last part)
- Part numbers start at 1 (not 0)
- Uncompleted uploads auto-abort after 7 days
- `resumeMultipartUpload` doesn't validate uploadId existence

## Conditional Operations

```typescript
// Precondition failure returns object WITHOUT body
const object = await env.MY_BUCKET.get(key, {
  onlyIf: { etagMatches: 'wrong' }
});

// Check for body, not just null
if (!object) return new Response('Not found', { status: 404 });
if (!('body' in object)) return new Response(null, { status: 412 }); // If-Match failed
// A matching If-None-Match on GET/HEAD instead maps to 304.
```

## Key Authorization

R2 keys are object names, not filesystem paths. Rejecting `..` does not authorize a caller. Authenticate first and derive an allowed tenant/user prefix on the server; validate the requested key stays within that prefix. Use server-generated upload IDs when clients must not overwrite existing objects.

## Storage Class Pitfalls

- InfrequentAccess: 30-day minimum billing (even if deleted early)
- Can't transition IA → Standard via lifecycle (use S3 CopyObject)
- Retrieval fees apply for IA reads

## Stream Length Requirement

R2 requires a known-length stream. Request/Response bodies with a runtime-known length work directly; arbitrary transformed streams may not. An unsupported stream raises an error; do not describe this as silent truncation. `httpMetadata.contentLength` does not exist and cannot supply the length.

Use `FixedLengthStream` when the exact length is known and await both the write and upload promises. Otherwise use bounded buffering for small payloads or multipart uploads for large ones. Do not buffer an unbounded response in the Worker's 128 MiB memory.

## S3 SDK Region Configuration

```typescript
// ❌ WRONG: Missing region breaks ALL S3 SDK calls
const s3 = new S3Client({
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: { ... }
});

// ✅ CORRECT: MUST set region='auto'
const s3 = new S3Client({
  region: 'auto', // REQUIRED
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: { ... }
});
```

**Reason:** S3 SDK requires region. R2 uses 'auto' as placeholder.

## Local Development

Wrangler/Miniflare emulate R2 including multipart uploads. Wrangler persists local state under `.wrangler/state`; configure Miniflare persistence explicitly when using its API. Local binding tests do not verify the hosted S3 endpoint, signed URL authorization, CORS, or public-domain delivery. Use a dedicated remote test bucket for those checks.

## Presigned URL Expiry

```typescript
// ❌ WRONG: URL expires but no client validation
const url = await getSignedUrl(s3, command, { expiresIn: 60 });
// 61 seconds later: 403 Forbidden

// ✅ CORRECT: Return expiry to client
return Response.json({
  uploadUrl: url,
  expiresAt: new Date(Date.now() + 60000).toISOString()
});
```

## Limits

| Limit | Value |
|-------|-------|
| Object size | 5 TB |
| Multipart part count | 10,000 |
| Multipart part min size | 5 MB (except last) |
| Batch delete | 1,000 keys |
| List limit | 1,000 per request |
| Key size | 1024 bytes |
| Custom metadata | 2 KB per object |
| Presigned URL max expiry | 7 days |

## Common Errors

### "Stream upload failed"

**Cause:** Stream length unknown or Content-Length missing
**Solution:** Use a runtime-known-length body, FixedLengthStream, bounded buffering, or multipart upload

### "Invalid credentials" / S3 SDK

**Cause:** Missing `region: 'auto'` in S3Client config
**Solution:** Always set `region: 'auto'` for R2

### "Object not found"

**Cause:** Object key doesn't exist or was deleted
**Solution:** Verify object key correct, check if object was deleted, ensure bucket correct

### "List compatibility error"

**Cause:** Missing or old compatibility_date, or flag not enabled
**Solution:** Set `compatibility_date >= 2022-08-04` or enable `r2_list_honor_include` flag

### "Multipart upload failed"

**Cause:** Part sizes not uniform or incorrect part number
**Solution:** Ensure uniform size except final part, verify part numbers start at 1
