# Images Patterns

## Transform a user upload and store in R2

Authenticate the uploader and enforce the application's request/file limits before this handler. Cloudflare transformation limits vary by product path and format.

```typescript
interface Env { IMAGES: ImagesBinding; R2: R2Bucket }
export default {
  async fetch(request, env) {
    if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
    const file = (await request.formData()).get("image");
    if (!(file instanceof File)) return new Response("Image file required", { status: 400 });
    const result = await env.IMAGES.input(file.stream())
      .transform({ width: 800, fit: "scale-down" })
      .output({ format: "image/avif", quality: 80 });
    const key = `images/${crypto.randomUUID()}.avif`;
    await env.R2.put(key, result.image(), { httpMetadata: { contentType: result.contentType() } });
    return Response.json({ key }, { status: 201 });
  }
} satisfies ExportedHandler<Env>;
```

The returned R2 key is not an authorization grant. Serve private objects through authenticated access.

## Responsive delivery

Use named variants or enable flexible variants for inline width transformations. Prefer srcset/sizes to guessing device size from User-Agent.

```html
<img src="https://imagedelivery.net/ACCOUNT_HASH/IMAGE_ID/medium"
  srcset="https://imagedelivery.net/ACCOUNT_HASH/IMAGE_ID/small 400w, https://imagedelivery.net/ACCOUNT_HASH/IMAGE_ID/medium 800w"
  sizes="(max-width: 600px) 100vw, 800px" alt="Product image" />
```

URL-based `format=auto` can negotiate format. Binding output requires an explicit MIME type; if you negotiate from Accept, honor supported media types and q-values, preserve Vary, and include the chosen format in cache identity. Do not return WebP to every client that lacks AVIF.

## Watermarking

Fetch the watermark from a trusted asset binding, check response status and non-null body, then pass its stream or transformer to `draw`. Await `output({ format: "image/webp" })` and return the result's `response()`. See [api.md](api.md).

## Caching public transformations

```typescript
async function cachedImage(request: Request, env: { IMAGES: ImagesBinding; ASSETS: Fetcher }, ctx: ExecutionContext) {
  if (request.method !== "GET") return new Response("Method not allowed", { status: 405 });
  const key = new Request(new URL("/transforms/logo-800-v1.webp", request.url));
  const cached = await caches.default.match(key);
  if (cached) return cached;
  const source = await env.ASSETS.fetch(new URL("/logo.png", request.url));
  if (!source.ok || !source.body) return new Response("Image unavailable", { status: 502 });
  const result = await env.IMAGES.input(source.body).transform({ width: 800 })
    .output({ format: "image/webp", quality: 85 });
  const response = result.response({ headers: { "Cache-Control": "public, max-age=86400" } });
  ctx.waitUntil(caches.default.put(key, response.clone()));
  return response;
}
```

This fixed cache key is only for the one fixed public logo/source version and output format shown. General handlers must key by source revision and every output parameter; keep tenant/private authorization out of shared public caches.

## Upload URLs and errors

Use the backend form-data example in [api.md](api.md) for Direct Creator Upload. Validate the upload result before persisting image ownership. On transformation errors, record the documented error code and return a bounded failure. Retry only transient failures with a bounded policy; never swallow the final error or retry invalid input blindly.
