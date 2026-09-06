# persist-queries: Configure Query Persistence for Offline Support

## Priority: LOW

## Explanation

TanStack Query can persist the cache to storage (localStorage, IndexedDB, AsyncStorage) and restore it on app load. This enables offline support and faster startup by eliminating initial loading states.

## Bad Example

```tsx
// No persistence - always starts fresh
const queryClient = new QueryClient()

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <MyApp />
    </QueryClientProvider>
  )
}

// User refreshes page:
// 1. Empty cache
// 2. Loading spinners everywhere
// 3. Refetch all data
// Poor offline experience
```

## Good Example: Basic Persistence with localStorage

```tsx
import { QueryClient } from '@tanstack/react-query'
import { createSyncStoragePersister } from '@tanstack/query-sync-storage-persister'
import { PersistQueryClientProvider } from '@tanstack/react-query-persist-client'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      gcTime: 1000 * 60 * 60 * 24,  // 24 hours - keep cache longer for persistence
      staleTime: 1000 * 60 * 5,     // 5 minutes
    },
  },
})

function browserStorage(): Storage | undefined {
  if (typeof window === 'undefined') return undefined
  try {
    return window.localStorage
  } catch {
    return undefined // Browser policy can deny access to the property itself
  }
}

const persister = createSyncStoragePersister({
  storage: browserStorage(),
  key: 'REACT_QUERY_CACHE',
})

function App() {
  return (
    <PersistQueryClientProvider
      client={queryClient}
      persistOptions={{
        persister,
        maxAge: 1000 * 60 * 60 * 24,  // 24 hours max
      }}
    >
      <MyApp />
    </PersistQueryClientProvider>
  )
}
```

## Good Example: Browser Persistence with TanStack Start

The basic module-level client above is for a client-rendered app. In Start, create
the `QueryClient` inside `getRouter()` and keep SSR query integration enabled.
When supplying `PersistQueryClientProvider` through the router's `Wrap`, set
`wrapQueryClient: false` on `setupRouterSsrQueryIntegration`.

For a view whose initial data exists only in browser storage, preserve a stable
server fallback with `ClientOnly`. Restoring the cache can finish before a lazy
or streamed route hydrates; rendering restored data against server loading text
causes a hydration mismatch. `useIsRestoring` controls restoration UI but is not
a hydration boundary. Keep loader-backed SSR data on the normal SSR path.

```tsx
import { ClientOnly } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { catalogQuery } from './queries'

function PersistedCatalog() {
  return (
    <ClientOnly fallback={<p>Loading catalog</p>}>
      <Catalog />
    </ClientOnly>
  )
}

function Catalog() {
  const query = useQuery(catalogQuery())
  if (query.error) return <p>Catalog unavailable</p>
  return <p>{query.data?.label ?? 'Loading catalog'}</p>
}
```

Test a full reload with an existing storage snapshot, not only client navigation.
Also test expired/busted snapshots, malformed or unavailable storage, and account
changes. When storage is unavailable, let Query continue with its in-memory cache.

References: [ClientOnly](https://tanstack.com/router/latest/docs/framework/react/api/router/clientOnlyComponent),
[localStorage exceptions](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage#exceptions).

## Good Example: Async Persistence with IndexedDB

```tsx
import { createAsyncStoragePersister } from '@tanstack/query-async-storage-persister'
import { get, set, del } from 'idb-keyval'

const persister = createAsyncStoragePersister({
  storage: {
    getItem: async (key) => await get(key),
    setItem: async (key, value) => await set(key, value),
    removeItem: async (key) => await del(key),
  },
  key: 'REACT_QUERY_CACHE',
})

function App() {
  return (
    <PersistQueryClientProvider
      client={queryClient}
      persistOptions={{
        persister,
        maxAge: 1000 * 60 * 60 * 24 * 7,  // 7 days
        buster: APP_VERSION,  // Bust cache on app updates
      }}
    >
      <MyApp />
    </PersistQueryClientProvider>
  )
}
```

## Good Example: Selective Persistence

```tsx
import { persistQueryClient } from '@tanstack/react-query-persist-client'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      gcTime: 1000 * 60 * 60 * 24,
    },
  },
})

// Explicitly opt public queries in with meta: { persist: true }.
// A denylist of known private keys misses newly added sensitive queries.
persistQueryClient({
  queryClient,
  persister,
  dehydrateOptions: {
    shouldDehydrateQuery: (query) => {
      return query.meta?.persist === true && query.state.status === 'success'
    },
  },
})
```

## Good Example: React Native with AsyncStorage

```tsx
import AsyncStorage from '@react-native-async-storage/async-storage'
import { createAsyncStoragePersister } from '@tanstack/query-async-storage-persister'

const persister = createAsyncStoragePersister({
  storage: AsyncStorage,
  key: 'app-query-cache',
})

// Usage is the same as web
```

## Good Example: Handling Restoration Loading

```tsx
import { useIsRestoring } from '@tanstack/react-query'
import { PersistQueryClientProvider } from '@tanstack/react-query-persist-client'

function PersistedApp() {
  const isRestoring = useIsRestoring()

  return isRestoring ? <SplashScreen /> : <MainApp />
}

function App() {
  return (
    <PersistQueryClientProvider
      client={queryClient}
      persistOptions={{ persister }}
      onSuccess={() => {
        // Cache restored successfully
        console.log('Cache restored')
      }}
    >
      <PersistedApp />
    </PersistQueryClientProvider>
  )
}
```

## Persistence Configuration

| Option | Purpose |
|--------|---------|
| `maxAge` | Maximum cache age before considered invalid |
| `buster` | String to invalidate cache (use app version) |
| `dehydrateOptions.shouldDehydrateQuery` | Filter which queries to persist |
| `hydrateOptions.defaultOptions` | Defaults for hydrated queries and mutations |

## Context

- Requires `@tanstack/react-query-persist-client` package
- Set `gcTime` at least as large as persistence `maxAge`; otherwise inactive restored data can be collected earlier than intended
- Create the client per SSR request; keep the browser client stable. Clear both persisted and in-memory private data on logout/account changes.
- Use `buster` option to invalidate cache on app updates
- Don't persist sensitive data or real-time data
- IndexedDB is better than localStorage for large caches
- Restored data is still subject to staleTime checks
- Works well with `networkMode: 'offlineFirst'`
