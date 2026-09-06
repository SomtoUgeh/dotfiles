# nav-route-masks: Use Route Masks for Modal URLs

## Priority: LOW

## Explanation

A route mask displays a shareable page URL while the local history entry keeps
an internal modal route. Copying the address bar copies the displayed URL;
it does not reveal the internal route. Create separate page and modal routes.

## Good Example

The page route `/posts/$postId` renders `PostPage`. A separate internal route
`/posts/$postId/modal` renders `PostModal` inside the list layout. If the page
must avoid that layout, use a non-nested file route such as
`posts_.$postId.tsx`; inspect the generated route IDs for the actual project.

```tsx
import { Link } from '@tanstack/react-router'

function PostLink({ post }: { post: { id: string; title: string } }) {
  return (
    <Link
      to="/posts/$postId/modal"
      params={{ postId: post.id }}
      mask={{ to: '/posts/$postId', params: { postId: post.id } }}
      unmaskOnReload
    >
      {post.title}
    </Link>
  )
}
```

This navigates internally to `/posts/123/modal` and displays `/posts/123`.
Opening the copied URL in another tab renders `PostPage`. Without
`unmaskOnReload`, a local reload can restore the modal using history state.
The mask itself does not change which component a route renders.

## Programmatic Navigation

```tsx
const openInModal = () => navigate({
  to: '/posts/$postId/modal',
  params: { postId },
  mask: { to: '/posts/$postId', params: { postId } },
  unmaskOnReload: true,
})

const expandToFullPage = () => navigate({
  to: '/posts/$postId',
  params: { postId },
  replace: true,
})
```

The modal needs its own accessible dialog behavior, close destination, focus
restoration, and background/list layout. Those are application responsibilities.

| Action | Result |
| --- | --- |
| Click masked link | Internal modal route; page URL in address bar |
| Copy address bar / open elsewhere | Displayed page URL; page route |
| Local reload with default options | History state can retain modal route |
| Reload with `unmaskOnReload: true` | Displayed page URL becomes route |
| Browser Back | Previous history entry |

Reference: [Official route masking guide](https://tanstack.com/router/latest/docs/guide/route-masking)
