---
name: product
description: Founder-mode product review — challenge premises, find gaps, ensure quality before implementation
argument-hint: "[plan folder path, PR number, or feature description]"
user-invocable: true
effort: max
---

# Product

## Review Target

<review_target> #$ARGUMENTS </review_target>

Load and execute the plan-ceo-review skill:

```
skill: plan-ceo-review
```

Pass the review target above to the skill's "Detect Review Target" step.
