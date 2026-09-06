---
title: Version and Minimize localStorage Data
impact: MEDIUM
impactDescription: prevents schema conflicts, reduces storage size
tags: client, localStorage, storage, versioning, data-minimization
---

## Version and Minimize localStorage Data

Add version prefix to keys and store only needed fields. Prevents schema conflicts and accidental storage of sensitive data.

**Incorrect:**

```typescript
// No version, stores everything, no error handling
localStorage.setItem('userConfig', JSON.stringify(fullUserObject))
const data = localStorage.getItem('userConfig')
```

**Correct:**

```typescript
const VERSION = 'v2'

function saveConfig(config: { theme: string; language: string }): boolean {
  try {
    localStorage.setItem(`userConfig:${VERSION}`, JSON.stringify(config))
    return true
  } catch {
    return false // Storage can be disabled or exceed its quota
  }
}

function loadConfig() {
  try {
    const data = localStorage.getItem(`userConfig:${VERSION}`)
    const parsed: unknown = data ? JSON.parse(data) : null
    if (!parsed || typeof parsed !== 'object') return null
    if (!('theme' in parsed) || typeof parsed.theme !== 'string') return null
    if (!('language' in parsed) || typeof parsed.language !== 'string') return null
    return { theme: parsed.theme, language: parsed.language }
  } catch {
    return null
  }
}

// Migration from v1 to v2
function migrate() {
  try {
    const v1 = localStorage.getItem('userConfig:v1')
    if (v1) {
      const old: unknown = JSON.parse(v1)
      if (!old || typeof old !== 'object' || !('darkMode' in old) ||
          typeof old.darkMode !== 'boolean' || !('lang' in old) || typeof old.lang !== 'string') return
      if (saveConfig({ theme: old.darkMode ? 'dark' : 'light', language: old.lang })) {
        localStorage.removeItem('userConfig:v1')
      }
    }
  } catch {}
}
```

**Store minimal fields from server responses:**

```typescript
// User object has 20+ fields, only store what UI needs
function cachePrefs(user: FullUser) {
  try {
    localStorage.setItem('prefs:v1', JSON.stringify({
      theme: user.preferences.theme,
      notifications: user.preferences.notifications
    }))
  } catch {}
}
```

**Always wrap in try-catch:** storage access can throw when disabled or restricted, and writes can exceed quota. Private browsing does not always disable storage. Use these helpers only in browser callbacks; retain v1 when migration cannot persist v2.

**Benefits:** Schema evolution via versioning, reduced storage size, reduces accidental storage of unnecessary fields. Versioning alone does not prevent storing sensitive values.
