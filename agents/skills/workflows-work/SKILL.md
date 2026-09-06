---
name: workflows-work
description: Execute an implementation plan or PRD through complete, verified stories, preserving dependencies and progress across sessions.
---

# Execute a work plan

Use [RUNTIME_TOOLS.md](../RUNTIME_TOOLS.md) for available progress, skill,
question, and worker tools. Follow shared instructions for authorization,
models, Git, and review. Use the active harness's selected model.

## Load and validate

Resolve the plan from the invocation or current conversation. For a directory,
read `spec.md`, `prd.json`, and any documents the spec declares normative. For a
single file, read relevant sibling documents. If there is no PRD, execute the
plan with an in-context checklist; generating another artifact is optional.
Ask only if the plan or an essential decision cannot be identified.

Support the existing schema without forcing a migration:

| Source | Working interpretation | Completion write |
|---|---|---|
| `status` | pending / in_progress / blocked / completed | status and existing completion fields |
| `passes` | true means completed; false means pending | passes = true after verification |

- Default missing `depends_on` to an empty list.
- Use `acceptance_criteria`, or existing `steps` when criteria are absent.
- Validate unique IDs, valid dependency IDs, no cycles, and usable criteria.
- Preserve unknown fields and the source schema. Do not write derived working
  fields into the PRD. Append a log only if the PRD already has a log array.
- Recheck completed work only when evidence suggests drift or a relevant
  change invalidated its previous verification.

Show the ready stories, remaining work, and concrete blockers. Mirror progress
into the runtime's available tool using only supported fields. Keep dependency
and story-to-task mappings in context when the tool cannot represent them.
The PRD remains the source of truth; the progress UI is a view.

## Prepare the workspace

Read repository instructions, current branch, status, and relevant patterns.
Preserve unrelated work. Use the branch/worktree already selected for this task.
If the plan names another branch, resolve the mismatch from user intent and
existing state; ask only if changing it would conflict with current work.
Do not pull, switch branches, or create a worktree just to read a plan.

An instruction to execute the plan authorizes its routine reversible work.
Do not add a second generic approval gate. External actions still require the
authorization specified by the user and active runtime.

## Execute each story

1. Select the highest-priority pending story whose dependencies are complete.
   Do not start a dependent story while a prerequisite remains unverified.
2. Mark it in progress in the full schema and progress UI. In the lightweight
   schema leave `passes` false until complete. Explain the next concrete result.
3. Load the relevant named skills before implementation, using the discovered
   paths. If a skill is unavailable, search its current name and use an existing
   equivalent when that preserves the plan. Report a material missing dependency;
   do not invent tool or agent names.
4. Read the affected files and existing patterns. Implement the complete story,
   including error paths. Add focused tests for meaningful behavior.
5. Verify every acceptance criterion with appropriate tests or direct checks.
   For UI changes, verify behavior and the requested design where tools permit.
   State any interaction that could not be observed.
6. Review the changed code for correctness and unnecessary complexity. Use
   `code-review` closeout for the ship gate, plus only relevant specialist checks
   from the plan. Discover callable roles and respect concurrency limits; if
   delegation is unavailable, perform the checks locally and disclose that an
   independent review was not obtained. Do not require nonexistent `system`,
   `code-reviewer`, or `code-simplifier` agents.
7. Verify findings against the code. Fix in-scope blockers and repeat affected
   checks. Record unresolved concerns accurately; do not mark the story complete
   when acceptance criteria or blocking defects remain unresolved.
8. Update the PRD completion state and existing timestamps/log **before** staging
   a story commit. Re-read the updated JSON. If the requested workflow includes
   commits, stage only this story's files plus its PRD update, inspect the staged
   diff and status, then commit the completed story. Prefer one commit per story;
   never include another worker's unfinished changes.
9. Report the resulting commit SHA in the conversation when a commit was made.
   A commit cannot contain its own SHA. Leave its `commit` field null/absent
   rather than writing an uncommitted self-reference. If the project explicitly
   requires persisted SHAs, record the implementation SHA in a separate,
   deliberate bookkeeping commit and describe that convention.
10. Mark the progress UI complete and continue to the next ready story.

A failed commit does not undo verified implementation. Report the commit error,
keep the PRD completion update with the work, and resolve the Git failure before
claiming the story was committed. Never bypass hooks or push without permission.

## Blocked stories and resumption

For a full schema, mark a blocked story as blocked and record the reason in its
existing log. For a lightweight schema, keep `passes` false and track the blocker
in context. Continue independent ready work. Surface the smallest missing input
or external change needed; a tool failure is not proof that the feature is done.

At resumption, reconcile PRD state, working-tree changes, commits, and test
results before selecting the next story. Do not blindly rerun completed work or
assume that an in-progress story has no implementation.

## Parallel execution

Use `--swarm` or the user's explicit parallel request for independent stories.
Run bounded batches that fit available worker slots. Give each worker:

- One story, its relevant spec and criteria, and exact file/module ownership.
- Dependency state and any shared interface decisions.
- An instruction to preserve others' edits and adapt to concurrent changes.
- Responsibility to implement and test, then return files changed, evidence,
  unresolved concerns, and any deviations.

Workers do not commit or edit shared PRD state. The coordinator reviews results,
updates the PRD, and stages/commits serially under the story procedure above.
Overlapping files or dependent stories run sequentially. A failed worker leaves
its story unfinished; inspect partial edits before retrying locally or elsewhere.

## Finish

Check all requested stories and criteria, run the appropriate final lint/test
checks, and review the scoped diff. Do not broaden testing without a reason.
Reconcile the PRD and progress UI. Report what changed, evidence, remaining
blockers, and commit state. Follow existing authorization for any next shipping
step; never infer permission to push or comment on a PR.
