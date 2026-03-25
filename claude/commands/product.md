---
name: product
description: Founder-mode product review — challenge premises, find gaps, ensure quality before implementation
argument-hint: "[plan folder path, PR number, or feature description]"
user-invocable: true
effort: max
---

# Product

Rigorous product review inspired by founder-mode thinking. Challenge every premise, find every gap, ensure the plan ships at the highest possible standard.

Do NOT make any code changes. Do NOT start implementation. Your only job is to review with maximum rigor and the appropriate level of ambition.

## Review Target

<review_target> #$ARGUMENTS </review_target>

## Philosophy

Three review postures — user selects one, you COMMIT to it throughout:

| Mode | Posture | Mindset |
|------|---------|---------|
| **EXPAND** | Build the cathedral | "What would make this 10x better for 2x the effort?" Push scope UP. Dream. |
| **HOLD** | Make it bulletproof | Scope is accepted. Catch every failure mode, test every edge case, map every error path. |
| **REDUCE** | Surgical minimum | Find the minimum viable version. Cut everything else. Be ruthless. |

**Critical rule:** Once selected, do not drift. If EXPAND, don't argue for less. If REDUCE, don't sneak scope back in. Raise concerns once in Step 0 — after that, execute faithfully.

## Prime Directives

1. **Zero silent failures.** Every failure mode must be visible — to the system, to the team, to the user.
2. **Every error has a name.** Don't say "handle errors." Name the specific error, what triggers it, what catches it, what the user sees.
3. **Data flows have shadow paths.** Every flow has a happy path and three shadows: nil input, empty input, upstream error. Trace all four.
4. **Interactions have edge cases.** Double-click, navigate-away-mid-action, slow connection, stale state, back button. Map them.
5. **Observability is scope, not afterthought.** Dashboards, alerts, and runbooks are first-class deliverables.
6. **Everything deferred must be written down.** Vague intentions are lies. Todos or it doesn't exist.
7. **Optimize for the 6-month future.** If this solves today's problem but creates tomorrow's, flag it.

## Workflow

### PRE-REVIEW: Taste Calibration (EXPAND mode, or when reviewing a codebase)

Before Step 0, identify quality benchmarks in the existing codebase:

- **2-3 well-designed files or patterns** — note them as style references
- **1-2 frustrating or poorly designed patterns** — these are anti-patterns to avoid repeating

Report findings before proceeding. This calibrates your taste for the review.

### Step 0: Nuclear Scope Challenge + Mode Selection

This is the most important step. It exists to prevent building the wrong thing well.

#### 0a. Detect Review Target

| Input | Type | Action |
|-------|------|--------|
| `docs/plans/*/` path | Plan folder | Read spec.md, prd.json, brainstorm.md |
| Numeric (e.g., `123`) | PR number | `gh pr view 123 --json title,body,files` |
| GitHub URL | PR URL | Extract PR number, fetch metadata |
| Branch name | Branch | Checkout or worktree |
| Feature description | Freeform | Review the described feature concept |
| Empty | Current context | Ask what to review |

**If plan folder detected:**
1. Read spec.md for the full plan
2. Read prd.json for story breakdown
3. Read brainstorm.md if it exists (for R table, shapes, fit check)
4. Check for breadboard tables

**If PR detected:**
1. Fetch PR metadata and changed files
2. Read the PR description for context

#### 0b. System Audit

Before reviewing, gather context:

- Task repo-research-analyst("Understand codebase patterns, architecture, and conventions relevant to: <review_target>")

Read CLAUDE.md, any existing architecture docs, and recently modified files relevant to the review target.

**Map:**
- Current system state and relevant patterns
- What's already in flight (open PRs, branches)
- Known pain points relevant to this plan
- Existing TODOs/FIXMEs in files this plan touches

#### 0c. Mode Selection

Use **AskUserQuestion tool** to select review mode:

**Question:** "How should I approach this review?"

**Options:**
1. **EXPAND** — Dream big. Challenge scope upward. Find the 10-star version.
2. **HOLD** — Scope is accepted. Make it bulletproof. Maximum rigor.
3. **REDUCE** — Strip to essentials. Find the minimum viable version.

**Context-dependent defaults** (suggest but let user override):
- Greenfield feature -> suggest EXPAND
- Bug fix or hotfix -> suggest HOLD
- Refactor -> suggest HOLD
- Plan touching >15 files -> suggest REDUCE
- User says "go big" / "ambitious" -> EXPAND, no question

#### 0d. Premise Challenge

Ask these questions ruthlessly. Do not accept surface-level answers.

1. **Is this the right problem to solve?** Could a different framing yield a dramatically simpler or more impactful solution? What if the problem statement itself is wrong?
2. **What is the actual user/business outcome?** Is the plan the most direct path to that outcome, or is it solving a proxy problem? Would the user even notice if this shipped?
3. **What would happen if we did nothing?** Real pain point or hypothetical one? If the answer is "not much," this plan might not be worth the engineering cost.
4. **Who is the user, really?** Not "users" in the abstract. Name the specific persona. What do they care about? What are they doing 5 seconds before and after using this feature?
5. **What's the competitive landscape?** How do others solve this? What can we learn from their approach? What would make ours 10x better?

Use **AskUserQuestion tool** for each concern. One at a time. Recommend + WHY. If no issues, state that and move on.

#### 0e. Existing Code Leverage

Before planning new work, map what already exists:

1. **What existing code already partially or fully solves each sub-problem?** Map every sub-problem to existing code. Can we capture outputs from existing flows rather than building parallel ones?
2. **Is this plan rebuilding anything that already exists?** If yes, explain why rebuilding is better than refactoring.
3. **What can be reused vs what must be built from scratch?** The best code is code you don't write.

#### 0f. Dream State Mapping

Describe the ideal end state of this system 12 months from now. Does this plan move toward that state or away from it?

```
CURRENT STATE                  THIS PLAN                  12-MONTH IDEAL
[describe]          --->       [describe delta]    --->    [describe target]
```

Use **AskUserQuestion tool** if the plan moves AWAY from the ideal state — that's a red flag.

#### 0g. Mode-Specific Deep Dive

**For EXPAND — run all three:**

1. **10x check:** What's the version that's 10x more ambitious and delivers 10x more value for 2x the effort? Describe it concretely. Not hand-wavy — what would the user actually experience?
2. **Platonic ideal:** If the best engineer in the world had unlimited time and perfect taste, what would this system look like? What would the user FEEL when using it? Start from experience, not architecture.
3. **Adjacent delight:** What 30-minute improvements would make this feature sing? Things where a user would think "oh nice, they thought of that." List at least 3.

**For HOLD — run:**

1. **Failure inventory:** List every way this can fail in production. Not just errors — silent data corruption, race conditions, state inconsistencies, third-party outages.
2. **Edge case exhaustion:** For every user-facing flow, list 5 edge cases. If you can't think of 5, you haven't thought hard enough.

**For REDUCE — run:**

1. **Core value extraction:** What is the ONE thing this must do? Strip everything else.
2. **Dependency audit:** For each piece of scope, ask: "Does the core value work without this?" If yes, cut it.
3. **Time-to-value:** What's the fastest path to putting this in front of a user? What can ship in 1 day vs 1 week vs 1 month?

#### 0h. Temporal Interrogation (EXPAND and HOLD modes)

Think ahead to implementation. What decisions will need to be made during implementation that should be resolved NOW?

```
HOUR 1 (foundations):     What does the implementer need to know?
HOUR 2-3 (core logic):   What ambiguities will they hit?
HOUR 4-5 (integration):  What will surprise them?
HOUR 6+ (polish/tests):  What will they wish they'd planned for?
```

Surface these as questions for the user NOW — not as "figure it out later."

### Step 1: What Already Exists & NOT In Scope

Write two explicit sections:

**What already exists:** List existing code, patterns, infrastructure this plan builds on. Prevents re-inventing what's already there.

**NOT in scope:** List everything discussed or considered that is explicitly NOT being built. This prevents scope creep and documents decisions.

**Dream state delta (EXPAND mode only):** Describe the gap between what this plan delivers and the platonic ideal. This is the roadmap for future work.

## Formatting Rules

- **NUMBER** issues (1, 2, 3...) and **LETTER** options (A, B, C...)
- Label with NUMBER + LETTER (e.g., "3A", "3B")
- Recommended option always listed first
- One sentence max per option
- After each section, pause and wait for feedback
- Use **CRITICAL GAP** / **WARNING** / **OK** for scannability
- **Diagrams are mandatory** for non-trivial flows — use ASCII art inline while discussing, Mermaid for final artifacts. Use `skill: beautiful-mermaid` to render.

## Output: Findings

Choose output based on review target:

### Option A: Update prd.json (if plan folder)

Add `review_findings` to each relevant story in prd.json:

```json
{
  "severity": "P1",
  "category": "security",
  "finding": "SQL injection risk in user input",
  "file": "src/api/users.ts:42",
  "suggestion": "Use parameterized queries"
}
```

### Option B: Create file-todos (for standalone reviews)

Use `skill: file-todos` for structured todo management:

```
{id}-pending-{priority}-{description}.md
```

## Completion Summary

```
MODE: [EXPAND / HOLD / REDUCE]
CRITICAL GAPS: [count] — [list if any]
UNRESOLVED DECISIONS: [count] — [list if any]
CONFIDENCE: [high / medium / low] — [one-line reason]
RECOMMENDED NEXT: [specific action]
```

### Unresolved Decisions

If any AskUserQuestion goes unanswered, note it here. Never silently default.

## Next Steps

Use **AskUserQuestion tool** to present:

**Question:** "Product review complete. What would you like to do next?"

**Options:**
1. **Run `/workflows:review`** — Follow up with code-level multi-agent review (architecture, errors, security, performance, tests, deployment)
2. **Run `/triage`** — Triage findings into actionable todos
3. **Revise the plan** — Update spec.md/prd.json based on findings
4. **Done** — Review complete, proceed with implementation
