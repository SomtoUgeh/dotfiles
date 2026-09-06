# Cloudflare Images Skill Reference

**Cloudflare Images** is an end-to-end image management solution providing storage, transformation, optimization, and delivery at scale via Cloudflare's global network.

## Quick Decision Tree

**Need to:**
- **Transform in Worker?** → [api.md](api.md#workers-binding) (Workers Binding API)
- **Upload from Worker?** → [api.md](api.md#hosted-images-and-rest) (hosted binding or REST)
- **Upload from client?** → [patterns.md](api.md#direct-creator-upload) (Direct Creator Upload)
- **Set up variants?** → [configuration.md](configuration.md#variants-configuration)
- **Serve responsive images?** → [patterns.md](patterns.md#responsive-images)
- **Add watermarks?** → [patterns.md](patterns.md#watermarking)
- **Fix errors?** → [gotchas.md](gotchas.md#common-errors)

## Reading Order

**For building image upload/transform feature:**
1. [configuration.md](configuration.md) - Setup Workers binding
2. [api.md](api.md#workers-binding) - Learn transform API
3. [patterns.md](api.md#direct-creator-upload) - Direct upload pattern
4. [gotchas.md](gotchas.md) - Check limits and errors

**For URL-based transforms:**
1. [configuration.md](configuration.md#variants-configuration) - Create variants
2. [api.md](api.md#url-transform-api) - URL syntax
3. [patterns.md](patterns.md#responsive-images) - Responsive patterns

**For troubleshooting:**
1. [gotchas.md](gotchas.md#common-errors) - Error messages
2. [gotchas.md](gotchas.md#limits) - Size/format limits

## Core Methods

| Method | Use Case | Location |
|--------|----------|----------|
| `env.IMAGES.input().transform()` | Transform in Worker | [api.md:11](api.md) |
| REST API `/images/v1` | Upload images | [api.md:57](api.md) |
| Direct Creator Upload | Client-side upload | [api.md:127](api.md) |
| URL transforms | Static image delivery | [api.md:112](api.md) |

## In This Reference

- **[api.md](api.md)** - Complete API: Workers binding, REST endpoints, URL transforms
- **[configuration.md](configuration.md)** - Setup: wrangler.toml, variants, auth, signed URLs
- **[patterns.md](patterns.md)** - Patterns: responsive images, watermarks, format negotiation, caching
- **[gotchas.md](gotchas.md)** - Troubleshooting: limits, errors, best practices

## Key Features

- **Automatic Optimization** - AVIF/WebP format negotiation
- **On-the-fly Transforms** - Resize, crop, blur, sharpen via URL or API
- **Workers Binding** - Transform images in Workers (stream transformation API)
- **Direct Upload** - Secure client-side uploads without backend proxy
- **Global Delivery** - Delivered through Cloudflare
- **Watermarking** - Overlay images programmatically

## See Also

- [Official Docs](https://developers.cloudflare.com/images/)
- [Workers Examples](https://developers.cloudflare.com/images/tutorials/)
