---
title: Use Ref as a Prop in React 19
impact: MEDIUM
tags: react19, ref, forwardRef, useContext, use
---

## Use Ref as a Prop in React 19

> **React 19+ only.** Keep `forwardRef` when supporting React 18 or earlier.

React 19 lets function components receive `ref` as a regular prop, so new React 19-only components do not need a `forwardRef` wrapper.

**Legacy React 18 pattern:**

```tsx
const ComposerInput = forwardRef<TextInput, Props>((props, ref) => {
  return <TextInput ref={ref} {...props} />
})
```

**React 19 pattern:**

```tsx
function ComposerInput({ ref, ...props }: Props & { ref?: React.Ref<TextInput> }) {
  return <TextInput ref={ref} {...props} />
}
```

React 19 also adds `use()`, but it does not make `useContext()` obsolete. Continue using `useContext()` for ordinary unconditional context reads:

```tsx
const value = useContext(MyContext)
```

Use `use(MyContext)` when its distinct semantics help, such as reading context conditionally. Apply the normal Rules of Hooks to `useContext()`; `use()` has its own restrictions documented by React.

References:

- [React 19 upgrade guide: ref as a prop](https://react.dev/blog/2024/04/25/react-19-upgrade-guide#ref-as-a-prop)
- [React `useContext`](https://react.dev/reference/react/useContext)
- [React `use`](https://react.dev/reference/react/use)
