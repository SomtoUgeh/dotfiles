# Images API

## Workers binding

```toml
[images]
binding = "IMAGES"
```

The type is `ImagesBinding`. Input is a byte stream. Geometry goes in `transform`; MIME format and encoding quality go in `output`. Await output before calling `response()`.

```typescript
async function resize(images: ImagesBinding, input: ReadableStream<Uint8Array>) {
  const result = await images.input(input)
    .transform({ width: 800, height: 600, fit: "cover" })
    .output({ format: "image/avif", quality: 85 });
  return result.response();
}
```

Use `file.stream()`, an R2 object's `body`, or a non-null fetch response body. Do not pass an ArrayBuffer directly. For bytes held in memory, construct a Blob and use its stream.

## Watermarks

```typescript
async function watermark(images: ImagesBinding, base: ReadableStream<Uint8Array>, mark: ReadableStream<Uint8Array>) {
  return images.input(base)
    .draw(images.input(mark).transform({ width: 100 }), { top: 10, left: 10, opacity: 0.8 })
    .output({ format: "image/webp", quality: 85 });
}
```

Read the generated `ImageTransform`, `ImageDrawOptions`, and `ImageOutputOptions` types for supported options. URL transformation parameters are not an interchangeable binding interface. Binding output uses MIME strings such as `image/avif`, not `avif` or `auto`.

## Hosted Images and REST

Current generated bindings also expose `env.IMAGES.hosted` for supported hosted-image operations; consult the [current hosted binding API](https://developers.cloudflare.com/images/). Existing REST APIs remain available:

```bash
curl --fail-with-body -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/images/v1" \
  -H "Authorization: Bearer $IMAGES_TOKEN" \
  -F file=@image.jpg -F metadata='{"purpose":"example"}'
```

The v1 image detail/delete path is `/accounts/{account_id}/images/v1/{image_id}`. List endpoints are paginated; check response success and pagination.

## Direct Creator Upload

After authenticating the uploader, create a limited upload URL from the backend. The REST endpoint accepts form fields:

```typescript
async function createUpload(accountId: string, token: string, userId: string) {
  const form = new FormData();
  form.set("requireSignedURLs", "true");
  form.set("metadata", JSON.stringify({ userId }));
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v2/direct_upload`,
    { method: "POST", headers: { Authorization: `Bearer ${token}` }, body: form }
  );
  if (!response.ok) throw new Error(`Upload URL request failed: ${response.status}`);
  return response.json(); // Validate the Cloudflare envelope before exposing result.uploadURL.
}
```

The client uploads a FormData `file` to the returned `uploadURL` without the account API token. Check upload completion and associate the image ID with the authenticated owner server-side. Choose signed/private or public delivery deliberately.

## Delivery URLs

Named variants use `https://imagedelivery.net/{account_hash}/{image_id}/{variant}`. Inline transformation options require flexible variants to be enabled. Transforming remote origin images through `/cdn-cgi/image/...` is a separate delivery path.

Sources: [Workers binding](https://developers.cloudflare.com/images/optimization/binding/), [direct uploads](https://developers.cloudflare.com/images/storage/upload-images/direct-creator-upload/).
