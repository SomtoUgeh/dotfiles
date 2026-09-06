---
title: Cache Storage API Calls
impact: LOW-MEDIUM
impactDescription: reduces expensive I/O
tags: javascript, localStorage, storage, caching, performance
---

## Cache Storage API Calls

Storage is synchronous. Cache only after measuring repeated reads, and centralize all same-tab writes/removals. This browser-only helper handles blocked storage and cross-tab clear events. Register listeners once in the owning module lifecycle; remove them when that lifecycle ends.

```typescript
const storageCache = new Map<string, string | null>()
function getLocalStorage(key: string): string | null {
  const cached = storageCache.get(key)
  if (cached !== undefined) return cached
  try {
    const value = localStorage.getItem(key)
    storageCache.set(key, value)
    return value
  } catch { return null }
}
function setLocalStorage(key: string, value: string | null): boolean {
  try {
    if (value === null) localStorage.removeItem(key)
    else localStorage.setItem(key, value)
    storageCache.set(key, value)
    return true
  } catch { storageCache.delete(key); return false }
}
function onStorage(event: StorageEvent) {
  if (event.key === null) storageCache.clear()
  else storageCache.delete(event.key)
}
function onVisibility() {
  if (document.visibilityState === 'visible') storageCache.clear()
}
window.addEventListener('storage', onStorage)
document.addEventListener('visibilitychange', onVisibility)
// On module/owner teardown:
// window.removeEventListener('storage', onStorage)
// document.removeEventListener('visibilitychange', onVisibility)
```

Cookies can change through HTTP responses without a storage event. Avoid persistent cookie caching unless every change can invalidate it. Parse at the first equals sign so values containing equals signs survive; never treat client-readable cookies as proof of authentication.
