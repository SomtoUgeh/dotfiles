---
title: Use useTransition Over Manual Loading States
impact: LOW
impactDescription: reduces re-renders and improves code clarity
tags: rendering, transitions, useTransition, loading, state
---

## Use useTransition Over Manual Loading States

React 19 supports async Actions with `useTransition` and a pending flag. It does not cancel requests or enforce response order. Keep an existing data library's loading state when it already owns the request.

**Incorrect (manual loading state):**

```tsx
function SearchResults() {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Awaited<ReturnType<typeof fetchResults>>>([])
  const [isLoading, setIsLoading] = useState(false)

  const handleSearch = async (value: string) => {
    setIsLoading(true)
    setQuery(value)
    const data = await fetchResults(value)
    setResults(data)
    setIsLoading(false)
  }

  return (
    <>
      <input value={query} onChange={(e) => handleSearch(e.target.value)} />
      {isLoading && <Spinner />}
      <ResultsList results={results} />
    </>
  )
}
```

**Correct (useTransition with built-in pending state):**

```tsx
import { useTransition, useState, useRef } from 'react'

function SearchResults() {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Awaited<ReturnType<typeof fetchResults>>>([])
  const [isPending, startTransition] = useTransition()
  const latestRequest = useRef(0)

  const handleSearch = (value: string) => {
    setQuery(value) // Update input immediately
    const requestId = ++latestRequest.current
    
    startTransition(async () => {
      // Fetch and update results
      const data = await fetchResults(value)
      if (requestId === latestRequest.current) {
        startTransition(() => setResults(data))
      }
    })
  }

  return (
    <>
      <input value={query} onChange={(e) => handleSearch(e.target.value)} />
      {isPending && <Spinner />}
      <ResultsList results={results} />
    </>
  )
}
```

**Benefits:**

- **Automatic pending state**: No need to manually manage `setIsLoading(true/false)`
- **Errors**: Uncaught Action errors go to an error boundary; provide one or handle the error inside the Action.
- **Better responsiveness**: Keeps the UI responsive during updates
- **Response ordering**: Explicitly ignore obsolete results, or use a data library that owns cancellation and ordering. New transitions do not cancel network requests.

Reference: [useTransition](https://react.dev/reference/react/useTransition)
