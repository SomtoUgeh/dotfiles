# Closeout review contract

Adapted from [openclaw/agent-skills autoreview](https://github.com/openclaw/agent-skills/blob/main/skills/autoreview/SKILL.md)
(MIT ideas; not a vendored 440KB helper). Use with our shared model policy in
AGENTS.md: **Fable/Sol review**, **Grok implement**, no nested Fable.

This is a **ship/commit gate**, not a permission to rewrite the task, and not
product behavior-validation (that is separate: running app/CLI against a
behavior contract).

## When to use

- After non-trivial code edits, before final/commit/ship
- Local dirty work, branch vs base, or open PR
- User asks for closeout, second-model review, autoreview, or "is this ready?"

**Skip heavy closeout** when the entire diff is prose-only internal notes or
`SKILL.md` docs. Still skim the diff and run any lightweight doc checks the
repo has. Exception does **not** cover user-facing docs, config, scripts,
generated clients, or behavior changes.

## Severity contract

- **Default: P0/P1 only** — issues worth blocking because they break the normal
  flow, outcome, or safety boundary.
- Widen to P2/P3 only when the user asks (`--max-priority`, "full review",
  "nitpick") or when routing into `workflows-review` (exhaustive mode).
- Treat all findings as **advisory** until verified in real code.

## Reviewer posture

- Verify every accepted finding by reading the real code path and adjacent files.
- Read dependency docs/types when the finding depends on external behavior.
- Reject unrealistic edge cases, speculative risks, broad rewrites, and fixes
  that over-complicate the codebase.
- Prefer small fixes at the right ownership boundary. No refactor unless it
  clearly kills a bug class in the current scope.
- When an accepted finding shows a repeated pattern, scan the **current PR
  scope** for siblings before fixing.
- Fix the scoped bug class at once when practical; stop at touched surfaces,
  owner boundaries, and clear follow-up territory.
- Security is always in scope, but only report concrete, actionable risk or
  removed safety checks — not theoretical threat essays.
- If rejecting a finding as intentional, add a brief inline comment only when
  it documents a real invariant future reviewers need.

## Scope governor

Before the first review, freeze a scope baseline:

- original request / issue
- target branch and intended behavior
- owner boundary
- changed files and non-test LOC (use intended PR diff on bloated branches)

Classify each finding before patching:

| Class | Meaning |
|-------|---------|
| **In-scope blocker** | Introduced by this diff, same owner boundary, fixable without changing the task contract |
| **Follow-up** | Real but adjacent surface, cleanup, or broader hardening |
| **Stop-and-escalate** | New protocol/config/storage/public API, different owner, release-process change, or design choice outside the request |

Stop and report instead of continuing when:

- a narrow PR becomes architecture / protocol / migration / release-process work
- the diff grows past ~2× original files or non-test LOC without approval
- **two** review-triggered patch cycles have not converged — pause and reclassify
- the real fix is "define the canonical contract first"
- the PR would no longer describe the same behavior, issue, or owner boundary

After a two-cycle pause, continue only for remaining in-scope blockers.
Otherwise land the safe subset and open/request a follow-up.

Do not push or stack fix commits while scope/proof is unresolved. Keep
exploratory edits local.

**Critical exceptions** (may justify wider scope): active data loss, crash,
broken install/upgrade, release blocker, concrete security exposure. Nothing
else is critical enough to blow up scope.

## Release / hotfix branches

Even when the branch name is not release-like, freeze discipline applies for
release, beta, stable, hotfix, signing, notarization, package-publish work:

- Fix only release blockers, failed release infra, exact backports,
  install/upgrade breakage, data loss, crashes, or concrete security exposure.
- Non-blocking findings → follow-ups for `main`, not release-branch scope.
- No new product behavior, config surface, protocol, migration, or process
  policy unless it directly unblocks the release.
- Proof stays tied to the release target (ref, failing check, smallest command).

## Models (this stack)

| Step | Model / harness | Effort |
|------|-----------------|--------|
| Primary closeout gate | **fable-5** (Claude session) | high |
| Independent second opinion | **gpt-5.6-sol** via `codex review` | high |
| Optional third opinion | **opus-4.8** | high |
| Apply accepted fixes | **grok-4.5** via `grok -p` | high |
| Fix if Grok missed / hard bug | **gpt-5.6-sol** via `codex exec` | high / xhigh |
| UI / polish fixes | **fable-5** or **opus-4.8** | med / high |

**One Fable gate.** Never nest Fable reviewers under Fable. Multi-reviewer
panels only when the user asks or risk clearly justifies spend; the main agent
still verifies every accepted finding before fixing.

Never invent Claude model names for Sol or Grok.

## How to run the gate

### 1. Pick the target

| Work state | Diff command |
|------------|--------------|
| Dirty local (staged/unstaged/untracked) | `git status --porcelain` then `git diff HEAD` + untracked as added |
| Branch / PR not yet clean main | `git merge-base` with `origin/main` (or PR base from `gh pr view`) then three-dot or merge-base..HEAD |
| Single commit already on main | review that commit, not empty main-vs-origin/main |
| Open PR | prefer PR base: `base=$(gh pr view --json baseRefName -q .baseRefName)` |

Do **not** force local/dirty mode after commits are made. Do not push just to review.

### 2. Primary review (pick one path)

**A. Claude / Fable (default high-taste gate)**

In a Fable (or high-effort Claude) session, review the collected diff against this
contract. Output:

```markdown
## Summary
<2–4 sentences: what changed, overall risk, ship/no-ship>

## Issues

### Issue N — Severity: P0|P1|P2|P3
- File: path:line
- Description: ...
- Suggestion: ...
- Status: open
```

Default: only emit P0/P1 unless asked for wider.

**B. Codex Sol (independent / Codex-native)**

```bash
codex review --uncommitted
# or
codex review --base main
# or PR base
codex review --base "origin/$(gh pr view --json baseRefName -q .baseRefName)"
```

Investigate only (no edits):

```bash
codex exec -s read-only -m gpt-5.6-sol -c model_reasoning_effort="high" "…"
```

**C. Optional dual pass**

Run Fable gate, then Sol. Keep disagreements in a short **Tension** list. Do
not auto-merge opinions — the synthesizer (you) decides after verifying code.

### 3. Accept / reject loop

For each finding:

1. Read the cited path and surrounding call sites.
2. Accept (in-scope blocker), defer (follow-up), or reject (wrong / intentional).
3. Apply accepted fixes with the **implementer** model row above — not the
   reviewer.
4. Rerun focused tests for touched behavior.
5. Rerun the **same** review gate until no accepted/actionable findings remain
   **or** the two-cycle pause / scope governor trips.

Stop as soon as the gate is clean. Do not run another review only for nicer
wording.

### 4. Final report

Always include:

- review command / mode used (and models)
- tests/proof run
- findings accepted / rejected (brief why)
- clean result of the final gate run, or conscious rejections

## Parallel tests (optional)

Format first if formatting shifts line numbers. Then tests and review may run
in parallel when safe. If either forces code changes, rerun both until the gate
is clean.

Do not put secrets in printed commands.

## What we intentionally do not vend

OpenClaw's `scripts/autoreview` helper (~440KB) covers TruffleHog pre-scan,
engine isolation sandboxes, panel orchestration, and chunking. We rely on:

- agent-driven diff collection + Fable/Sol review
- repo CI / hooks for secret scan where configured
- `codex review` for structured Codex isolation

If you later want the full helper, install it from
`openclaw/agent-skills` as a separate tool — do not fork behavior into this skill.
