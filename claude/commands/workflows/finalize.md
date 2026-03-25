---
name: workflows:finalize
description: "Ship-readiness pass: fix, validate, and ship working copy or PR changes. Use after review findings are triaged, or standalone for a final pass before merge."
argument-hint: "[optional: working-copy, pr, or both]"
effort: max
---

# Finalize

Load and execute the finalize skill:

```
skill: finalize
```

Pass through any arguments from the user (working-copy, pr, both, or infer from context).
