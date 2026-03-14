---
name: codex-plan-review
description: Independent cross-model plan review via Codex CLI. Codex reviews spec.md + prd.json, Claude revises them directly, user controls the loop. Use after /workflows:plan or /deepen-plan, before /workflows:work.
user_invocable: true
argument-hint: "[plan folder path] [model override, e.g., gpt-5.4]"
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
2. **Model override** — e.g., `gpt-5.4` (default: `gpt-5.4`)

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

Write the structured output schema:

```bash
cat > /tmp/codex-plan-schema-${REVIEW_ID}.json <<'SCHEMA'
{
  "type": "object",
  "properties": {
    "issues": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "severity": { "enum": ["critical", "high", "medium", "low"] },
          "category": { "enum": ["correctness", "architecture", "security", "data-model", "edge-case", "story-breakdown", "feasibility"] },
          "description": { "type": "string" },
          "suggestion": { "type": "string" }
        },
        "required": ["severity", "category", "description", "suggestion"],
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
        "low": { "type": "number" }
      },
      "required": ["total", "critical", "high", "medium", "low"],
      "additionalProperties": false
    }
  },
  "required": ["issues", "summary"],
  "additionalProperties": false
}
SCHEMA
```

Send plan to Codex with structured output and here-doc prompt:

```bash
codex exec \
  -m ${MODEL:-gpt-5.4} \
  -s read-only \
  -c model_reasoning_effort=high \
  --output-schema /tmp/codex-plan-schema-${REVIEW_ID}.json \
  -o /tmp/codex-review-${REVIEW_ID}.json \
  <<EOF
You are reviewing an implementation plan before any code is written.

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

For each issue, provide severity, category, description, and suggestion.
EOF
```

**Fail-open:** If codex is not installed or the command fails:
- Self-review spec.md and prd.json against the same 7 categories
- Note clearly: "Self-review (Codex unavailable) — install with `npm install -g @openai/codex`"
- Continue to Step 4

### Step 4: Present Feedback

Read `/tmp/codex-review-${REVIEW_ID}.json` and parse the structured output.

Present to user:

```markdown
## Codex Review -- Round N (model: gpt-5.4)

[Codex's feedback, formatted from JSON]

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
  "agent": "codex-gpt-5.4",
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

### Step 6b: Re-submit to Codex (Round 2+)

Use fresh `codex exec` with structured output and here-doc (session resume does not support `-o` or `--output-schema`):

```bash
codex exec \
  -m ${MODEL:-gpt-5.4} \
  -s read-only \
  -c model_reasoning_effort=high \
  --output-schema /tmp/codex-plan-schema-${REVIEW_ID}.json \
  -o /tmp/codex-review-${REVIEW_ID}.json \
  <<EOF
You are re-reviewing an implementation plan after revisions. This is round N.

Read these files in the repo:
- ${PLAN_FOLDER}/spec.md
- ${PLAN_FOLDER}/prd.json
- ${PLAN_FOLDER}/brainstorm.md (if exists)

Previous round found these issues:
[List prior findings]

Changes made:
[List specific revisions]

Skipped (with rationale):
[List skipped items and why]

Re-review. Focus on:
1. Whether previous issues were addressed
2. Any new issues introduced by revisions
3. Anything missed in prior passes

Review categories: correctness, architecture, security, data-model, edge-case, story-breakdown, feasibility.
EOF
```

Return to Step 4.

### Step 7: Log & Handoff

Add review summary to prd.json `log` array:

```json
{
  "timestamp": "2026-01-30T14:30:00Z",
  "action": "codex_review",
  "review_id": "REVIEW_ID",
  "model": "gpt-5.4",
  "rounds": 3,
  "issues_found": 14,
  "issues_resolved": 12,
  "issues_skipped": 2
}
```

Clean up:

```bash
rm -f /tmp/codex-review-${REVIEW_ID}.json /tmp/codex-plan-schema-${REVIEW_ID}.json
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
- Default model: `gpt-5.4`. Accept override from arguments.
- Always use read-only sandbox — Codex reads the codebase but never writes
- Max 5 rounds as safety cap (user warned, can override)
- Show user each round's feedback and revisions transparently
- **Fail-open:** on any error, fall back gracefully. Never trap the user.
- If a revision contradicts user's explicit requirements, skip it and note why
- Review ID validated against `^[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$`
- Findings written in prd.json `review_findings` format for downstream consumption
- **No temp plan file** — Codex reads the real spec.md and prd.json from the repo
- **Undo is always available** — files are in git, user can revert any round
- **Always pass `-c model_reasoning_effort=high`** — deeper analysis for plan review
- **Use `--output-schema` for structured JSON output** — deterministic parsing, no markdown guessing
- **Use here-doc for prompts** — avoids shell escaping issues with long, multi-line prompts
- **Round 2+ uses fresh `codex exec`** — session resume does not support `-o` or `--output-schema`
- **Do NOT use `--ephemeral`** — silently breaks session resume (creates new session instead)
