# err-server-errors: Handle Server Function Errors

## Priority: MEDIUM

Server errors cross a serialization boundary. Do not depend on a custom
`Error` subclass, `instanceof`, or arbitrary custom properties surviving RPC
unless the application explicitly registers and tests serialization adapters.
Use plain discriminated results for expected failures, and sanitized exceptions
for unexpected failures. Keep full diagnostics in server logs.

## Not Found and Redirects

```tsx
import { createServerFn } from '@tanstack/react-start'
import { notFound, redirect } from '@tanstack/react-router'
import { z } from 'zod'

export const getPost = createServerFn()
  .validator(z.object({ id: z.string() }))
  .handler(async ({ data }) => {
    const user = await requireCurrentUser()
    const post = await findPostVisibleToUser(data.id, user.id)
    if (!post) throw notFound()
    return post
  })
```

`requireCurrentUser` and `findPostVisibleToUser` are the application's
server-only authentication and access-controlled data functions. Import them
inside this server-function module; do not replace them with a client route guard.

## Expected Failure Results

```tsx
import { createServerFn } from '@tanstack/react-start'
import { setResponseStatus } from '@tanstack/react-start/server'

export const createPost = createServerFn({ method: 'POST' })
  .validator(createPostSchema)
  .handler(async ({ data }) => {
    const user = await requireCurrentUser()
    try {
      const post = await insertPostForUser(data, user.id)
      return { ok: true as const, post }
    } catch (error) {
      if (isDuplicateTitle(error)) {
        return {
          ok: false as const,
          code: 'DUPLICATE' as const,
          message: 'A post with this title already exists',
        }
      }
      console.error('Failed to create post', error)
      setResponseStatus(500)
      throw new Error('Failed to create post')
    }
  })
```

Here `createPostSchema`, `insertPostForUser`, and `isDuplicateTitle` come from
the project's schema/data layer. If using Prisma, recognize its typed `P2002`
error in that layer. Validate that the constraint is the one you intend to map.

```tsx
const mutation = useMutation({
  mutationFn: (data: CreatePostInput) => createPost({ data }),
  onSuccess: (result) => {
    if (!result.ok) {
      setError(result.message)
      return
    }
    navigate({ to: '/posts/$postId', params: { postId: result.post.id } })
  },
  onError: () => setError('Unable to save the post. Please try again.'),
})
```

RPC envelopes represent expected application results. For an external REST
endpoint, return `Response.json(payload, { status: 409 })` for a conflict.
Do not assume that setting an HTTP status on an RPC changes its result type.

## Verify in the Application

- Test schema failures, unauthenticated calls, forbidden resources, missing
  records, duplicate constraints, and unexpected server exceptions through HTTP.
- Keep `redirect()` and `notFound()` out of broad catch blocks, or rethrow
  them using Router's `isRedirect` / `isNotFound` checks.
- Assert the actual client result and response status on the installed release.
- Use Query error reset plus router invalidation when retrying failed loaders.

Reference: [TanStack Start server functions](https://tanstack.com/start/latest/docs/framework/react/guide/server-functions)
