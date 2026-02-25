---
name: workflows:work
description: Execute work plans efficiently while maintaining quality and finishing features
argument-hint: "[plan folder path, e.g., docs/plans/2026-01-30-feat-user-auth/] [--swarm]"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Task", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "Skill", "AskUserQuestion"]
---

# Work Plan Execution Command

Execute a work plan efficiently while maintaining quality and finishing features.

## Introduction

This command takes a plan folder (containing spec.md and prd.json) and executes stories systematically. The focus is on **shipping complete features** by following the PRD story breakdown, respecting dependencies, and maintaining quality throughout.

## Input

<input> #$ARGUMENTS </input>

**Parse input:** Split arguments into `<path>` and optional flags (`--swarm`).

**If the path is empty, ask the user:** "Which plan would you like to work on? Provide the folder path (e.g., `docs/plans/2026-01-30-feat-user-auth/`)."

**If input is a folder:** Look for prd.json insides
**If input is a file:** Check if it's prd.json or spec.md, find sibling files

## Execution Workflow

### Phase 1: Load Plan

#### 1.1 Read Plan Files

```bash
# List plan folder contents
ls -la <input_path>/
```

Read both files:
- `spec.md` - For context, rationale, technical approach
- `prd.json` - For executable stories

**If prd.json doesn't exist:**
- Fall back to legacy mode (use spec.md + TodoWrite)
- Suggest running `/workflows:plan` to generate prd.json

#### 1.2 Parse PRD and Normalize Schema

PRDs come in two variants. Detect and normalize before proceeding:

**Schema detection:**
```
If stories[0] has "passes" field (boolean):
  → Lightweight schema: passes=true means completed, passes=false means pending
  → depends_on may be missing (default to [])
  → acceptance_criteria may be missing (fall back to steps[])
  → log/completed_at/commit may be missing (initialize as needed)

If stories[0] has "status" field (string):
  → Full schema from /workflows:plan — use as-is
```

**Normalize each story to working state:**
```
For each story:
  story._effective_status =
    if story.status exists → story.status
    else if story.passes === true → "completed"
    else → "pending"

  story._effective_deps = story.depends_on ?? []
  story._effective_criteria = story.acceptance_criteria ?? story.steps ?? []
```

**Display current state:**
```
Plan: [title]
Stories: [total] ([pending] pending, [in_progress] in progress, [completed] completed)

Next stories ready to execute:
  #[id] [title] (priority: [priority])
  #[id] [title] (priority: [priority])

Blocked stories:
  #[id] [title] - blocked by #[depends_on]
```

**Initialize log if missing:**
If prd.json has no top-level `log` array, treat it as `[]`. Only append log entries if the PRD already has one (don't bloat lightweight PRDs).

#### 1.3 Sync Stories to Task System

Create a TaskCreate entry for **every** story in prd.json (mirrors full state to Ctrl+T):

```
For each story in prd.json.stories:
  TaskCreate({
    subject: "Story #[id]: [title]",
    description: "[category] | Priority: [priority]\n\nSteps:\n- [step1]\n- [step2]...\n\nAcceptance Criteria:\n- [criteria]",
    activeForm: "Implementing story #[id]: [title]",
    metadata: { story_id: [id], prd_path: "[path/to/prd.json]", category: "[category]" }
  })
```

**After creating all tasks, set up dependencies:**
```
For each story with depends_on:
  TaskUpdate({
    taskId: "[task_id]",
    addBlockedBy: [task_ids of depends_on stories]
  })
```

**For already-completed stories** (resuming a partial run):
```
If story._effective_status === "completed":
  TaskUpdate({ taskId: "[task_id]", status: "completed" })
```

Store the story_id → task_id mapping for use during execution.

#### 1.4 Clarify and Confirm

- Review spec.md for context and technical approach
- Read any referenced files from the spec
- If anything is unclear or ambiguous, ask clarifying questions now
- Get user approval to proceed
- **Do not skip this** - better to ask questions now than build wrong thing

### Phase 2: Setup Environment

#### 2.1 Validate Expected Branch

Check if prd.json specifies a branch:

```bash
expected_branch=$(cat <input_path>/prd.json | jq -r '.branch // empty')
current_branch=$(git branch --show-current)
```

**If prd.json has a `branch` field:**

| Current State | Action |
|---------------|--------|
| `current_branch === expected_branch` | Proceed to Phase 3 |
| `expected_branch` exists locally | Ask: "Switch to `[expected_branch]`?" then `git checkout [expected_branch]` |
| `expected_branch` doesn't exist | Create it: `git checkout -b [expected_branch]` |

**If branch mismatch and user declines to switch:**
- Warn: "Continuing on `[current_branch]` but prd.json expects `[expected_branch]`. Commits may not align with plan."
- Proceed only with explicit confirmation

#### 2.2 Branch Fallback (No branch in prd.json)

If prd.json has no `branch` field, fall back to legacy behavior:

```bash
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

# Fallback if remote HEAD isn't set
if [ -z "$default_branch" ]; then
  default_branch=$(git rev-parse --verify origin/main >/dev/null 2>&1 && echo "main" || echo "master")
fi
```

**If already on a feature branch** (not the default branch):
- Ask: "Continue working on `[current_branch]`, or create a new branch?"
- If continuing, proceed to Phase 3
- If creating new, follow Option A or B below

**If on the default branch**, choose how to proceed:

**Option A: Create a new branch**
```bash
git pull origin [default_branch]
git checkout -b feature-branch-name
```
Use a meaningful name based on the work (e.g., `feat/user-authentication`, `fix/email-validation`).

**Option B: Use a worktree (recommended for parallel development)**
```bash
gwt new feature-branch-name
# Creates worktree in ~/code/worktrees/{repo}--{branch}, copies .env files
# Use absolute paths for all subsequent commands: cd $(gwt go feature-branch-name) && ...
```

**Option C: Continue on the default branch**
- Requires explicit user confirmation
- Only proceed after user explicitly says "yes, commit to [default_branch]"
- Never commit directly to the default branch without explicit permission

### Phase 3: Execute Stories

#### 3.1 Story Selection

Get next executable story (using normalized fields from Phase 1.2):
1. Filter stories where `_effective_status === "pending"`
2. Filter stories where all `_effective_deps` story IDs have `_effective_status === "completed"`
3. Sort by `priority` ascending
4. Take first story

If no stories are ready but some are blocked, report the blockers.

#### 3.2 Story Execution Loop

```
while (executable stories remain):

  1. SELECT next story (lowest priority, unblocked)

  2. UPDATE prd.json + Task system:
     - If full schema (has "status" field): set story.status = "in_progress"
     - If lightweight schema (has "passes" field): no prd.json change (passes is boolean, no "in_progress" equivalent)
     - If prd.json has "log" array: append { timestamp, story_id, action: "status_change", from: "pending", to: "in_progress" }
     - TaskUpdate({ taskId: "[mapped_task_id]", status: "in_progress" })

  3. ANNOUNCE to user:
     "Starting story #[id]: [title]"
     Display acceptance criteria

  4. LOAD relevant skills (MANDATORY if story.skills is non-empty):
     ```
     For each skill_name in story.skills:
       skill: [skill_name]
     ```
     This calls the Skill tool for each entry. Do NOT skip — skills provide
     critical implementation guidance (design systems, framework patterns, etc).

  5. IMPLEMENT:
     - Read referenced files from spec.md
     - Look for similar patterns in codebase
     - Follow existing conventions
     - Write tests for new functionality
     - Run tests after changes

  6. VERIFY acceptance criteria:
     - Check each criterion is satisfied
     - Run relevant tests
     - If UI work, verify against design

  7. RUN validation agents:
     - **For stories with code changes** (new/modified source files beyond prd.json):
       - **Always run** these default agents in parallel:
         ```
         Task code-reviewer: "Review implementation of story #[id]: [title]"
         Task code-simplifier: "Review implementation of story #[id]: [title]"
         ```
       - **Additionally run** any agents from story.validation_agents array (if present)
       - Do NOT skip this step for code stories.
     - **For operational stories** (deploys, verifications, config-only — no source code changes beyond prd.json):
       - Skip default code-reviewer/code-simplifier (nothing meaningful to review)
       - Still run any story-specific validation_agents if present

  7a. HANDLE validation findings:

     **If findings exist:**
     - Log findings to prd.json story.review_findings[]
     - Categorize by severity: P1 (critical), P2 (important), P3 (minor)

     **For P1 (critical) findings:**
     - MUST fix before proceeding
     - Re-run validation after fix
     - Loop until P1s resolved

     **For P2 (important) findings:**
     - Fix if quick (<5 min)
     - Otherwise log to prd.json and continue
     - Address in quality check phase

     **For P3 (minor) findings:**
     - Log to prd.json
     - Continue (address later or ignore)

     **Update prd.json:**
     ```json
     {
       "review_findings": [
         {
           "severity": "P2",
           "agent": "security-sentinel",
           "finding": "Input not sanitized",
           "file": "src/api/users.ts:42",
           "status": "logged",
           "resolved_at": null
         }
       ]
     }
     ```

  8. COMMIT (MANDATORY per story — every completed story gets its own commit):
     - Do NOT defer or batch commits. Each story = one commit.
     - Only exception: unresolved P1 findings from step 7a (fix first, then commit).
     - **Operational stories** (deploys, verifications) still produce a committable artifact: the prd.json status update. "No source code changes" is never a reason to skip — prd.json IS the change.
     ```bash
     git add <files for this story>
     git commit -m "type(scope): [story title]"
     ```
     Capture commit SHA

  9. UPDATE prd.json + Task system (MANDATORY — ALWAYS runs after commit):
     - This step is NOT optional. Every completed story must be marked done immediately.
     - Update prd.json FIRST, then sync to Task system. Steps 8 and 9 are atomic per story — complete both before moving to the next story.
     - If full schema: set story.status = "completed", story.completed_at = ISO8601 now, story.commit = SHA
     - If lightweight schema: set story.passes = true
     - If prd.json has "log" array: append { timestamp, story_id, action: "status_change", from: "in_progress", to: "completed" }
     - TaskUpdate({ taskId: "[mapped_task_id]", status: "completed" })
     - **Verify update:** Re-read prd.json to confirm the status change persisted

  10. ANNOUNCE completion:
     "Completed story #[id]: [title]"
     Show remaining stories count
```

#### 3.3 PRD Update Format

When updating prd.json, use atomic edits. Write back in the **same schema variant** as the source:

**Full schema (from /workflows:plan):**
```json
{ "status": "in_progress" }
{ "status": "completed", "completed_at": "2026-01-30T14:30:00Z", "commit": "abc123def" }
```

**Lightweight schema (hand-written):**
```json
{ "passes": true }
```
No "in_progress" state — only flip `passes` to `true` on completion.

**Log entry (only if prd.json already has a `log` array):**
```json
{
  "timestamp": "2026-01-30T14:30:00Z",
  "story_id": 1,
  "action": "status_change",
  "from": "pending",
  "to": "in_progress"
}
```

#### 3.4 Handling Blocked Stories

If a story becomes blocked during implementation:

1. If full schema: set story.status = "blocked". If lightweight: leave passes as false (no blocked state).
2. If prd.json has "log" array: add entry explaining why
3. TaskUpdate({ taskId: "[mapped_task_id]", description: "BLOCKED: [reason]" })
4. Move to next unblocked story
5. Report to user what's blocked and why

#### 3.5 Commit Policy

**Default: One commit per completed story.** Every story that passes verification (step 6) and agent review (step 7) gets committed immediately.

| Extra commits OK when... | Do NOT commit when... |
|--------------------------|----------------------|
| Logical sub-unit complete within a large story | Story partially done |
| About to attempt risky/uncertain changes | Tests failing |
| About to switch contexts (backend → frontend) | Unresolved P1 findings |

**Heuristic:** Story done + agents passed + tests green = commit. No exceptions.

### Phase 3.5: Swarm Mode (--swarm flag)

**Only when `--swarm` is present in arguments.** Replaces the sequential loop in Phase 3.2 with parallel subagent execution.

#### When Swarm Mode Activates

| Use Swarm when... | Stay Sequential when... |
|---|---|
| 5+ independent (unblocked) stories | Linear dependency chain |
| Stories touch different parts of codebase | Stories modify same files |
| User explicitly requests `--swarm` | Simple/small plans |

#### Swarm Execution

1. **Identify independent stories** — stories with no unresolved `_effective_deps`
2. **Fan out parallel Task subagents** — one per independent story:

```
For each independent story:
  Task({
    description: "Implement story #[id]",
    subagent_type: "general-purpose",
    prompt: "You are implementing story #[id]: [title] from [prd_path].

      Context: [paste relevant spec.md sections]

      Steps:
      - [step1]
      - [step2]

      Acceptance criteria:
      - [criteria]

      Instructions:
      1. Read the codebase patterns for similar implementations
      2. Implement following existing conventions
      3. Write tests for new functionality
      4. Run tests to verify
      5. When done, report files changed and test results

      Do NOT commit. Do NOT modify prd.json. Only implement and test.",
    run_in_background: true
  })
```

3. **Monitor completion** — check each background task's output
4. **After each subagent completes:**
   - Review its output for correctness
   - Stage and commit if tests pass
   - Update prd.json (full schema: status → "completed"; lightweight: passes → true)
   - TaskUpdate({ taskId: "[mapped_task_id]", status: "completed" })
5. **Once current wave completes**, check if newly unblocked stories exist → fan out next wave
6. **Repeat** until all stories complete or only blocked stories remain

#### Swarm Safety Rules

- Subagents do NOT commit or modify prd.json — only the coordinator does
- If two stories touch overlapping files, run them sequentially, not in parallel
- If a subagent fails, log the error and fall back to sequential for that story
- Always review subagent output before committing

### Phase 4: Quality Check

1. **Run Core Quality Checks**

   ```bash
   # Run full test suite (use project's test command)
   # Examples: npm test, pnpm test, vitest, jest, etc.

   # Run linting (check package.json for lint script)
   # Examples: npm run lint, pnpm lint, eslint ., etc.
   ```

2. **Consider Additional Reviewer Agents** (for complex/risky changes)

   Note: code-reviewer and code-simplifier already ran per-story in step 7.
   These are cross-cutting agents that benefit from seeing the full changeset:

   - **performance-oracle**: Check for performance issues across stories
   - **security-sentinel**: Scan for security vulnerabilities across stories

   Run in parallel with Task tool if needed.

3. **Final Validation**
   - All prd.json stories completed (status="completed" or passes=true)
   - All tests pass
   - Linting passes
   - Code follows existing patterns
   - Figma designs match (if applicable)

### Phase 5: Ship It

1. **Final Commit** (if uncommitted changes remain)

   ```bash
   git add .
   git status  # Review what's being committed
   git diff --staged  # Check the changes

   git commit -m "$(cat <<'EOF'
   type(scope): complete [feature name]

   Implements all stories from prd.json
   EOF
   )"
   ```

2. **Update PRD Final State**

   Ensure prd.json reflects:
   - All stories completed (status="completed" or passes=true)
   - Full schema: commits recorded, log has execution history
   - Lightweight schema: all passes=true is sufficient

3. **Notify User**
   - Summarize what was completed
   - Show prd.json final state
   - Note any follow-up work needed
   - Suggest creating PR

## PRD State Management

### Reading Current State

```bash
# Full schema — get story statuses
cat <prd_path> | jq '.stories[] | {id, title, status, priority}'

# Lightweight schema — get story pass/fail
cat <prd_path> | jq '.stories[] | {id, title, passes, priority}'

# Get blocked stories (works for both — depends_on may not exist)
cat <prd_path> | jq '.stories[] | select(.status == "pending" or .passes == false) | select((.depends_on // []) | length > 0)'

# Get execution log (may not exist in lightweight PRDs)
cat <prd_path> | jq '.log // empty'
```

### Status Transitions

**Full schema** (has `status` string):
```
pending → in_progress → completed
                ↓
             blocked → in_progress → completed
```

**Lightweight schema** (has `passes` boolean):
```
passes: false → passes: true
```
No intermediate states. The Task system (Ctrl+T) tracks in_progress/blocked for lightweight PRDs.

### Skills Integration

Stories may include a `skills` array in prd.json:

```json
"skills": ["frontend-design", "vercel-react-best-practices"]
```

These are loaded via the Skill tool in Phase 3, Step 4 — one `skill: [name]` call per entry.
This is mandatory and must happen before implementation begins.

This provides relevant guidance for the implementation.

## Legacy Mode (No prd.json)

If the input doesn't have prd.json:

1. Read spec.md or plan file
2. Use TodoWrite to break into tasks
3. Execute using TodoWrite tracking
4. Suggest running `/workflows:plan` to generate prd.json for future work

## Key Principles

### prd.json is Source of Truth, Tasks are the View Layer
- **prd.json** is the authoritative state — it persists across sessions, has full history
- **Task system** (Ctrl+T) is the live visibility layer — shows progress, enables swarm
- Always update prd.json FIRST, then sync to Task system
- If they diverge, prd.json wins

### Start Fast, Execute Faster
- Get clarification once at start, then execute
- The goal is to **finish the feature**, not create perfect process

### The PRD is Your Guide
- Stories are pre-broken-down and prioritized
- Dependencies are explicit - respect them
- Acceptance criteria define done

### Test As You Go
- Run tests after each story
- Fix failures immediately
- Don't batch testing to the end

### Track Everything
- PRD status updates provide audit trail
- Log entries capture execution history
- Commits tied to stories for traceability

### Ship Complete Features
- All stories completed before moving on
- Don't leave features 80% done
- A finished feature that ships beats a perfect feature that doesn't

## Quality Checklist

- [ ] Current branch matches prd.json `branch` field
- [ ] All prd.json stories completed (status="completed" or passes=true)
- [ ] All acceptance criteria verified
- [ ] Tests pass
- [ ] Linting passes
- [ ] Code follows existing patterns
- [ ] Commits follow conventional format
- [ ] Full schema: prd.json has complete execution log

## Common Pitfalls

- **Working on wrong branch** - Always verify current branch matches prd.json `branch` field
- **Skipping clarifying questions** - Ask at start, not after building wrong thing
- **Ignoring dependencies** - Don't start blocked stories
- **Not updating prd.json** - Track progress or lose state
- **Testing at the end** - Test per-story
- **80% done syndrome** - Finish all stories
- **Skipping commits on operational stories** - Deploys and verifications still change prd.json. Commit it. Steps 8+9 are atomic per story — never batch across stories.
