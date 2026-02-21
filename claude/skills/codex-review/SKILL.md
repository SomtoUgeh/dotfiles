---
name: codex-review
description: Independent cross-model plan review via Codex CLI. Codex reviews spec.md + prd.json, Claude revises them directly, user controls the loop. Use after /workflows:plan or /deepen-plan, before /workflows:work.
user_invocable: true
argument-hint: "[plan folder path] [model override, e.g., o4-mini]"
---

# Codex Plan Review

Independent cross-model review of implementation plans. Codex reviews, Claude revises spec.md and prd.json directly, you decide when it's good enough.

## When to Use

- After `/workflows:plan` or `/deepen-plan`, before `/workflows:work`
- High-stakes plans: auth, payments, data models, multi-service coordination
- Plans that will take days to implement
- When you want a genuinely independent perspective (not same-model echo chamber)

## When to Skip

- Simple bug fixes, small changes
- Already-validated approaches
- Speed matters more than thoroughness

## Prerequisites

Codex CLI: `npm install -g @openai/codex`

## Arguments

Parse `$ARGUMENTS` for:
1. **Plan folder path** — e.g., `docs/plans/2026-01-30-feat-user-auth/`
2. **Model override** — e.g., `o4-mini` (default: `gpt-5.3-codex`)

If no path provided, check `ls docs/plans/` sorted by date and ask user which plan to review.

## Workflow

### Step 1: Setup

Generate a review ID for session tracking:

```bash
REVIEW_ID=$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 3 2>/dev/null || head -c 3 /dev/urandom | od -An -tx1 | tr -d ' \n')
```

Validate format matches `^[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$` (prevents path traversal).

### Step 2: Load Plan

Read the plan folder:
- `spec.md` (required)
- `prd.json` (required)
- `brainstorm.md` (optional — shaping context)

If spec.md or prd.json missing, inform user and abort.

### Step 3: Send to Codex

```bash
codex exec \
  -m ${MODEL:-gpt-5.3-codex} \
  -s read-only \
  -o /tmp/codex-review-${REVIEW_ID}.md \
  "You are reviewing an implementation plan before any code is written.

Read these files in the repo:
- ${PLAN_FOLDER}/spec.md
- ${PLAN_FOLDER}/prd.json
- ${PLAN_FOLDER}/brainstorm.md (if exists)

Review for:

1. **Correctness** — Will this achieve the stated goals? Are acceptance criteria testable?
2. **Architecture** — Sound technical choices? Missing components? Over-engineering?
3. **Security** — Auth gaps, injection risks, data exposure, OWASP concerns?
4. **Data Model** — Schema conflicts, missing constraints, migration risks?
5. **Edge Cases** — Race conditions, concurrency, error paths, failure modes?
6. **Story Breakdown** — Stories atomic? Dependencies correct? Anything missing?
7. **Feasibility** — Unrealistic assumptions or missing prerequisites?

For each issue, provide:
- **Severity:** critical / high / medium / low
- **Category:** correctness, architecture, security, data-model, edge-case, story-breakdown, feasibility
- **Description:** What's wrong
- **Suggestion:** How to fix it

End with a summary: total issues, breakdown by severity."
```

Capture the Codex session ID from output (line containing `session id: <uuid>`). Store as `CODEX_SESSION_ID`.

**Fail-open:** If codex is not installed or the command fails:
- Self-review spec.md and prd.json against the same 7 categories
- Note clearly: "Self-review (Codex unavailable) — install with `npm install -g @openai/codex`"
- Continue to Step 4

### Step 4: Present Feedback

Read `/tmp/codex-review-${REVIEW_ID}.md` (round 1) or captured stdout (subsequent rounds).

Present to user:

```markdown
## Codex Review -- Round N (model: gpt-5.3-codex)

[Codex's feedback]

---
Issues: X total (Y critical, Z high, ...)
```

### Step 5: Revise spec.md and prd.json

Address each issue directly in the real files. Use your judgment — do NOT blindly accept every suggestion.

For each issue:
- **Agree** → edit spec.md and/or prd.json directly
- **Disagree** → note why you're skipping it
- **Contradicts user's requirements** → skip and flag

Show the user what changed:

```markdown
### Revisions (Round N)
- [What changed in spec.md and why]
- [What changed in prd.json and why]
- [Skipped: issue X — reason]
```

For critical/high issues that map to specific stories, add to that story's `review_findings` in prd.json:

```json
{
  "severity": "high",
  "category": "security",
  "agent": "codex-gpt-5.3-codex",
  "finding": "No auth on agent write endpoints",
  "suggestion": "Add per-agent API keys with ACL",
  "status": "resolved",
  "resolved_at": "2026-01-30T14:45:00Z"
}
```

### Step 6: User Decides

Use **AskUserQuestion tool**:

**Question:** "Round N complete. X issues addressed, Y skipped. Another round?"

**Options:**
1. **Another round** — Send updated plan back to Codex for re-review
2. **Done** — Plan is good enough, proceed to handoff
3. **Review changes** — Show diff of what changed in spec.md and prd.json
4. **Undo last round** — Revert changes from this round (git checkout the files)

If **Another round** and round < 5:
  → Go to Step 6b (Re-submit)

If **Another round** and round = 5:
  → Warn: "Max 5 rounds reached. Proceed anyway or stop here?"

If **Done** → Step 7

If **Review changes**:
  → Show `git diff` for spec.md and prd.json, then re-ask

If **Undo**:
  → `git checkout -- ${PLAN_FOLDER}/spec.md ${PLAN_FOLDER}/prd.json`
  → Re-ask from the previous round's state

### Step 6b: Re-submit to Codex

Resume existing session for context continuity:

```bash
codex exec resume ${CODEX_SESSION_ID} \
  "The plan has been revised based on your feedback. Re-read:
- ${PLAN_FOLDER}/spec.md
- ${PLAN_FOLDER}/prd.json

Changes made:
[List specific changes]

Skipped (with rationale):
[List skipped items and why]

Re-review. Focus on whether previous issues were addressed and any new issues introduced.

Provide findings in the same format: severity, category, description, suggestion.
End with summary." 2>&1
```

**Note:** `codex exec resume` does NOT support `-o`. Capture full stdout.

**If resume fails** (session expired): fall back to fresh `codex exec` with prior round context in the prompt.

Return to Step 4.

### Step 7: Log & Handoff

Add review summary to prd.json `log` array:

```json
{
  "timestamp": "2026-01-30T14:30:00Z",
  "action": "codex_review",
  "review_id": "REVIEW_ID",
  "model": "gpt-5.3-codex",
  "rounds": 3,
  "issues_found": 14,
  "issues_resolved": 12,
  "issues_skipped": 2
}
```

Clean up:

```bash
rm -f /tmp/codex-review-${REVIEW_ID}.md
```

Present summary:

```
Codex Review complete (ID: REVIEW_ID)
  Rounds: N
  Issues found: X (Y critical, Z high)
  Resolved: A | Skipped: B
  spec.md and prd.json updated in place.
```

Then use **AskUserQuestion tool**:

**Question:** "Plan reviewed and updated. What next?"

**Options:**
1. **Start `/workflows:work`** — Begin implementing stories
2. **Run `/deepen-plan`** — Further enrich with skill/agent discovery
3. **Review final plan** — Read updated spec.md
4. **Done for now** — Come back later

## Rules

- Claude **actively revises spec.md and prd.json** between rounds — the real files, not copies
- **User controls the loop** — Codex doesn't decide when to stop, you do
- Default model: `gpt-5.3-codex`. Accept override from arguments.
- Always use read-only sandbox — Codex reads the codebase but never writes
- Max 5 rounds as safety cap (user warned, can override)
- Show user each round's feedback and revisions transparently
- **Fail-open:** on any error, fall back gracefully. Never trap the user.
- If a revision contradicts user's explicit requirements, skip it and note why
- Review ID validated against `^[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$`
- Findings written in prd.json `review_findings` format for downstream consumption
- **No temp plan file** — Codex reads the real spec.md and prd.json from the repo
- **Undo is always available** — files are in git, user can revert any round
