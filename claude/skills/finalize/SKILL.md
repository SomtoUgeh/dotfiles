---
name: finalize
description: "Ship-readiness pass: review, fix, and validate working copy or PR changes. This skill should be used when asked to finalize, harden, do a final pass, or make code shippable. Runs as a forked subagent."
context: fork
---

# Finalize

Take ownership of the last serious pass before merge: understand what changed, identify what could still go wrong, simplify what can be safely simplified, fix everything with a clear right answer, validate the result, and surface only decisions that genuinely require product or architectural input.

After this runs, the user should be able to click merge. If something still needs their input, they should have zero confusion about what, why, and the recommendation.

## Operating Stance

Think like the person who would approve this to ship tonight.

- Care most about correctness, regressions, user-visible behavior, failure modes, and maintainability
- Read enough surrounding code to understand the change in context, not just the patch
- Map the likely blast radius before declaring confidence: callers, dependents, shared utilities, adjacent integrations, affected user flows, tests, docs
- Prefer focused investigation over exhaustive ceremony
- Always look for simplification, but only apply when clearly safe and local
- Delegate narrow, concrete questions to subagents; keep the critical path in the main thread
- Optimize for shipping confidence, not maximum diff size

## Safety Rails

### Approval boundary

Without explicit user approval, do not: deploy, merge, publish, release to production, send external communications, or trigger any action affecting live systems.

Aggressive preparation is fine: fix code, run validations, create branches, commit task-related changes, open/update PRs through normal workflow.

If the next step would move from "ready to ship" to "actually shipped," stop and ask.

### Preserve reversibility

Before making non-trivial edits, create a clear rollback boundary:

- On a non-default branch with coherent working copy: commit the current task state, then place finalize edits in new commits on top
- On the default/base branch with coherent working copy: create a branch first, baseline commit, then finalize edits
- Work already committed: keep finalize edits in their own commit

If the tree is mixed with unrelated edits or the task boundary is unclear, do not force a commit. Instead: keep edits narrowly scoped and easy to inspect, or stop and ask before making changes that would be hard to disentangle.

## Execution Order

### 1. Determine scope

Determine whether the user wants the working copy, the current PR, or both.

If both exist and the user did not specify, prefer working copy first and mention PR-only concerns separately. Only ask when the distinction materially changes the work.

If the working copy is dirty, distinguish finalize targets from unrelated in-progress edits. Do not rewrite, reformat, or "clean up" files just because they are dirty.

If nothing to finalize, say so plainly.

### 2. Build the picture

- Inspect repo status and the effective diff
- Read changed files in full
- Read project instructions (AGENTS.md, CLAUDE.md, referenced docs)
- Identify work type: backend, frontend, infra, schema, integration, refactor, new feature, or mix
- Look beyond changed files: callers, related tests, docs, routes, schemas, affected flows
- Size the work: low, medium, or high risk
- Map the blast radius before editing

Read [investigation-patterns.md](references/investigation-patterns.md) for domain-specific investigation checklists based on the type of change identified.

Do not stay trapped inside the diff. A finalize pass is about whether the change holds up in the codebase.

Any area with credible impact that was not inspected is unverified, not implicitly safe.

### 3. Deslop and simplify

Run `/deslop` then `/simplify` on the changed files. These are mechanical cleanup passes that should happen before investigation:

- **Deslop** removes AI slop: unnecessary comments, defensive over-engineering, type hacks, style inconsistencies, over-abstraction
- **Simplify** reviews for reuse, quality, and efficiency — then fixes

Skip if reviewing a plan folder (no code to clean). If either pass makes changes, note them briefly before proceeding. If neither finds anything, proceed silently.

### 4. Create rollback boundary (if needed)

If likely changes are non-trivial and the task state is coherent, create the appropriate branch and/or baseline commit before editing (see Safety Rails above).

### 5. Investigate and delegate

Spawn parallel subagents for independent side investigations. Good delegated work:

- Convention and command discovery
- Dependency and impact tracing
- Focused backend or frontend audits
- Unresolved PR feedback evaluation
- Targeted verification of suspicious areas

Each subagent should return concrete findings with file references and recommended action.

After subagents return, integrate findings before editing. The main thread owns the final judgment about blast radius, fixes, and ship confidence.

### 6. Fix

Default is to fix, not propose. Read [investigation-patterns.md](references/investigation-patterns.md) for the fix rubric, review-feedback handling, and simplification guidelines.

Fix directly when the correct action is clear and low-risk: real bugs, safe simplifications, broken imports, missing edge-case handling, type-safety holes, dead code, stale docs, unresolved review feedback with a clear path.

Do not widen scope. Avoid speculative rewrites, style churn, and opportunistic architecture changes. "Could be cleaner" is not enough. "Would likely bite us soon" is enough.

Raise the bar further when a simplification would remove multiple components, delete helper layers, or collapse public interfaces. Those are not "safe and local." Investigate more, checkpoint first, keep in a reversible commit.

### 7. Validate

Run the appropriate checks for the scope:

- Typecheck for localized code changes
- Lint when changes span files or patterns
- Targeted tests for the affected area
- Build for broader structural changes
- Real-flow verification in the best safe environment available when behavior changed

If a check fails, treat it as part of finalize: understand, fix what belongs to this change, rerun.

Prefer exercising real behavior over reading code or relying only on static checks. Do not poke production systems or trigger irreversible external side effects.

When relevant, also check ship-readiness beyond code: rollout assumptions, migration safety, rollback path, observability, feature flags, config drift. Use judgment — do not force this onto trivial changes.

### 8. Final targeted pass (medium/high risk only)

After fixes and validation, do one more targeted pass over the original blast radius to catch anything introduced by the fixes themselves.

### 9. PR flow (when appropriate)

If finalizing working copy on the default/base branch, the work ends in high confidence, has no unresolved blockers, and the diff is a coherent task: proactively create a branch, commit, and open a PR through the project's normal workflow.

Only when clearly safe. If the tree contains unrelated work, task boundary is unclear, or publishing would be premature, stop at the finalize handoff.

## Completion

Done when one of:

- Work is validated and comfortable to ship
- Work is validated, comfortable to ship, and carried through branch-and-PR flow when safe
- Short, explicit list of blockers/decisions that prevent high confidence

If confidence is not high, say exactly why.

## Final Response

Keep concise and decision-oriented:

- Scope reviewed
- Risk level and why
- Surfaces checked vs. unverified
- What was fixed or simplified, and why
- Delegated investigations and what they established
- Decisions still needed (if any)
- Validation ran and results
- Rollback boundary created (how)
- Branch/PR created (link if so)
- Follow-up improvements (only if clearly valuable and non-blocking)
- **Ship confidence: high / medium / low** — one short reason

Keep blockers separate from follow-up ideas. The user should scan the response and know both whether this is ready to merge and what would be worth doing next.
