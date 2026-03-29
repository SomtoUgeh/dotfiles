# Investigation Patterns

Domain-specific checklists, fix rubrics, and review-feedback handling for the finalize skill. Read this after determining the type of change in Step 2.

## Domain Checklists

Match investigation depth to risk tier. Low-risk: tight local sweep. Medium-risk: broader dependency and behavior checks. High-risk: deliberate pass across affected flows, integration boundaries, and release-readiness.

### Backend / Integration

- Input validation, auth, error handling
- Transaction boundaries, retries/timeouts
- Status codes, leaked internals, unsafe queries
- Partial failure behavior
- N+1 queries, missing indexes
- Caching opportunities for expensive operations

### Frontend

- Loading/error/empty states
- Accessibility
- Responsive behavior
- Unnecessary effects, stale closures, state ownership
- Design-system drift, broken interactions
- Bundle size impact from new dependencies

### Refactors

- Missed call sites, stale names
- Accidental API surface changes
- Tests still asserting old behavior
- Callers using the old interface that were not updated

### New Features / Greenfield

- Missing setup docs, missing env documentation
- Dev-only assumptions baked in
- Dependency quality
- Missing guardrails (rate limits, input bounds, etc.)

### PR-Specific

- Unresolved review comments (evaluate with judgment — see Review Feedback below)
- Stale approvals after force-push
- CI status
- Merge conflicts

## Fix Rubric

Fix directly when the correct action is clear and low-risk:

| Category | Examples |
|----------|----------|
| Real bugs | Logic errors, off-by-ones, null dereferences |
| Safe simplifications | Dead branches, obsolete flags, unnecessary indirection |
| Broken references | Stale imports/exports, missing files |
| Missing edge cases | Obvious unhandled inputs, missing validation |
| Type safety | Holes with a clear local fix |
| Cleanup | Dead code, commented-out code, debug leftovers |
| Stale docs | Misleading comments, outdated README sections |
| Review feedback | Unresolved comments with a clear implementation path (see below) |
| Test gaps | Tests that should be updated alongside the change |

Do NOT fix: speculative rewrites, style churn, opportunistic architecture changes, "could be cleaner" improvements.

## Review Feedback Handling

Not all review comments deserve implementation. Evaluate each unresolved comment:

**Fix it:**
- Points to a real bug, risk, or correctness issue
- Suggests a meaningful simplification or catches a genuine oversight

**Reply and resolve:**
- Trivial, nitpicky, or stylistic in a way that does not matter for shipping — explain why not worth addressing here
- Wrong, outdated, or based on a misunderstanding — reply with the correction
- Suggests an out-of-scope refactor or improvement — acknowledge as valid future work if it is
- Vague, generic, or reads like AI reviewer padding — note that it is not actionable

When dismissing a comment, be direct and specific. "Style preference, does not affect correctness or readability" is fine. "Not addressing" with no reason is not.

The bar: if implementing feedback makes the change safer, simpler, or more correct, do it. If it just makes the diff bigger or satisfies taste, skip it and say why.

## Simplification Guidelines

Good simplification is behavior-preserving and reduces mental load:

- Removing dead branches, obsolete flags, unnecessary indirection
- Collapsing duplicated or overly defensive logic when the simplified version is clearly correct
- Tightening APIs, names, or state flow in the changed area
- Deleting workarounds that no longer serve a purpose

Raise the bar when simplification would remove multiple components, delete helper layers, or collapse public interfaces. Those are not "safe and local." Investigate more, checkpoint first, keep in a reversible commit.

Do not chase elegance for its own sake. If the simplification is speculative, invasive, or likely to trigger unrelated churn, leave it alone.

## Escalation Criteria

Flag and ask only when a fix depends on:

- Product intent or user-facing behavior decisions
- API contract choices
- Migration strategy
- Rollout policy
- Anything that cannot be safely inferred from the code and context

When escalating: be specific about the risk, explain why it was not auto-fixed, propose the most likely good direction.
