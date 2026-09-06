# auth-session-management: Implement Secure Session Handling

## Priority: HIGH

## Explanation

Sessions maintain user authentication state across requests. Use HTTP-only cookies with secure settings to reduce token theft. Cookies alone do not prevent XSS or all CSRF; retain Start's CSRF checks and authorize each server operation. Never store sensitive data in client-accessible storage.

## Bad Example

```tsx
// Storing auth in localStorage - vulnerable to XSS
function login(credentials: Credentials) {
  const token = await authenticate(credentials)
  localStorage.setItem('authToken', token)  // XSS can steal this
}

// Non-HTTP-only cookie - JavaScript accessible
export const setSession = createServerFn({ method: 'POST' })
  .handler(async ({ data }) => {
    setResponseHeader('Set-Cookie', `session=${data.token}`)  // Not secure
  })
```

## Good Example: Secure Session Cookie

```tsx
// lib/session.server.ts
import { useSession } from '@tanstack/react-start/server'

interface SessionData { userId: string; email: string; createdAt: number }

function sessionSecret(): string {
  const secret = process.env.SESSION_SECRET
  if (!secret || secret.length < 32) throw new Error('SESSION_SECRET must have at least 32 characters')
  return secret
}

// Configure session with secure defaults
export function getSession() {
  return useSession<SessionData>({
    password: sessionSecret(),
    name: '__session',
    maxAge: 60 * 60 * 24 * 7, // Enforced by the sealed session, not just the browser
    cookie: {
      httpOnly: true,          // Not accessible via JavaScript
      secure: process.env.NODE_ENV === 'production',  // HTTPS only in prod
      sameSite: 'lax',         // CSRF protection
    },
  })
}

// Usage in server function
export const login = createServerFn({ method: 'POST' })
  .validator(loginSchema)
  .handler(async ({ data }) => {
    const session = await getSession()

    // Verify credentials
    const user = await verifyCredentials(data.email, data.password)
    if (!user) {
      throw new Error('Invalid credentials')
    }

    // Store only essential data in session
    await session.update({
      userId: user.id,
      email: user.email,
      createdAt: Date.now(),
    })

    return { success: true }
  })
```

## Good Example: Full Authentication Flow

```tsx
// lib/auth.functions.ts
import { createServerFn } from '@tanstack/react-start'
import { redirect } from '@tanstack/react-router'
import { getSession } from './session.server'
import { verifyPassword } from './password.server'
import { z } from 'zod'

// Login
export const login = createServerFn({ method: 'POST' })
  .validator(z.object({
    email: z.string().email(),
    password: z.string().min(1),
  }))
  .handler(async ({ data }) => {
    const user = await db.users.findUnique({
      where: { email: data.email },
    })

    if (!user || !await verifyPassword(data.password, user.passwordHash)) {
      throw new Error('Invalid email or password')
    }

    const session = await getSession()
    await session.update({
      userId: user.id,
      email: user.email,
      createdAt: Date.now(),
    })

    throw redirect({ to: '/dashboard' })
  })

// Logout
export const logout = createServerFn({ method: 'POST' })
  .handler(async () => {
    const session = await getSession()
    await session.clear()
    throw redirect({ to: '/' })
  })

// Get current user
export const getCurrentUser = createServerFn()
  .handler(async () => {
    const session = await getSession()
    const data = await session.data

    if (!data?.userId) {
      return null
    }

    const user = await db.users.findUnique({
      where: { id: data.userId },
      select: {
        id: true,
        email: true,
        name: true,
        avatar: true,
        role: true,
        // Don't include passwordHash!
      },
    })

    return user
  })
```

## Good Example: Session with Role-Based Access

Read the current role from the database so revoked privileges do not remain valid for the cookie lifetime. `getSessionData` stays server-only; routes call the `getCurrentUser` server function from `auth.functions.ts`.

```tsx
// lib/session.server.ts
interface SessionData {
  userId: string
  email: string
  createdAt: number
}

export async function getSessionData(): Promise<SessionData | null> {
  const session = await getSession()
  const data = await session.data

  if (!data?.userId) return null

  if (typeof data.email !== 'string' || typeof data.createdAt !== 'number') return null

  // Validate session age
  const maxAge = 7 * 24 * 60 * 60 * 1000  // 7 days
  if (Date.now() - data.createdAt > maxAge) {
    await session.clear()
    return null
  }

  return { userId: data.userId, email: data.email, createdAt: data.createdAt }
}

// Middleware for admin-only routes
export const requireAdmin = createMiddleware()
  .server(async ({ next }) => {
    const session = await getSessionData()

    const user = session ? await db.users.findUnique({ where: { id: session.userId } }) : null
    if (!user || user.role !== 'admin') {
      throw redirect({ to: '/unauthorized' })
    }

    return next({ context: { user } })
  })
```

## Session Security Checklist

| Setting | Value | Purpose |
|---------|-------|---------|
| `httpOnly` | `true` | Prevents XSS from accessing cookie |
| `secure` | `true` in prod | Requires HTTPS |
| `sameSite` | `'lax'` or `'strict'` | CSRF protection |
| `maxAge` | Application-specific | Session duration |
| `password` | 32+ random chars | Encryption key |

## Context

- Always use HTTP-only cookies for session tokens
- Generate `SESSION_SECRET` with `openssl rand -base64 32`
- Store minimal data in session - fetch user details on demand
- Implement session rotation on privilege changes
- Consider session invalidation on password change
- Use `sameSite: 'strict'` for highest CSRF protection
