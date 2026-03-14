---
name: codex-code-review
description: Independent cross-model code review via Codex CLI. Codex reviews code changes (PR, branch, or staged files), Claude addresses findings directly, user controls the loop. Use after implementation, before merge.
user_invocable: true
argument-hint: "[PR number, branch name, or 'staged'] [model override, e.g., gpt-5.4]"
---

# Codex Code Review

Independent cross-model review of code changes. Codex reviews, Claude fixes code directly, you decide when it's good enough.

## When to Use

- After implementing a feature or fix, before merge
- High-stakes code: auth, payments, data mutations, concurrency
- Large PRs with 10+ files changed
- When you want a genuinely independent perspective (not same-model echo chamber)

## When to Skip

- Trivial changes (typo fixes, config tweaks)
- Already-reviewed and approved code
- Speed matters more than thoroughness

## Prerequisites

Codex CLI: `npm install -g @openai/codex`

## Arguments

Parse `$ARGUMENTS` for:
1. **Review target** — PR number (e.g., `123`), branch name (e.g., `feat/auth`), or `staged` for staged changes
2. **Model override** — e.g., `gpt-5.4` (default: `gpt-5.4`)

If no target provided, detect automatically:
1. Check for open PR on current branch → use that
2. Otherwise, diff current branch against main/master

## Workflow

### Step 1: Setup

Generate a review ID for session tracking:

```bash
REVIEW_ID=$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 3 2>/dev/null || head -c 3 /dev/urandom | od -An -tx1 | tr -d ' \n')
```

Validate format matches `^[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$` (prevents path traversal).

### Step 1b: Deslop

Before review, clean AI-generated slop from the changeset so reviewers focus on real issues.

Run `/deslop` against the changed files. This removes:
- Unnecessary comments (obvious, redundant, style-inconsistent)
- Defensive over-engineering (unreachable try/catch, redundant null checks)
- Type hacks (`as any`, `!` assertions, `@ts-ignore`)
- Style inconsistencies vs surrounding code
- Over-abstraction (single-use helpers, unnecessary intermediates)

If deslop makes changes, inform the user before proceeding:

```markdown
**Deslop pre-pass:** [summary of what was cleaned]
Proceeding to review with cleaned code.
```

If no slop found, proceed silently.

### Step 2: Determine Review Scope

**Target Detection:**

| Input | Type | Action |
|-------|------|--------|
| Numeric (e.g., `123`) | PR number | `gh pr view 123 --json files,baseRefName,headRefName` |
| Branch name | Branch | `git diff main...{branch} --stat` |
| `staged` | Staged changes | `git diff --cached --stat` |
| Empty | Auto-detect | Check for PR on current branch, else diff against main |

**Gather context:**

```bash
# Get the base branch
BASE_BRANCH=$(gh pr view --json baseRefName -q '.baseRefName' 2>/dev/null || echo "main")

# Get the diff
git diff ${BASE_BRANCH}...HEAD > /tmp/codex-diff-${REVIEW_ID}.diff

# Get changed file list
git diff ${BASE_BRANCH}...HEAD --name-only > /tmp/codex-files-${REVIEW_ID}.txt

# Get diff stats
git diff ${BASE_BRANCH}...HEAD --stat
```

If diff is empty, inform user and abort.

**For large diffs (>3000 lines):**
- Warn user about size
- Suggest reviewing in chunks by directory or file group
- Ask user to proceed with full review or select specific paths

### Step 3: Send to Codex (Round 1)

Use the dedicated `codex exec review` subcommand — produces structured comments with P1-P4 severity, file paths, and line ranges out of the box:

```bash
codex exec review \
  --base ${BASE_BRANCH} \
  -m ${MODEL:-gpt-5.4} \
  -c model_reasoning_effort=high \
  -o /tmp/codex-code-review-${REVIEW_ID}.md
```

**Target mapping:**

| Skill input | `codex exec review` flag |
|-------------|--------------------------|
| PR number / branch | `--base ${BASE_BRANCH}` |
| `staged` | `--uncommitted` |
| Specific commit | `--commit ${SHA}` |

**Fail-open:** If codex is not installed or the command fails:
- Self-review the diff against the same 8 categories
- Note clearly: "Self-review (Codex unavailable) — install with `npm install -g @openai/codex`"
- Continue to Step 4

### Step 4: Present Feedback

**Round 1:** Read `/tmp/codex-code-review-${REVIEW_ID}.md` (built-in review format, P1-P4 severity).

**Round 2+:** Read `/tmp/codex-rereview-${REVIEW_ID}.json` (structured JSON per output schema).

Present to user:

```markdown
## Codex Code Review — Round N (model: gpt-5.4)

[Codex's feedback, normalized to consistent format]

---
Issues: X total (Y critical, Z high, ...)
Assessment: [merge-ready / needs-fixes / needs-rework]
```

### Step 5: Address Findings

For each issue, use judgment — do NOT blindly accept every suggestion:

- **Agree** → fix the code directly in the source file
- **Disagree** → note why you're skipping it
- **Contradicts user's intent** → skip and flag

Show the user what changed:

```markdown
### Fixes Applied (Round N)
- [file:line — what changed and why]
- [file:line — what changed and why]
- [Skipped: issue X — reason]
```

### Step 6: User Decides

Use **AskUserQuestion tool**:

**Question:** "Round N complete. X issues fixed, Y skipped. Another round?"

**Options:**
1. **Another round** — Send updated code back to Codex for re-review
2. **Done** — Code is good enough, stop here
3. **Review changes** — Show diff of all fixes applied so far
4. **Undo last round** — Revert changes from this round

If **Another round** and round < 5:
  → Go to Step 6b (Re-submit)

If **Another round** and round = 5:
  → Warn: "Max 5 rounds reached. Proceed anyway or stop here?"

If **Done** → Step 7

If **Review changes**:
  → Show `git diff` for all modified files, then re-ask

If **Undo**:
  → `git checkout -- [files modified in this round]`
  → Re-ask from the previous round's state

### Step 6b: Re-submit to Codex (Round 2+)

Write the structured output schema for re-review findings:

```bash
cat > /tmp/codex-review-schema-${REVIEW_ID}.json <<'SCHEMA'
{
  "type": "object",
  "properties": {
    "issues": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "severity": { "enum": ["critical", "high", "medium", "low"] },
          "category": { "enum": ["correctness", "security", "architecture", "performance", "error-handling", "testing", "maintainability", "type-safety"] },
          "file": { "type": "string" },
          "line": { "type": "string" },
          "description": { "type": "string" },
          "suggestion": { "type": "string" }
        },
        "required": ["severity", "category", "file", "description", "suggestion"],
        "additionalProperties": false
      }
    },
    "summary": {
      "type": "object",
      "properties": {
        "total": { "type": "number" },
        "critical": { "type": "number" },
        "high": { "type": "number" },
        "medium": { "type": "number" },
        "low": { "type": "number" },
        "assessment": { "enum": ["merge-ready", "needs-fixes", "needs-rework"] }
      },
      "required": ["total", "critical", "high", "medium", "low", "assessment"],
      "additionalProperties": false
    }
  },
  "required": ["issues", "summary"],
  "additionalProperties": false
}
SCHEMA
```

Use fresh `codex exec` with structured output and here-doc input (session resume does not support `-o` or `--output-schema`):

```bash
codex exec \
  -m ${MODEL:-gpt-5.4} \
  -s read-only \
  -c model_reasoning_effort=high \
  --output-schema /tmp/codex-review-schema-${REVIEW_ID}.json \
  -o /tmp/codex-rereview-${REVIEW_ID}.json \
  <<EOF
You are re-reviewing code changes after fixes were applied. This is round N.

Read the diff at /tmp/codex-diff-${REVIEW_ID}.diff
Read the changed files list at /tmp/codex-files-${REVIEW_ID}.txt
Then read the full source of each changed file for context.

Previous round found these issues:
[List prior findings]

Changes made:
[List specific fixes]

Skipped (with rationale):
[List skipped items and why]

Re-review. Focus on:
1. Whether previous issues were actually fixed
2. Any new issues introduced by the fixes
3. Anything missed in prior passes

Review categories: correctness, security, architecture, performance, error-handling, testing, maintainability, type-safety.
EOF
```

Return to Step 4.

### Step 7: Cleanup & Summary

Clean up temp files:

```bash
rm -f /tmp/codex-code-review-${REVIEW_ID}.md \
  /tmp/codex-diff-${REVIEW_ID}.diff \
  /tmp/codex-files-${REVIEW_ID}.txt \
  /tmp/codex-review-schema-${REVIEW_ID}.json \
  /tmp/codex-rereview-${REVIEW_ID}.json
```

Present summary:

```
Codex Code Review complete (ID: REVIEW_ID)
  Rounds: N
  Issues found: X (Y critical, Z high)
  Fixed: A | Skipped: B
  Assessment: [merge-ready / needs-fixes]
```

Then use **AskUserQuestion tool**:

**Question:** "Code reviewed and fixes applied. What next?"

**Options:**
1. **Commit fixes** — Stage and commit the changes
2. **Run tests** — Verify nothing broke
3. **Review final diff** — See all changes since review started
4. **Done for now** — Come back later

## Rules

- Claude **actively fixes code** between rounds — the real source files, not copies
- **User controls the loop** — Codex doesn't decide when to stop, you do
- Default model: `gpt-5.4`. Accept override from arguments.
- Always use read-only sandbox — Codex reads the codebase but never writes
- Max 5 rounds as safety cap (user warned, can override)
- Show user each round's feedback and fixes transparently
- **Fail-open:** on any error, fall back gracefully. Never trap the user.
- If a fix contradicts user's explicit intent, skip it and note why
- Review ID validated against `^[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$`
- **Round 1 uses `codex exec review`** — built-in structured review with P1-P4 severity
- **Round 2+ uses `codex exec` with `--output-schema`** — custom 8-category review as structured JSON
- **Always pass `-c model_reasoning_effort=high`** — deeper analysis for review tasks
- **Use here-doc for prompts** — avoids shell escaping issues with long, multi-line prompts
- **Diff-first approach** — Codex reads the diff, then the full files for context
- **Undo is always available** — files are in git, user can revert any round
- For PRs, include PR metadata (title, description) in the Codex prompt for intent context
- Never commit on behalf of the user unless explicitly asked in Step 7
- **Do NOT use `--ephemeral`** — silently breaks session resume (creates new session instead)
