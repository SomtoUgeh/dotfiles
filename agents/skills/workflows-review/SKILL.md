---
name: workflows-review
description: "Perform explicitly requested exhaustive review of large or high-risk changes with bounded specialist checks and one evidence-backed report. Ordinary ship gates use code-review."
---

# Exhaustive code review

Use [RUNTIME_TOOLS.md](../RUNTIME_TOOLS.md) and the shared role and authorization
policy. Apply [closeout.md](../code-review/closeout.md) for severity, scope, and
review-loop limits. This skill adds coverage, not permission to edit, push, post
comments, or create tracking files.

## Establish the target

Resolve the requested working-tree change, commit, branch, PR, or plan. Read
repository instructions and status first. A dirty tree is valid review input;
preserve it. Review another ref through diffs or an isolated worktree when
needed, without switching the user's active branch.

For a PR, use `gh` when available to read explicit metadata fields, diff, checks,
and existing feedback. Do not require GitHub authentication for local review.
For a plan, read its declared documents and map criteria to implementation.
Record the target revision or working-tree state so findings have a clear scope.

## Choose the review coverage

Start with the active runtime's callable agent and skill catalog. Discover
additional configured roles only when needed; a file on disk does not prove the
role is callable. Do not scan every installed plugin or launch the entire bench.

Select independent checks based on the actual changes:

| Change surface | Review responsibility |
|---|---|
| Auth, secrets, permissions, untrusted data | Security and abuse paths |
| Boundaries, APIs, data ownership | Architecture and integration |
| Hot paths, queries, resource usage | Measured performance and scalability |
| Types, error handling, concurrency | Correctness and failure behavior |
| UI, interaction, animation | User flow, accessibility, requested design |
| Tests and migrations | Coverage, repeatability, rollout and recovery |
| Complex code or repeated patterns | Simplicity and consistency |

Run a small batch of relevant specialists, normally two to four, bounded by
runtime slots and independent scope. Use the configured model; do not put model
versions in this workflow. One lead reviewer owns synthesis. Specialists return
findings only, do not edit, and do not spawn nested reviewers. Give each the exact
scope, relevant context, and an instruction to cite the current code.

If delegation is unavailable, perform the selected checks locally and disclose
that no independent agent review occurred. Never claim a failed worker returned
a clean review. An optional outside-model opinion must use a verified distinct
model and existing user authorization.

## Gather evidence

Read enough surrounding code to trace behavior beyond the changed lines. Follow
relevant callers, data models, tests, and configuration. Use authoritative docs
for unfamiliar/current API behavior and history when intent is unclear.

Load only skills relevant to the target. Choose one copy when local and plugin
skills overlap; preserve the user's visual style and project conventions.
If the plan contains a breadboard, use `breadboard-reflection` to compare its
places, affordances, and wiring with the actual implementation.

For each applicable scenario, trace inputs, state, and observable output:

- Expected use, empty and malformed inputs, boundary values.
- Partial failures, cancellation, retries, timeouts, and recovery.
- Concurrent requests, repeated actions, stale data, and resource limits.
- Authorization boundaries and sensitive-data handling.
- Deployment, migration, backwards interactions still required by the task.
- User-visible loading, error, accessibility, and reduced-motion behavior.

Use focused reproduction or tests where they materially establish the defect.
Do not report speculative scale concerns without an affected path and reason.

## Synthesize

Collect every launched check's result, or explicitly record its failure. Confirm
each candidate finding against the current code, deduplicate, and distinguish
pre-existing issues from regressions in the requested scope.

| Priority | Meaning |
|---|---|
| P0 | Immediate critical failure requiring action |
| P1 | Concrete defect that blocks shipping the requested change |
| P2 | Important issue to address; explain impact and constraints |
| P3 | Optional improvement |

Every finding needs a short title, current file and tight line range, triggering
conditions, concrete consequence, and an actionable correction. Omit unsupported
claims and style preferences that the user did not request. Disagreement between
reviewers is resolved with evidence, not a vote or automatic direction change.

## Return the review

Lead with actionable findings ordered by severity, then the validation performed
and material coverage limits. If no findings survived verification, say so and
state what was checked; do not imply exhaustive proof of correctness.

Default output is the conversation. Update `prd.json` or create `file-todos`
only when that tracking output was requested. Record findings without silently
changing story completion or accepting new scope. Never post on a PR unless
explicitly asked to comment on that PR.

If fixes were requested as part of the same task, the implementer applies
verified in-scope fixes and reruns affected checks under the closeout contract.
A review-only request stops after delivering the report.
