---
title: Prevent Hydration Mismatch Without Flickering
impact: MEDIUM
impactDescription: avoids visual flicker and hydration errors
tags: rendering, ssr, hydration, localStorage, flicker
---

## Prevent Hydration Mismatch Without Flickering

The server output and first client render must agree. For a cookie-backed theme, read and validate the cookie on the server, then pass the same initial theme to the client component. A localStorage read during render breaks SSR; reading it after hydration can visibly change the theme.

```tsx
// theme-wrapper.tsx
'use client'
import { useState, type ReactNode } from 'react'
type Theme = 'light' | 'dark'
export function ThemeWrapper({ initialTheme, children }: {
  initialTheme: Theme; children: ReactNode
}) {
  const [theme, setTheme] = useState(initialTheme)
  function toggleTheme() {
    const next = theme === 'light' ? 'dark' : 'light'
    document.cookie = 'theme=' + next + '; Path=/; SameSite=Lax'
    setTheme(next)
  }
  return <div className={theme}>
    <button onClick={toggleTheme}>Toggle theme</button>{children}
  </div>
}
```

In Next.js, the server layout can await cookies(), accept only light/dark, and pass light for missing or invalid values. This may make the route request-dependent; check the framework's caching model.

If a theme must come from localStorage before first paint, use an established theme integration. A pre-hydration script that changes a React-owned class creates a mismatch; it does not eliminate one. Narrow suppressHydrationWarning to that intentional cosmetic attribute, satisfy CSP, and keep React's later theme state synchronized. Suppression is an escape hatch, not reconciliation. Never derive authentication or permissions from client storage.
