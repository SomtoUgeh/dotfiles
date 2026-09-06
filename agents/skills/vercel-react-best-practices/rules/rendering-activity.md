---
title: Use Activity Component for Show/Hide
impact: MEDIUM
impactDescription: preserves state/DOM
tags: rendering, activity, visibility, state-preservation
---

## Use Activity Component for Show/Hide

React 19.2+ provides `<Activity>` to preserve state/DOM for components that frequently toggle visibility. Confirm the installed React version first.

**Usage:**

```tsx
import { Activity } from 'react'

function Dropdown({ isOpen }: Props) {
  return (
    <Activity mode={isOpen ? 'visible' : 'hidden'}>
      <ExpensiveMenu />
    </Activity>
  )
}
```

Hidden Activity boundaries preserve state, hide their DOM, and clean up effects; they can still render at lower priority. Effects restart when the boundary becomes visible. It does not freeze all work.
