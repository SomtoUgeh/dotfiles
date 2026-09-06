# Design Document and Review

Use this reference only when the user or repository workflow calls for a saved design document.

## Document Shape

```markdown
---
type: design
title: [title]
date: YYYY-MM-DD
mode: startup | builder
status: draft
---

# Design: [title]

## Problem
[Observed workflow and cost]

## Target User
[Named person or narrow audience]

## Evidence and Status Quo
[Quotes, behavior, numbers, and current workaround]

## Constraints and Premises
[Confirmed, assumed, contradicted]

## Approaches Considered
[Material alternatives and tradeoffs]

## Recommended Approach
[Chosen direction and why]

## Success Criteria
[Observable outcomes]

## Diagnostic Verdict
[Verdict, evidence, uncertainty]

## Assignment
[Person, action, evidence, deadline]

## Open Questions
[Only unresolved decisions]
```

In builder mode, replace demand-specific sections with motivation, the intended “wow” moment, learning goals, and completion scope where appropriate.

## Review

Review the saved document for:

1. evidence grounded in specific observations;
2. premises that were genuinely challenged;
3. a verdict consistent with the evidence;
4. a concrete, testable assignment;
5. an approach that solves the stated problem.

A fresh-context reviewer is optional when delegation is permitted and the document is consequential enough to justify it. Cap review at three iterations. If the same issue survives twice, record it as an unresolved concern instead of looping.

Report the actual review performed and its remaining concerns. Do not invent a score or claim independent review when no reviewer ran.
