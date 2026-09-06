# Images Gotchas

- The Worker type is `ImagesBinding`. `input` accepts a ReadableStream, `transform` applies geometry, and `output({ format: "image/avif", quality: 85 })` returns a Promise. Call `response()` or `image()` on the awaited result.
- URL options and binding options are different APIs. `format: "auto"` is a URL transformation option, not a binding output MIME type. `quality` belongs in binding output, not transform.
- Check fetch status and non-null bodies before transforming. Form fields can be strings as well as Files; validate them before calling `stream()`.
- Direct-upload URL creation uses form-data fields, not the old undocumented JSON body. Uploading a file to the returned URL is a separate client request.
- Native fetch accepts native FormData/Blob. A Node `form-data` instance containing an fs stream is not native FormData.
- Signed URL expiry is Unix seconds. Sign the full pathname (including account hash) plus `?` and query string before adding `sig`. Never enable a public variant accidentally for private uploads.
- Flexible variants must be enabled before relying on inline transformation URLs. Private images and custom-path support have separate restrictions.
- Copy headers with `new Headers(response.headers)`, not object spread of a Headers instance. Preserve Content-Type. Include format/source/size in cache keys and avoid caching private responses publicly.
- Hosted image upload, remote transformations, and binding operations have different file-size and format limits. The old universal 100 MB / 12000-pixel table and invented 540x error mapping are not a contract; check [limits and formats](https://developers.cloudflare.com/images/get-started/limits-and-formats/) and inspect actual errors.
- Test decoded dimensions, output MIME type, invalid input, and signing vectors. A type check or mocked binding does not validate Cloudflare delivery, billing, or a live signature acceptance.

Sources: [binding](https://developers.cloudflare.com/images/optimization/binding/), [private images](https://developers.cloudflare.com/images/optimization/hosted-images/serve-private-images/).
