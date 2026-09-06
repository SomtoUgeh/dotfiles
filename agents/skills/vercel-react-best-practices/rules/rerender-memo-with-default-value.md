---

title: Extract Default Non-primitive Parameter Value from Memoized Component to Constant
impact: MEDIUM
impactDescription: restores memoization by using a constant for default value
tags: rerender, memo, optimization

---

## Extract Default Non-primitive Parameter Value from Memoized Component to Constant

A default parameter is evaluated only when the component runs. Omitting it does not break that component's outer `memo` comparison: React compares incoming props before calling the component. If another prop or state makes it render, a newly created default object/function can invalidate a memoized child or an effect that consumes it.

Hoist the default when it is passed to a memoized child or used as an effect dependency. Do not describe this as repairing the outer component's memoization.

**Incorrect (`onClick` has different values on every rerender):**

```tsx
const UserAvatar = memo(function UserAvatar({ onClick = () => {} }: { onClick?: () => void }) {
  // ...
})

// Used without optional onClick
<UserAvatar />
```

**Correct (stable default value):**

```tsx
const NOOP = () => {};

const UserAvatar = memo(function UserAvatar({ onClick = NOOP }: { onClick?: () => void }) {
  // ...
})

// Used without optional onClick
<UserAvatar />
```
