# API Reference

## ASSETS Binding

The `ASSETS` binding provides access to static assets via the `Fetcher` interface.

### Type Definition

```typescript
interface Env {
  ASSETS: Fetcher;
}

interface Fetcher {
  fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>;
}
```

### Method Signatures

```typescript
// 1. Forward entire request
await env.ASSETS.fetch(request);

// 2. String path (hostname ignored, only path matters)
await env.ASSETS.fetch("https://any-host/path/to/asset.png");

// 3. URL object
await env.ASSETS.fetch(new URL("/index.html", request.url));

// 4. Constructed Request object
await env.ASSETS.fetch(new Request(new URL("/logo.png", request.url), {
  method: "GET",
  headers: request.headers
}));
```

**Key behaviors:**

- Host/origin is ignored for string/URL inputs (only path is used)
- Methods GET and HEAD are supported; other methods return 405
- Request headers pass through (affects response)
- Returns standard `Response` object

## Request Handling

### Path Resolution

```typescript
// All resolve to same asset:
env.ASSETS.fetch("https://example.com/logo.png")
env.ASSETS.fetch("https://ignored.host/logo.png")
env.ASSETS.fetch(new URL("/logo.png", request.url))
```

Assets are resolved relative to configured `assets.directory`.

### Headers

Request headers that affect response:

| Header | Effect |
|--------|--------|
| `Accept-Encoding` | Controls compression (gzip, brotli) |
| `Range` | Enables partial content (206 responses) |
| `If-None-Match` | Conditional request via ETag |
| `If-Modified-Since` | Conditional request via modification date |

Custom headers pass through but don't affect asset serving.

### Method Support

| Method | Supported | Response |
|--------|-----------|----------|
| `GET` | ✅ Yes | Asset content |
| `HEAD` | ✅ Yes | Headers only, no body |
| `POST`, `PUT`, etc. | ❌ No | 405 Method Not Allowed |

## Response Behavior

### Content-Type Inference

Automatically set based on file extension:

| Extension | Content-Type |
|-----------|--------------|
| `.html` | `text/html; charset=utf-8` |
| `.css` | `text/css` |
| `.js` | `application/javascript` |
| `.json` | `application/json` |
| `.png` | `image/png` |
| `.jpg`, `.jpeg` | `image/jpeg` |
| `.svg` | `image/svg+xml` |
| `.woff2` | `font/woff2` |

### Default Headers

Responses include:

```
Content-Type: <inferred>
ETag: "<hash>"
Cache-Control: public, max-age=0, must-revalidate
Content-Encoding: br  (if supported and beneficial)
```

**Cache-Control defaults:**

- Default browser policy is `public, max-age=0, must-revalidate`; see the [headers reference](https://developers.cloudflare.com/workers/static-assets/headers/)
- Override via Worker response transformation (see patterns.md:27-35)

### Compression

Automatic compression based on `Accept-Encoding`:

- **Brotli** (`br`): Preferred, best compression
- **Gzip** (`gzip`): Fallback
- **None**: If client doesn't support or asset too small

### ETag Generation

ETags are content-based hashes:

```
ETag: "a3b2c1d4e5f6..."
```

Used for conditional requests (`If-None-Match`). Returns `304 Not Modified` if match.

## Error Responses

| Status | Condition | Behavior |
|--------|-----------|----------|
| `404` | Asset not found | Body depends on `not_found_handling` config |
| `405` | Non-GET/HEAD method | `{ "error": "Method not allowed" }` |
| `416` | Invalid Range header | Range not satisfiable |

### 404 Handling

Depends on configuration (see configuration.md:45-52):

```typescript
// not_found_handling: "single-page-application"
// Returns /index.html with 200 status

// not_found_handling: "404-page"
// Returns /404.html if exists, else 404 response

// not_found_handling: "none"
// Returns 404 response
```

## Advanced Usage

### Modifying Responses

```typescript
const response = await env.ASSETS.fetch(request);
const headers = new Headers(response.headers);
headers.set('Cache-Control', 'public, max-age=31536000');
headers.set('X-Custom', 'value');

// Clone and modify
return new Response(response.body, {
  status: response.status,
  headers
});
```

See patterns.md:27-35 for full example.

### Error Handling

```typescript
const response = await env.ASSETS.fetch(request);

if (response.status === 404) {
  // Asset not found or error
  return new Response('Custom error page', { status: 404 });
}

return response;
```

### Conditional Serving

```typescript
const url = new URL(request.url);

// Serve different assets based on conditions
if (url.pathname === '/') {
  return env.ASSETS.fetch(new URL('/index.html', request.url));
}

return env.ASSETS.fetch(request);
```

See patterns.md for complete patterns.
