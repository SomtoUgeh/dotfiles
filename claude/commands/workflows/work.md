---
name: workflows:work
description: Execute work plans efficiently while maintaining quality and finishing features
argument-hint: "[plan folder path, e.g., docs/plans/2026-01-30-feat-user-auth/]"
---

# Work Plan Execution Command

Execute a work plan efficiently while maintaining quality and finishing features.

## Introduction

This command takes a plan folder (containing spec.md and prd.json) and executes stories systematically. The focus is on **shipping complete features** by following the PRD story breakdown, respecting dependencies, and maintaining quality throughout.

## Input

<input_path> #$ARGUMENTS </input_path>

**If the input path is empty, ask the user:** "Which plan would you like to work on? Provide the folder path (e.g., `docs/plans/2026-01-30-feat-user-auth/`)."

**If input is a folder:** Look for prd.json inside
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

#### 1.2 Parse PRD and Display Summary

Read prd.json and display current state:

```
Plan: [title]
Stories: [total] ([pending] pending, [in_progress] in progress, [completed] completed)

Next stories ready to execute:
  #[id] [title] (priority: [priority])
  #[id] [title] (priority: [priority])

Blocked stories:
  #[id] [title] - blocked by #[depends_on]
```

#### 1.3 Clarify and Confirm

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
skill: git-worktree
# The skill will create a new branch from the default branch in an isolated worktree
```

**Option C: Continue on the default branch**
- Requires explicit user confirmation
- Only proceed after user explicitly says "yes, commit to [default_branch]"
- Never commit directly to the default branch without explicit permission

### Phase 3: Execute Stories

#### 3.1 Story Selection

Get next executable story:
1. Filter stories where `status === "pending"`
2. Filter stories where all `depends_on` IDs have `status === "completed"`
3. Sort by `priority` ascending
4. Take first story

If no stories are ready but some are blocked, report the blockers.

#### 3.2 Story Execution Loop

```
while (executable stories remain):

  1. SELECT next story (lowest priority, unblocked)

  2. UPDATE prd.json:
     - Set status: "in_progress"
     - Add log entry: { timestamp, story_id, action: "status_change", from: "pending", to: "in_progress" }

  3. ANNOUNCE to user:
     "Starting story #[id]: [title]"
     Display acceptance criteria

  4. LOAD relevant skills:
     - Check story.skills array
     - Load each skill for implementation guidance

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

  7. RUN validation agents (if any):
     - Check story.validation_agents array
     - Run each agent in parallel:
       ```
       Task [agent-name]: "Review implementation of story #[id]: [title]"
       ```

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

  8. COMMIT (if logical unit complete AND no unresolved P1s):
     ```bash
     git add <files for this story>
     git commit -m "type(scope): [story title]"
     ```
     Capture commit SHA

  9. UPDATE prd.json:
     - Set status: "completed"
     - Set completed_at: current ISO8601 timestamp
     - Set commit: SHA from step 8 (or null if part of larger commit)
     - Add log entry: { timestamp, story_id, action: "status_change", from: "in_progress", to: "completed" }

  10. ANNOUNCE completion:
     "Completed story #[id]: [title]"
     Show remaining stories count
```

#### 3.3 PRD Update Format

When updating prd.json, use atomic edits:

**Status change:**
```json
{
  "status": "in_progress"
}
```

**Completion:**
```json
{
  "status": "completed",
  "completed_at": "2026-01-30T14:30:00Z",
  "commit": "abc123def"
}
```

**Log entry:**
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

1. Update status to "blocked"
2. Add log entry explaining why
3. Move to next unblocked story
4. Report to user what's blocked and why

#### 3.5 Incremental Commits

| Commit when... | Don't commit when... |
|----------------|---------------------|
| Story complete with passing tests | Story partially done |
| Logical unit complete (model, service, component) | Tests failing |
| About to switch contexts (backend → frontend) | Would need "WIP" message |
| About to attempt risky/uncertain changes | Purely scaffolding |

**Heuristic:** "Can I write a commit message describing a complete, valuable change? If yes, commit."

### Phase 4: Quality Check

1. **Run Core Quality Checks**

   ```bash
   # Run full test suite (use project's test command)
   # Examples: npm test, pnpm test, vitest, jest, etc.

   # Run linting (check package.json for lint script)
   # Examples: npm run lint, pnpm lint, eslint ., etc.
   ```

2. **Consider Reviewer Agents** (for complex/risky changes)

   - **code-simplicity-reviewer**: Check for unnecessary complexity
   - **performance-oracle**: Check for performance issues
   - **security-sentinel**: Scan for security vulnerabilities

   Run in parallel with Task tool if needed.

3. **Final Validation**
   - All prd.json stories have status "completed"
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
   - All stories completed
   - All commits recorded
   - Log has full execution history

3. **Notify User**
   - Summarize what was completed
   - Show prd.json final state
   - Note any follow-up work needed
   - Suggest creating PR

## PRD State Management

### Reading Current State

```bash
# Get story statuses
cat docs/plans/<folder>/prd.json | jq '.stories[] | {id, title, status, priority}'

# Get blocked stories
cat docs/plans/<folder>/prd.json | jq '.stories[] | select(.status == "pending") | select(.depends_on | length > 0)'

# Get execution log
cat docs/plans/<folder>/prd.json | jq '.log'
```

### Status Transitions

```
pending → in_progress → completed
                ↓
             blocked → in_progress → completed
```

Valid transitions:
- `pending` → `in_progress` (starting work)
- `in_progress` → `completed` (finished)
- `in_progress` → `blocked` (hit blocker)
- `blocked` → `in_progress` (blocker resolved)

### Skills Integration

When a story has skills listed:

```json
"skills": ["frontend-design", "vercel-react-best-practices"]
```

Load those skills before implementation:
```
skill: frontend-design
skill: vercel-react-best-practices
```

This provides relevant guidance for the implementation.

## Legacy Mode (No prd.json)

If the input doesn't have prd.json:

1. Read spec.md or plan file
2. Use TodoWrite to break into tasks
3. Execute using TodoWrite tracking
4. Suggest running `/workflows:plan` to generate prd.json for future work

## Key Principles

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

Before creating PR:

- [ ] Current branch matches prd.json `branch` field
- [ ] All prd.json stories have status "completed"
- [ ] All acceptance criteria verified
- [ ] Tests pass
- [ ] Linting passes
- [ ] Code follows existing patterns
- [ ] Commits follow conventional format
- [ ] prd.json has complete execution log

## Common Pitfalls

- **Working on wrong branch** - Always verify current branch matches prd.json `branch` field
- **Skipping clarifying questions** - Ask at start, not after building wrong thing
- **Ignoring dependencies** - Don't start blocked stories
- **Not updating prd.json** - Track progress or lose state
- **Testing at the end** - Test per-story
- **80% done syndrome** - Finish all stories
