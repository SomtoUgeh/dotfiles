---
name: product-review
description: Founder-mode product review — challenge premises, find gaps, ensure quality before implementation
argument-hint: "[plan folder path, PR number, or feature description]"
user-invocable: true
---

# Product Review

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

### Step 1: Architecture & System Design

Evaluate and diagram:

- **Component boundaries.** Dependency graph of new vs existing components.
- **Data flow — all four paths.** For every new data flow:
  - Happy path (data flows correctly)
  - Nil path (input is nil/missing)
  - Empty path (input is present but empty/zero-length)
  - Error path (upstream call fails)
- **State machines.** For every new stateful object, diagram states and transitions. Include impossible/invalid transitions and what prevents them.
- **Coupling concerns.** What's now coupled that wasn't before? Is it justified?
- **Scaling characteristics.** What breaks first at 10x load? 100x?
- **Single points of failure.** Map them.
- **Rollback posture.** If this ships and immediately breaks — git revert? Feature flag? DB migration rollback?

Use `skill: technical-svg-diagrams` for architecture diagrams when complexity warrants it.

**STOP.** Use AskUserQuestion once per issue found. Recommend + WHY. If no issues, state what you found and move on.

### Step 2: Error & Failure Map

This catches silent failures. Not optional.

For every new method, service, or codepath that can fail, build this table:

```
METHOD/CODEPATH          | WHAT CAN GO WRONG           | ERROR TYPE
-------------------------|-----------------------------|-----------------
ExampleService.call()    | API timeout                 | TimeoutError
                         | API returns 429             | RateLimitError
                         | Malformed response          | ParseError
                         | DB connection exhausted     | ConnectionError
```

For each entry, answer:
- **What catches it?** (try/catch, error boundary, middleware)
- **What does the user see?** (error message, loading state, blank page)
- **Is it logged?** (structured log with context, or silent?)
- **Is it tested?** (unit test, integration test, or untested?)
- **Is it retried?** (automatic retry, manual retry, or permanent failure?)

**Failure Modes Registry** — consolidate all findings into this table:

```
CODEPATH             | FAILURE MODE     | CAUGHT? | TESTED? | USER SEES?     | LOGGED?
---------------------|------------------|---------|---------|----------------|--------
```

Any row with CAUGHT=N, TESTED=N, USER SEES=Silent -> **CRITICAL GAP**. These are the silent killers.

**STOP.** AskUserQuestion for any CRITICAL GAP found.

### Step 3: Security & Threat Model

Security gets its own section — it's not a sub-bullet of architecture.

Evaluate:
- **Attack surface expansion.** New endpoints, params, file paths, background jobs?
- **Input validation.** For every new user input: validated, sanitized, rejected loudly on failure? Check: nil, empty, wrong type, exceeding max length, unicode edge cases, injection attempts.
- **Authorization.** For every new data access: scoped to right user/role? Direct object reference vulnerability? Can user A access user B's data?
- **Secrets and credentials.** New secrets? In env vars, not hardcoded? Rotatable?
- **Dependency risk.** New packages? Security track record?
- **Data classification.** PII, payment data, credentials? Handling consistent with existing patterns?
- **Injection vectors.** SQL, command, template, LLM prompt injection.
- **Audit logging.** Sensitive operations have an audit trail?

**STOP.** AskUserQuestion for any HIGH severity finding.

### Step 4: Data Flow & UX Edge Cases

Trace data through the system and interactions through the UI with adversarial thoroughness.

**Data edge cases:**
- What happens with concurrent writes to the same resource?
- What happens during partial failure (3 of 5 operations succeed)?
- What happens with stale data (cached version vs reality)?
- What about timezone, locale, currency edge cases?

**UX interaction edge cases:**
- Double-click / rapid submission
- Navigate away mid-action (form half-submitted)
- Slow connection (3G, high latency)
- Stale state (tab left open for hours)
- Back button after action
- Multiple tabs with same session
- Empty states (first-time user, no data yet)
- Loading states (skeleton? spinner? nothing?)

If reviewing UI code, load: `skill: emil-design-engineering` for accessibility and interaction checklist.

**STOP.** AskUserQuestion for unhandled edge cases.

### Step 5: Code Quality & Patterns

Evaluate:
- **Pattern consistency.** Does new code fit existing codebase patterns? If it deviates, is there a reason?
- **DRY violations.** Same logic elsewhere? Flag it with file:line reference.
- **Naming quality.** Named for WHAT it does, not HOW.
- **Over-engineering.** Abstractions solving problems that don't exist yet?
- **Under-engineering.** Fragile code assuming happy path only?
- **Complexity.** Any method branching more than 5 times? Propose a refactor.

Cross-reference with Section 2 — this section reviews patterns; Section 2 maps specifics.

**STOP.** AskUserQuestion for issues found.

### Step 6: Test Coverage Analysis

Map every new thing this plan introduces:

```
NEW FLOWS:
  [list each new user-visible interaction]

NEW DATA PATHS:
  [list each new data transformation]

NEW INTEGRATIONS:
  [list each external system interaction]
```

For each: does a test exist? What kind? (unit, integration, e2e)

Flag gaps explicitly. Testing gaps are scope — they belong in the plan, not in "we'll add tests later."

**STOP.** AskUserQuestion for critical test gaps.

### Step 7: Performance Review

Evaluate:
- **N+1 queries.** For every new data fetch in a loop: is it batched?
- **Memory usage.** New data structures — what's the max size in production?
- **Database indexes.** For every new query: is there an index?
- **Caching opportunities.** Expensive computation or external calls — should they be cached?
- **Background job sizing.** Worst-case payload, runtime, retry behavior?
- **Slow paths.** Top 3 slowest new codepaths and estimated p99 latency.
- **Bundle size.** (If frontend) New dependencies added to client bundle?

**STOP.** AskUserQuestion for issues found.

### Step 8: Observability & Debuggability

New systems break. This ensures you can see why.

Evaluate:
- **Logging.** Structured log lines at entry, exit, and each significant branch?
- **Metrics.** What metric tells you it's working? What tells you it's broken?
- **Tracing.** Cross-service or cross-job flows: trace IDs propagated?
- **Alerting.** What new alerts should exist?
- **Dashboards.** What panels do you want on day 1?
- **Debuggability.** Bug reported 3 weeks post-ship — can you reconstruct what happened from logs alone?
- **Runbooks.** For each new failure mode: what's the operational response?

**STOP.** AskUserQuestion for gaps.

### Step 9: Deployment & Rollout

Evaluate:
- **Migration safety.** New DB migrations: backward-compatible? Zero-downtime? Table locks?
- **Feature flags.** Should any part be behind a flag?
- **Rollout order.** Correct sequence: migrate first, deploy second?
- **Rollback plan.** Explicit step-by-step.
- **Deploy-time risk.** Old code and new code running simultaneously — what breaks?
- **Post-deploy verification.** First 5 minutes? First hour?
- **Smoke tests.** What automated checks run immediately post-deploy?

**STOP.** AskUserQuestion for risks flagged.

### Step 10: Future-Proofing & Technical Debt

Evaluate:
- **Debt introduced.** Code debt, operational debt, testing debt, documentation debt.
- **Path dependency.** Does this make future changes harder?
- **Knowledge concentration.** Documentation sufficient for a new engineer?
- **Reversibility.** Rate 1-5: 1 = one-way door, 5 = easily reversible.
- **The 1-year question.** Read this plan as a new engineer in 12 months — obvious?

### Step 11: Delight Opportunities (EXPAND mode only)

Identify at least 5 "bonus chunk" opportunities (<30 min each) that would make users think "oh nice, they thought of that."

Present each as its own AskUserQuestion. For each:
- What it is
- Why it would delight users
- Effort estimate

Options per opportunity:
- **A)** Add to todos as a future item
- **B)** Skip
- **C)** Add to current scope

### Step 12: What Already Exists & NOT In Scope

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
- **Diagrams are mandatory** for non-trivial flows — use ASCII art inline while discussing, Mermaid for final artifacts. Use `skill: beautiful-mermaid` to render. Produce all that apply: system architecture, data flow (with shadow paths), state machines, error flow, dependency graph, deployment sequence

## Priority Under Context Pressure

If context is getting long, prioritize in this order:

Step 0 > System audit > Error/failure map > Security > Architecture > Test gaps > Everything else

Never skip Step 0, system audit, error/failure map, or security. These are the highest-leverage outputs.

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

### Option C: PR comment (for PR reviews)

Post findings directly to PR via `gh pr comment`.

## Completion Summary

```
+====================================================================+
|              PRODUCT REVIEW — COMPLETION SUMMARY                   |
+====================================================================+
| Mode selected        | EXPAND / HOLD / REDUCE                      |
| System Audit         | [key findings]                              |
| Step 0               | [mode + key decisions]                      |
| Step 1  (Arch)       | ___ issues found                            |
| Step 2  (Errors)     | ___ error paths mapped, ___ GAPS            |
| Step 3  (Security)   | ___ issues found, ___ HIGH severity         |
| Step 4  (Data/UX)    | ___ edge cases mapped, ___ unhandled        |
| Step 5  (Quality)    | ___ issues found                            |
| Step 6  (Tests)      | ___ gaps found                              |
| Step 7  (Perf)       | ___ issues found                            |
| Step 8  (Observ)     | ___ gaps found                              |
| Step 9  (Deploy)     | ___ risks flagged                           |
| Step 10 (Future)     | Reversibility: _/5, debt items: ___         |
+--------------------------------------------------------------------+
| NOT in scope         | written (___ items)                          |
| What already exists  | written                                     |
| Dream state delta    | written (EXPAND only)                       |
| Failure modes        | ___ total, ___ CRITICAL GAPS                |
| Error map            | ___ methods, ___ CRITICAL GAPS              |
| Delight opportunities| ___ identified (EXPAND only)                |
| Diagrams produced    | ___ (list types)                            |
| Taste calibration    | ___ good patterns, ___ anti-patterns        |
| Unresolved decisions | ___ (listed below)                          |
+====================================================================+
```

### Unresolved Decisions

If any AskUserQuestion goes unanswered, note it here. Never silently default.

## Next Steps

Use **AskUserQuestion tool** to present:

**Question:** "Product review complete. What would you like to do next?"

**Options:**
1. **Run `/triage`** — Triage findings into actionable todos
2. **Run `/workflows:review`** — Follow up with code-level multi-agent review
3. **Revise the plan** — Update spec.md/prd.json based on findings
4. **Run `/resolve-todo-parallel`** — Address approved findings in parallel
5. **Done** — Review complete, proceed with implementation
