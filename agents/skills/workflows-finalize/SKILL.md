---
name: workflows-finalize
description: Review, fix, simplify, and validate an implemented change for ship readiness. Use when the user asks to finalize, harden, or make code shippable; do not publish, push, open a PR, merge, or deploy unless separately authorized.
---

# Finalize

Take the last serious pass over the requested working-copy or PR scope. Fix verified in-scope issues, validate real behavior, and leave a concrete reviewable result.

Use [RUNTIME_TOOLS.md](../RUNTIME_TOOLS.md) for available tools and workers. Shared authority, model, Git, and review policy in `agents/shared/AGENTS.md` is authoritative.

## Authorization boundary

Finalizing authorizes local review, in-scope edits, and appropriate validation. It does not by itself authorize:

- pushing commits
- opening or updating a PR
- merging, publishing, releasing, or deploying
- sending external messages or review comments

Prepare the local result first. Perform a publication step only when the user has already requested that exact step; otherwise report what is ready.

Do not create a baseline commit containing user work merely to establish rollback. Preserve unrelated changes and use explicit paths for staging if committing is part of the authorized workflow.

## 1. Determine the effective scope

Identify whether the target is the working copy, a branch/PR diff, or a named set of files. Inspect repository status and separate task changes from unrelated dirty-tree state. Read changed files in full plus enough callers, tests, schemas, and configuration to understand credible impact.

If the user asked to finalize a PR, inspect it read-only unless they also asked for PR mutations. Never post review comments unless explicitly requested.

## 2. Build the risk picture

Classify the change by actual risk and verify relevant surfaces:

- user-visible behavior and error paths
- callers and shared interfaces
- data, schema, migration, or authorization boundaries
- integration and rollout assumptions
- existing tests and project commands
- operational visibility when the feature genuinely needs it

Read [references/investigation-patterns.md](references/investigation-patterns.md) only for the domains present in the change.

Anything credibly affected but not inspected remains unverified.

## 3. Simplify and fix

Use `deslop` when it is available and applicable. Otherwise perform a focused local simplicity pass; do not invent a `/simplify` skill or agent.

Fix issues with a clear, verified answer:

- correctness and regression bugs
- unsafe or misleading error handling
- type-safety holes
- stale documentation caused by this change
- safe local simplifications
- in-scope review findings confirmed in the current code

Do not adopt an outside reviewer's scope or architecture change automatically. Present the evidence and ask when it conflicts with the user's direction or requires a product decision.

Avoid speculative rewrites, broad formatting churn, and unrelated cleanup. Keep edits reviewable in the current dirty tree.

## 4. Use bounded independent checks

Delegate only narrow questions that materially improve confidence, using callable runtime roles. Respect concurrency limits and keep one lead reviewer. The main agent owns final severity and verifies findings before fixing them.

A small or low-risk change may need no subagent. A medium/high-risk change may benefit from one to three independent checks for security, architecture, performance, or conventions.

## 5. Validate proportionally

Run the repository's focused checks for the changed behavior:

- targeted tests for affected behavior and error paths
- typecheck or lint when the language and scope warrant it
- build for structural or bundling changes
- safe real-flow verification for user-visible behavior

Expand validation only when risk, failures, or unresolved evidence justify it. Do not poke production or trigger live side effects without authorization.

For medium/high-risk work, re-read the final diff and affected boundary after fixes.

## Completion

Report concisely:

- scope and risk
- verified fixes and simplifications
- checks run and outcomes
- inspected and unverified surfaces
- remaining user decisions or blockers
- ship confidence and reason
- any authorized commit/branch details

Do not open a PR, push, or ship as an automatic final step. If the user requested one of those actions, complete all local preparation first and follow the shared authorization policy.
