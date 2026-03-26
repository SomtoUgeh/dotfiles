---
name: resolve-pr-parallel
description: Resolve all PR comments using parallel processing, then extract reusable conventions
user-invocable: false
---

Resolve all PR comments using parallel processing, then extract lasting conventions from the review.

Claude Code automatically detects and understands your git context:

- Current branch detection
- Associated PR context
- All PR comments and review threads
- Can work with any PR by specifying the PR number, or ask it.

## Workflow

### 1. Analyze

Get all unresolved comments for PR

```bash
gh pr status
gh pr view PR_NUMBER --json reviewRequests,reviews,comments
gh api repos/{owner}/{repo}/pulls/PR_NUMBER/comments
```

### 2. Plan

Create a TodoWrite list of all unresolved items grouped by type:

- **code_change** — specific code fix requested
- **pattern_change** — applies same fix across multiple files
- **architecture_feedback** — structural or design-level change
- **nit** — style or formatting preference
- **question** — reviewer asking for clarification (may need code comment or doc update)

### 3. Implement (PARALLEL)

Spawn a general-purpose agent for each unresolved item in parallel.

So if there are 3 comments, spawn 3 agents in parallel:

1. Task general-purpose(comment1)
2. Task general-purpose(comment2)
3. Task general-purpose(comment3)

Always run all in parallel subagents/Tasks for each Todo item.

**For pattern_change comments:** the agent MUST list every affected file, apply to ALL locations, and grep/search to confirm no instances were missed. One commit for the entire pattern change.

### 4. Commit & Resolve

- Commit changes
- Push to remote
- Reply to resolved threads with a brief summary of changes made

Last, check `gh pr view PR_NUMBER --json comments` again to see if all comments are resolved. They should be, if not, repeat the process from 1.

### 5. Extract Conventions

After all comments are resolved, extract reusable conventions from the review. This is the most valuable long-term output — every review comment is a signal about how this codebase/team expects things done.

#### 5.1 Identify Conventions

For each resolved comment, determine if it reveals a reusable convention:

**Is a convention if:**

- Reviewer says "always do X" or "we do X this way"
- Reviewer corrects a naming pattern (implies the convention applies everywhere)
- Reviewer asks for a structural change that would apply to all similar code
- Reviewer flags a missing practice that should be standard
- The change is about consistency with existing code, not a one-off fix
- Reviewer references a team standard, style guide, or established pattern

**Is NOT a convention if:**

- One-off bug fix specific to this code
- Reviewer preference that contradicts established codebase patterns
- Factual correction (wrong variable name, typo)
- Removing dead code or fixing a mistake unique to this PR

#### 5.2 Write Each Convention as a Rule

````markdown
### [Convention Title]

**Source:** PR #[number], comment by @[reviewer] on [file]
**Added:** [date]

**Rule:** [Clear, specific instruction — not vague. Should be copy-pasteable into a spec.]

**Example (before):**

```[language]
[code before]
```

**Example (after):**

```[language]
[code after]
```

**Rationale:** [Why this convention exists]
````

#### 5.3 Write to Layer Files

Conventions accumulate in `docs/conventions/` — one file per layer, growing over time across PRs:

- `docs/conventions/frontend.md` — hooks, components, state, UI patterns, data fetching, forms, error handling
- `docs/conventions/backend.md` — routes, controllers, services, database, auth, middleware, API design, validation
- `docs/conventions/general.md` — project-wide: naming, DTO structure, git practices, testing strategy, file organisation

**If the layer file doesn't exist:** create it with category headings relevant to that layer.

**If it already exists — merge and dedupe:**

1. Read the existing file
2. For each new convention, check for semantic duplicates:
   - Same rule about same pattern → **duplicate, skip**
   - Same category but different rule → **not duplicate, add**
   - Same rule but better example from new PR → **update existing entry**, add new PR as additional source
   - Contradicts existing convention → **flag to user** with AskUserQuestion
3. Append new conventions at the end of the correct category section
4. Preserve existing conventions exactly — don't rewrite or reorganise

**Dedupe heuristic:** Two conventions are duplicates if they would produce the same code change when applied to the same codebase. Compare by effect, not wording.

#### 5.4 Commit Convention Files

```bash
git add docs/conventions/
git commit -m "docs(conventions): extract [N] conventions from PR #[number]

Layers updated: [frontend, backend, general — whichever were touched]
New conventions: [count]
Updated conventions: [count]
Duplicates skipped: [count]"
```

Separate commit from code changes — conventions are documentation, not code fixes.

### 6. Report

```
## PR Review Comments Addressed

**PR #[number]:** [title]
**Comments addressed:** [N] of [M] actionable
**Comments skipped:** [list with reasons, if any]

## Conventions Extracted

**New conventions:** [count]
**Updated conventions:** [count]
**Duplicates skipped:** [count]
**Layer files updated:** [list]
```
