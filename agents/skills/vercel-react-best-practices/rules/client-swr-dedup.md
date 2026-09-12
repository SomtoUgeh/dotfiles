---
title: Use SWR for Automatic Deduplication
impact: MEDIUM-HIGH
impactDescription: automatic deduplication
tags: client, swr, deduplication, data-fetching
---

## Use SWR for Automatic Deduplication

Preserve the application’s existing data-fetching library and use its deduplication, caching, and revalidation features. The examples below apply to projects already using SWR; TanStack Query or another established owner should retain the same responsibility. Choose a new library only when the task requires that decision.

**Incorrect (no deduplication, each instance fetches):**

```tsx
function UserList() {
  const [users, setUsers] = useState([])
  useEffect(() => {
    fetch('/api/users')
      .then(r => r.json())
      .then(setUsers)
  }, [])
}
```

**Correct (multiple instances share one request):**

```tsx
import useSWR from 'swr'

function UserList() {
  const { data: users } = useSWR('/api/users', fetcher)
}
```

**For immutable data:**

```tsx
import useSWRImmutable from 'swr/immutable'

function StaticContent() {
  const { data } = useSWRImmutable('/api/config', fetcher)
}
```

**For mutations:**

```tsx
import useSWRMutation from 'swr/mutation'

function UpdateButton() {
  const { trigger } = useSWRMutation('/api/user', updateUser)
  return <button onClick={() => trigger()}>Update</button>
}
```

Reference: [https://swr.vercel.app](https://swr.vercel.app)
