# Workers for Platforms gotchas

## Dispatch failures

Await the delegated fetch inside the try block; otherwise an asynchronous
rejection bypasses the catch. Narrow unknown errors before reading fields.

```typescript
export async function dispatch(request: Request, dispatcher: DispatchNamespace, name: string): Promise<Response> {
  try {
    const worker = dispatcher.get(name);
    return await worker.fetch(request);
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('Worker not found')) {
      return new Response('Worker not found', { status: 404 });
    }
    throw error;
  }
}
```

Determine the name from a trusted platform routing record. Do not expose arbitrary
Worker names to callers or classify every runtime error as "not found".

## Uploads and preserved configuration

- Use a multipart module upload with `metadata.main_module` matching the file name.
- SDK method signatures do not prove multipart serialization is correct. The
  current SDK 7.1.0 transport fixture failed that check; [patterns.md](./patterns.md)
  uses the documented REST multipart format. Verify headers, metadata JSON, and
  named module parts when changing the upload implementation.
- `metadata.keep_bindings` is an array of binding **types**, such as
  `['secret_text']`; it is not a boolean. Explicitly preserve or resend each
  required binding/configuration and verify the resulting script settings.
- Use real returned KV/D1/R2 resource identifiers, not names constructed from a
  tenant ID. Creating a namespace and binding to one are separate operations.

## Static assets

Assets are associated with a dispatch namespace and may be reused by hash across
user Workers. Keep upload/completion JWTs in trusted platform services. Use a
stable tenant-specific hash input when tenant isolation is required. The manifest
hash is 32 hex characters; a consistent truncated SHA-256 scheme is documented.
Upload file contents as required by the assets endpoint; the upload and completion
tokens each have one-hour lifetimes. A session response alone does not upload files.

## Limits and isolation

| Constraint | Current documented behavior |
| --- | --- |
| User Worker scripts | Unlimited for Workers for Platforms customers |
| Durable Object namespaces | No WfP namespace limit |
| Tags per script | Eight; avoid comma/ampersand in tags |
| `request.cf` in user Worker | Unavailable by default; trusted mode requires controlling all code |
| `caches.default` in namespaced script | Disabled; follow the documented cache model |
| Gradual deployment of user Workers | Not supported; user-script updates deploy all at once |
| Client API rate limit | 1200/5min per user/account token, cumulative across dashboard/key/token |
| Client API per IP | 200/second |

Use SDK retry settings/Retry-After handling for control-plane rate limits. A
concurrency limit does not guarantee rate-limit compliance. Do not wrap retries
in a helper that silently succeeds when its attempt count is zero.

Outbound Workers do not intercept every operation. Check the current outbound
Worker restrictions, including DO/mTLS fetch and TCP socket behavior, before
claiming complete egress mediation. Monitor CPU/subrequest limit failures and
return the application's documented failure response.

Sources: [limits](https://developers.cloudflare.com/cloudflare-for-platforms/workers-for-platforms/reference/limits/),
[static assets](https://developers.cloudflare.com/cloudflare-for-platforms/workers-for-platforms/configuration/static-assets/),
[upload API](https://developers.cloudflare.com/api/resources/workers_for_platforms/subresources/dispatch/subresources/namespaces/subresources/scripts/methods/update/).
