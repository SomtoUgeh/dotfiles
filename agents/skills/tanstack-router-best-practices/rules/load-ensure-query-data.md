# load-ensure-query-data: Use ensureQueryData with TanStack Query

## Priority: HIGH

## Explanation

When integrating TanStack Router with TanStack Query, use `queryClient.ensureQueryData()` in loaders instead of `prefetchQuery()`. This respects the cache, awaits data if missing, and returns the data for potential use.

## Bad Example

```tsx
// Unawaited prefetchQuery does not block navigation or propagate fetch errors
export const Route = createFileRoute('/posts/$postId')({
  loader: async ({ params, context: { queryClient } }) => {
    // prefetchQuery never throws, swallows errors
    queryClient.prefetchQuery({
      queryKey: ['posts', params.postId],
      queryFn: () => fetchPost(params.postId),
    })
    // No await - might not complete before render
    // No return value to use
  },
})

// Fetching directly - bypasses TanStack Query cache
export const Route = createFileRoute('/posts')({
  loader: async () => {
    const posts = await fetchPosts()  // Not cached
    return { posts }
  },
})
```

## Good Example

```tsx
// Define queryOptions for reuse
const postQueryOptions = (postId: string) =>
  queryOptions({
    queryKey: ['posts', postId],
    queryFn: () => fetchPost(postId),
    staleTime: 5 * 60 * 1000,  // 5 minutes
  })

export const Route = createFileRoute('/posts/$postId')({
  loader: async ({ params, context: { queryClient } }) => {
    // ensureQueryData:
    // - Returns existing cached data, even when stale
    // - Fetches and caches only when data is missing
    // - Awaits completion
    // - Throws on error (caught by error boundary)
    await queryClient.ensureQueryData(postQueryOptions(params.postId))
  },
  component: PostPage,
})

function PostPage() {
  const { postId } = Route.useParams()

  // Data guaranteed to exist from loader
  const { data: post } = useSuspenseQuery(postQueryOptions(postId))

  return <PostContent post={post} />
}
```

## Good Example: Multiple Parallel Queries

```tsx
export const Route = createFileRoute('/dashboard')({
  loader: async ({ context: { queryClient } }) => {
    // Parallel data fetching
    await Promise.all([
      queryClient.ensureQueryData(statsQueries.overview()),
      queryClient.ensureQueryData(activityQueries.recent()),
      queryClient.ensureQueryData(notificationQueries.unread()),
    ])
  },
})
```

## Good Example: Dependent Queries

```tsx
export const Route = createFileRoute('/users/$userId/posts')({
  loader: async ({ params, context: { queryClient } }) => {
    // First query needed for second
    const user = await queryClient.ensureQueryData(
      userQueries.detail(params.userId)
    )

    // Dependent query uses result
    await queryClient.ensureQueryData(
      postQueries.byAuthor(user.id)
    )
  },
})
```

## Router Configuration for TanStack Query

```tsx
// router.tsx — create one client/router per SSR request
import { setupRouterSsrQueryIntegration } from '@tanstack/react-router-ssr-query'

export function getRouter() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { staleTime: 60 * 1000 } },
  })
  const router = createRouter({
    routeTree,
    context: { queryClient },
    defaultPreloadStaleTime: 0,
  })
  setupRouterSsrQueryIntegration({ router, queryClient })
  return router
}
```

## ensureQueryData vs prefetchQuery vs fetchQuery

| Method | Returns | Throws | Awaits | Use Case |
|--------|---------|--------|--------|----------|
| `ensureQueryData` | Data | Yes | Yes | Route loaders (recommended) |
| `prefetchQuery` | void | No | Yes | Background prefetching |
| `fetchQuery` | Data | Yes | Yes | When you need data immediately |

## Context

- `ensureQueryData` is the recommended method for route loaders
- Returns stale cached data by default. Set `revalidateIfStale: true` for background refresh, or use `fetchQuery` to await freshness.
- Errors propagate to route error boundaries
- Use `queryOptions()` factory for type-safe, reusable query definitions
- Set `defaultPreloadStaleTime: 0` to let TanStack Query manage cache
- Pair with `useSuspenseQuery` in components for guaranteed data
