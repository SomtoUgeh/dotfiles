# ssr-prerender: Configure Static Prerendering and CDN Caching

## Priority: MEDIUM

## Explanation

Static prerendering generates HTML during the production build. Enable it in the `tanstackStart()` Vite plugin and use `pages` for explicit routes that crawling cannot discover. For content that changes after the build, return cache headers from the route and let the configured CDN apply its caching policy.

## Bad Example

```tsx
// vite.config.ts — the build never enables prerendering
import viteReact from '@vitejs/plugin-react'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [tanstackStart(), viteReact()],
})
```

## Good Example: Static Prerendering

```tsx
// vite.config.ts
import viteReact from '@vitejs/plugin-react'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [
    tanstackStart({
      prerender: {
        enabled: true,
        crawlLinks: true,
        failOnError: true,
      },
      pages: [
        { path: '/' },
        { path: '/about' },
        { path: '/pricing' },
      ],
    }),
    viteReact(),
  ],
})
```

`crawlLinks` discovers links in prerendered HTML. Add dynamic paths such as `/blog/hello-world` to `pages` explicitly when the crawler cannot reach them.

## Good Example: Per-Page Control

```tsx
tanstackStart({
  prerender: {
    enabled: true,
    crawlLinks: true,
  },
  pages: [
    { path: '/pricing' },
    {
      path: '/internal-preview',
      prerender: { enabled: false },
    },
  ],
})
```

## Good Example: CDN Revalidation Policy

```tsx
// src/routes/blog/$slug.tsx
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/blog/$slug')({
  loader: ({ params }) => fetchPost(params.slug),
  headers: () => ({
    'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300',
  }),
  component: BlogPost,
})
```

This header allows a supporting shared cache to serve the response for 60 seconds and then serve stale content for up to 300 seconds while it refreshes in the background. Cache behavior and purge APIs are controlled by the hosting provider.

## Cache-Control Directives

| Directive | Meaning |
|-----------|---------|
| `s-maxage=N` | Shared-cache freshness lifetime in seconds |
| `max-age=N` | Browser-cache freshness lifetime in seconds |
| `stale-while-revalidate=N` | Time a cache may serve stale content while refreshing |
| `private` | Prevent storage in shared caches |
| `no-store` | Prevent storage in any cache |

## Context

- Prerendered loaders run at build time and cannot use request-specific data.
- Do not prerender personalized pages such as carts or account dashboards.
- TanStack Start does not expose a framework-wide path revalidation function. Use the current purge or invalidation API from the configured host when on-demand invalidation is required.
- Test prerendering with a production build; development mode does not prove which pages will be emitted.

Reference: [TanStack Start Static Prerendering](https://tanstack.com/start/latest/docs/framework/react/guide/static-prerendering)
