---
title: Defer Non-Critical Third-Party Libraries
impact: MEDIUM
impactDescription: loads after hydration
tags: bundle, third-party, analytics, defer
---

## Defer Non-Critical Third-Party Libraries

Use a Client Component for Next.js dynamic imports with `ssr: false`. This option is not supported in a Server Component. Measure the emitted chunks: it disables server rendering, but does not promise a particular post-hydration load time.

```tsx
// app/deferred-analytics.tsx
'use client'
import dynamic from 'next/dynamic'
const Analytics = dynamic(
  () => import('@vercel/analytics/react').then(m => m.Analytics),
  { ssr: false },
)
export function DeferredAnalytics() { return <Analytics /> }
```

Import and render `DeferredAnalytics` from the existing server root layout. Add idle/consent gating only when the product requires it; preserve essential error reporting.
