---
title: Load External Scripts Without Blocking Rendering
impact: HIGH
impactDescription: avoids parser-blocking scripts and respects framework loading semantics
tags: rendering, script, async, next-script, performance
---

## Load External Scripts Without Blocking Rendering

**Impact: HIGH (avoids render-blocking scripts)**

In React, use an external `<script async>` when the script can execute independently. React can hoist and deduplicate async scripts rendered by components. Do not recommend `defer` as the general React solution: React's streaming and deduplication behavior is designed around scripts with `async={true}`.

**Incorrect: parser-blocking script**

```tsx
export default function Analytics() {
  return <script src="https://example.com/analytics.js" />
}
```

**Correct: independent external script**

```tsx
export default function Analytics() {
  return <script async src="https://example.com/analytics.js" />
}
```

For Next.js, use `next/script` so the framework controls placement and loading. Use `afterInteractive` for scripts that should load after hydration and `lazyOnload` for low-priority scripts.

```tsx
// app/analytics.tsx
import Script from 'next/script'

export function Analytics() {
  return (
    <Script
      src="https://example.com/analytics.js"
      strategy="afterInteractive"
    />
  )
}
```

Reserve `beforeInteractive` for critical, site-wide scripts. In the App Router it must be placed in the root `app/layout.tsx` file.

```tsx
// app/layout.tsx
import Script from 'next/script'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
      <Script src="/scripts/critical.js" strategy="beforeInteractive" />
    </html>
  )
}
```

Do not use `beforeInteractive` for ordinary analytics or page-specific scripts; it is injected into the initial HTML and loads before Next.js hydration.

References:

- [React `<script>`](https://react.dev/reference/react-dom/components/script)
- [Next.js Script component](https://nextjs.org/docs/app/api-reference/components/script)
