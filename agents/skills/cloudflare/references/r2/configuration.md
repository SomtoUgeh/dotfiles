# R2 Configuration

## Workers Binding

**wrangler.jsonc:**
```jsonc
{
  "r2_buckets": [
    {
      "binding": "MY_BUCKET",
      "bucket_name": "my-bucket-name"
    }
  ]
}
```

## TypeScript Types

```typescript
interface Env { MY_BUCKET: R2Bucket; }

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const object = await env.MY_BUCKET.get('file.txt');
    if (!object) return new Response('Not found', { status: 404 });
    return new Response(object.body);
  }
}
```

## S3 SDK Setup

```typescript
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY
  }
});

await s3.send(new PutObjectCommand({
  Bucket: 'my-bucket',
  Key: 'file.txt',
  Body: data,
  StorageClass: 'STANDARD' // or 'STANDARD_IA'
}));
```

## Location Hints

```bash
wrangler r2 bucket create my-bucket --location=enam

# Hints: wnam, enam, weur, eeur, apac, oc
# Jurisdictions (override hint): --jurisdiction=eu (or fedramp)
```

## CORS Configuration

CORS can be configured via Wrangler (`r2 bucket cors set`), S3 SDK, REST API, or dashboard (not available in Workers API):

```typescript
import { S3Client, PutBucketCorsCommand } from '@aws-sdk/client-s3';

const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY
  }
});

await s3.send(new PutBucketCorsCommand({
  Bucket: 'my-bucket',
  CORSConfiguration: {
    CORSRules: [{
      AllowedOrigins: ['https://example.com'],
      AllowedMethods: ['GET', 'PUT', 'HEAD'],
      AllowedHeaders: ['*'],
      ExposeHeaders: ['ETag'],
      MaxAgeSeconds: 3600
    }]
  }
}));
```

## Object Lifecycles

```typescript
import { PutBucketLifecycleConfigurationCommand } from '@aws-sdk/client-s3';

await s3.send(new PutBucketLifecycleConfigurationCommand({
  Bucket: 'my-bucket',
  LifecycleConfiguration: {
    Rules: [
      {
        ID: 'expire-old-logs',
        Status: 'Enabled',
        Prefix: 'logs/',
        Expiration: { Days: 90 }
      },
      {
        ID: 'transition-to-ia',
        Status: 'Enabled',
        Prefix: 'archives/',
        Transitions: [{ Days: 30, StorageClass: 'STANDARD_IA' }]
      }
    ]
  }
}));
```

## API Token Scopes

When creating R2 tokens, set minimal permissions:

| Permission | Use Case |
|------------|----------|
| Object Read | Public serving, downloads |
| Object Read & Write | Full object operations |
| Admin Read & Write | Bucket management, CORS, lifecycles |

**Best practice:** Worker bindings need no S3 token. Scope external S3 credentials to the required buckets and separate object access from bucket administration.

## Event Notifications

Configure bucket notification rules through Wrangler or the R2 API; `event_notifications` is not a Worker configuration field.

```bash
wrangler queues create r2-events
wrangler r2 bucket notification create my-bucket --queue r2-events --event-types object-create object-delete
```

Configure the consuming Worker separately:

```jsonc
{ "queues": { "consumers": [{ "queue": "r2-events", "max_batch_size": 10 }] } }
```

R2 publishes events directly; no producer binding is required. Validate each message against the [event notification schema](https://developers.cloudflare.com/r2/buckets/event-notifications/) and make processing idempotent. Object creation includes `PutObject`, `CopyObject`, and `CompleteMultipartUpload`; do not handle only `PutObject` when all uploads matter.

## Bucket Management

```bash
wrangler r2 bucket create my-bucket --location=enam --storage-class=Standard
wrangler r2 bucket list
wrangler r2 bucket info my-bucket
wrangler r2 bucket delete my-bucket  # Must be empty
wrangler r2 bucket update-storage-class my-bucket --storage-class=InfrequentAccess

# Public bucket via dashboard
wrangler r2 bucket domain add my-bucket --domain=files.example.com --zone-id=<ZONE_ID>
```
