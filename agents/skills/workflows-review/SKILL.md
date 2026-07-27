---
name: workflows-review
description: >
  Exhaustive multi-agent code review with dynamic agent/skill discovery,
  stakeholder and scenario passes, and todo/prd output. Use for large or
  high-risk PRs, after implementation in the workflows-* pipeline, or when
  code-review mode full hands off. Not for everyday ship gates — use
  code-review closeout for that.
---

# Workflows review (exhaustive)

## When to use this vs `code-review`

| Need | Use |
|------|-----|
| Ship/commit gate, P0/P1, often | **`code-review` closeout** (default) |
| Standards vs Spec only | **`code-review` axes** |
| Full agent bench, P1–P3, todos/prd | **This skill** (`workflows-review`) |

This skill is expensive by design. Prefer `code-review` closeout unless risk,
size, or the user asks for exhaustive review.

**Shared closeout contract:** still apply
[`code-review/closeout.md`](../code-review/closeout.md) for scope governor,
two-cycle pause, advisory findings, no push-to-review, and model/harness
rules. This skill adds breadth; it does not cancel the governor.

## Runtime Tools

When this skill needs user questions, todo/progress tracking, subagents, or another skill, use the active runtime equivalents in [RUNTIME_TOOLS.md](../RUNTIME_TOOLS.md).


Adhere to the Builder Ethos (ETHOS.md): Boil the Lake, Search Before Building, User Sovereignty.

Perform exhaustive code reviews using multi-agent analysis, dynamic skill/agent discovery, and optional prd.json integration.

## Models (from shared AGENTS.md)

Follow **Models for Workflows and Subagents → Review routing** in the shared
agent instructions. This skill is the exhaustive multi-agent path.

| Role | Model | Effort | Notes |
|------|-------|--------|-------|
| Orchestrator / synthesizer (you) | **fable-5** preferred, else **sonnet-5** | high | One gate. You rank severity and write the report. |
| Core taste / security / architecture agents | **fable-5** when spawn allows model override | high | security-sentinel, architecture-strategist, code-simplicity-reviewer, kieran-typescript-reviewer, design reviewers |
| Pure gatherers (history, file lists) | inherit or **sonnet-5** | med | git-history-analyzer, repo-research-analyst |
| Independent second opinion (optional) | **gpt-5.6-sol** | high | After synthesis: `codex review --base <base>` or `codex exec -s read-only` — do not re-run the full agent fan-out |
| UI skill slices | **fable-5** or **opus-4.8** | med / high | emil-design-engineering, web-design-guidelines, etc. |
| Post-review fixes | **grok-4.5** default implementer | high | Escalate Sol if Grok misses; UI polish → Fable/Opus |

**Hard rules:**

1. **Never nest Fable under Fable.** Specialists return findings only; they do
   not launch their own Fable subagents or re-enter this skill.
2. **One synthesizer.** You (or a single Fable manager) produce the final
   P1/P2/P3 report. Do not ask every specialist to also produce a full ship
   decision.
3. **Claude model params only accept Claude ids.** Sol and Grok run via CLI
   harnesses (`codex`, `grok`), never as invented Claude model names.
4. **Verify before block.** Cite file:line and confirm the path still exists
   before marking P1.
5. **Closeout severity:** P1 blocks merge; P2 should fix; P3 optional. Prefer
   fewer high-signal P1s over a wall of nits unless the user asked for depth.

## Prerequisites

- Git repository with GitHub CLI (`gh`) installed and authenticated
- Clean main/master branch
- Proper permissions to create worktrees and access the repository

## Review Target

<review_target> $ARGUMENTS </review_target>

## Workflow

### 1. Determine Review Target & Setup

**Target Detection:**

| Input | Type | Action |
|-------|------|--------|
| Numeric (e.g., `123`) | PR number | `gh pr view 123 --json` |
| GitHub URL | PR URL | Extract PR number, fetch metadata |
| `docs/plans/*/` path | Plan folder | Review against prd.json stories |
| Branch name | Branch | Checkout or worktree |
| Empty | Current branch | Review current branch changes |

**Setup Tasks:**

- [ ] Detect review target type
- [ ] Check current git branch
- [ ] If on target branch → proceed with analysis
- [ ] If different branch → offer worktree: `git worktree add ../<branch> <branch>` (use absolute paths after)
- [ ] Fetch PR metadata: `gh pr view --json title,body,files,baseRefName`
- [ ] If plan folder provided → read prd.json for story context

### 2. Discover & Launch ALL Review Agents

You MUST discover and run agents. This is not optional. Do not skip agents. Do not rationalize running fewer agents.

**Discover Review Agents:**

```bash
# Core and auxiliary agents by runtime
find ~/.claude/agents -name "*.md" 2>/dev/null
find ~/.codex/agents -name "*.toml" 2>/dev/null
find ~/.config/opencode/agents -name "*.md" 2>/dev/null

# Plugin agents when exposed by the active agent runtime
find ~/.codex/plugins ~/.claude/plugins ~/.config/opencode/plugins -path "*/agents/*" 2>/dev/null
```

**Extract agent metadata:**

```bash
for agent in $(find ~/.claude/agents ~/.codex/agents ~/.config/opencode/agents ~/.codex/plugins ~/.claude/plugins ~/.config/opencode/plugins -path "*/agents/*" 2>/dev/null); do
  name=$(sed -n '/^---$/,/^---$/p' "$agent" | grep "^name:" | cut -d: -f2- | xargs)
  [ -z "$name" ] && name=$(grep '^name = ' "$agent" | cut -d= -f2- | tr -d '" ' | xargs)
  category=$(dirname "$agent" | xargs basename)
  echo "AGENT|$name|$category"
done
```

**Agent sources:**

| Source | Agents | Purpose |
|--------|--------|---------|
| Active runtime user agents | security-sentinel, performance-oracle, architecture-strategist, code-simplicity-reviewer, kieran-typescript-reviewer, pattern-recognition-specialist | Core review |
| Active runtime user agents | design-implementation-reviewer, figma-design-sync | UI review |
| Active runtime user agents | git-history-analyzer | Historical context |
| pr-review-toolkit plugin | code-reviewer, silent-failure-hunter, type-design-analyzer, pr-test-analyzer, comment-analyzer | PR-specific review |
| pr-review-toolkit plugin | code-simplifier | Active code simplification |
| code-review plugin | code-review | Active code review |

**Simplification Agents - Different Roles:**

| Agent | Type | When to Use |
|-------|------|-------------|
| `code-simplicity-reviewer` | Audit | Identifies complexity issues, flags for review |
| `code-simplifier` | Refactor | Actively simplifies code, applies changes |

Use `code-simplicity-reviewer` during review phase, `code-simplifier` after implementation for cleanup.

**Discover Relevant Skills:**

```bash
find ~/.agents/skills -name "SKILL.md" 2>/dev/null
find ~/.codex/plugins ~/.claude/plugins ~/.config/opencode/plugins -path "*/skills/*/SKILL.md" 2>/dev/null
```

**Skill Categories for Reviews:**

| Skill | Use When PR Contains |
|-------|---------------------|
| `vercel-react-best-practices` | React, Next.js components |
| `vercel-composition-patterns` | Component architecture |
| `emil-design-engineering` | UI, forms, accessibility |
| `web-animation-design` | Animations, transitions |
| `web-design-guidelines` | UX, accessibility |
| `stripe-best-practices` | Payment code |

**Core Review Agents (always run):**

When the runtime supports model overrides on Agent/subagent calls, set
**`model: fable-5`** (high effort) for security, architecture, simplicity, and
TypeScript/quality reviewers. Pattern/history gatherers may inherit. Pass
explicit instruction: report findings only; do not spawn further subagents.

- Launch subagent `security-sentinel` with prompt ("Review these changed files for security vulnerabilities: <changed_files>. Return findings only; do not spawn subagents.")
- Launch subagent `performance-oracle` with prompt ("Review these changed files for performance issues: <changed_files>. Return findings only; do not spawn subagents.")
- Launch subagent `architecture-strategist` with prompt ("Review these changed files for architectural concerns: <changed_files>. Return findings only; do not spawn subagents.")
- Launch subagent `code-simplicity-reviewer` with prompt ("Review these changed files for unnecessary complexity: <changed_files>. Return findings only; do not spawn subagents.")
- Launch subagent `pattern-recognition-specialist` with prompt ("Review these changed files for anti-patterns: <changed_files>. Return findings only; do not spawn subagents.")
- Launch subagent `code-reviewer` with prompt ("Review these changed files for code quality issues: <changed_files>. Return findings only; do not spawn subagents.")

Every single one. No exceptions.

**Conditional Agents:**

| Condition | Agent | Source |
|-----------|-------|--------|
| TypeScript files | `kieran-typescript-reviewer` | active runtime user agents |
| UI components | `design-implementation-reviewer` | active runtime user agents |
| New types defined | `type-design-analyzer` | pr-review-toolkit plugin |
| Error handling code | `silent-failure-hunter` | pr-review-toolkit plugin |
| Test files | `pr-test-analyzer` | pr-review-toolkit plugin |
| Comments added | `comment-analyzer` | pr-review-toolkit plugin |
| Plan folder has breadboard | `breadboard-reflection` | skill |

If a conditional agent's trigger exists in the changeset, you MUST launch it. Do not skip.

**Breadboard-Reflection Agent (when plan folder has breadboard):**

Load the `/breadboard-reflection` skill and run these checks against the implementation:
- Trace user stories through implementation code
- Run naming test: can each function be named with one idiomatic verb?
- Check for wiring mismatches: does code call chain match breadboard Wires Out?
- Check for stale affordances: breadboard shows something that doesn't exist in code
- Check for missing affordances: code has paths not in the breadboard

**Research Agent:**

```
Launch subagent `git-history-analyzer`: "Analyze historical context for changed files"
```

### 3. Wait for ALL agents, then proceed

Do NOT move to the next step until every launched agent has returned findings. Collect all results before synthesizing.

### 4. Apply Relevant Skills

**For React/Next.js PRs:**
```
skill: vercel-react-best-practices
skill: vercel-composition-patterns
```

**For UI PRs:**
```
skill: emil-design-engineering
skill: web-animation-design
skill: web-design-guidelines
```

**UI Review Checklist (from emil-design-engineering):**

- [ ] No layout shift on dynamic content
- [ ] Animations have `prefers-reduced-motion` support
- [ ] Touch targets 44px minimum
- [ ] Hover effects use `@media (hover: hover)`
- [ ] Icon buttons have aria labels
- [ ] Inputs 16px+ (prevent iOS zoom)
- [ ] No `transition: all`
- [ ] z-index uses fixed scale

### 5. Stakeholder Perspective Analysis

**Developer Perspective:**
- How easy is this to understand and modify?
- Are the APIs intuitive?
- Is debugging straightforward?
- Can I test this easily?

**Operations Perspective:**
- How do I deploy this safely?
- What metrics and logs are available?
- How do I troubleshoot issues?
- What are the resource requirements?

**End User Perspective:**
- Is the feature intuitive?
- Are error messages helpful?
- Is performance acceptable?
- Does it solve the problem?

**Security Perspective:**
- What's the attack surface?
- Are there compliance requirements?
- How is data protected?
- What are the audit capabilities?

### 6. Scenario Exploration

**Scenario Checklist:**

- [ ] **Happy Path**: Normal operation with valid inputs
- [ ] **Invalid Inputs**: Null, empty, malformed data
- [ ] **Boundary Conditions**: Min/max values, empty collections
- [ ] **Concurrent Access**: Race conditions, deadlocks
- [ ] **Scale Testing**: 10x, 100x, 1000x normal load
- [ ] **Network Issues**: Timeouts, partial failures
- [ ] **Resource Exhaustion**: Memory, disk, connections
- [ ] **Security Attacks**: Injection, overflow, DoS
- [ ] **Data Corruption**: Partial writes, inconsistency
- [ ] **Cascading Failures**: Downstream service issues

### 7. Synthesize Findings

**Synthesis Tasks:**

- [ ] Collect findings from all parallel agents
- [ ] Categorize by type: security, performance, architecture, quality
- [ ] Assign severity: P1 (Critical), P2 (Important), P3 (Nice-to-have)
- [ ] Remove duplicate or overlapping findings
- [ ] Estimate effort: Small/Medium/Large

**Severity Definitions:**

| Level | Name | Description | Examples |
|-------|------|-------------|----------|
| P1 | Critical | Blocks merge | Security vulnerabilities, data corruption, breaking changes |
| P2 | Important | Should fix | Performance issues, architectural concerns, reliability |
| P3 | Nice-to-have | Enhancements | Code cleanup, minor improvements, docs |

### 8. Output Findings

Choose output format based on review target:

#### Option A: Update prd.json (if plan folder provided)

If reviewing against a plan folder with prd.json:

```json
{
  "stories": [
    {
      "id": 1,
      "title": "...",
      "review_findings": [
        {
          "severity": "P1",
          "category": "security",
          "agent": "security-sentinel",
          "finding": "SQL injection risk in user input",
          "file": "src/api/users.ts:42",
          "suggestion": "Use parameterized queries"
        }
      ]
    }
  ],
  "log": [
    {
      "timestamp": "2026-02-03T12:00:00Z",
      "action": "review",
      "agents": ["security-sentinel", "performance-oracle", ...],
      "findings_count": { "P1": 2, "P2": 5, "P3": 3 }
    }
  ]
}
```

#### Option B: Create file-todos (default for PR reviews)

Use file-todos skill for structured todo management:

```
skill: file-todos
```

**File naming:**
```
{id}-pending-{priority}-{description}.md

Examples:
001-pending-p1-sql-injection-vulnerability.md
002-pending-p2-n-plus-one-query.md
003-pending-p3-unused-import.md
```

**Todo structure:**
- YAML frontmatter: status, priority, issue_id, tags
- Problem Statement: What's wrong, why it matters
- Findings: Evidence from agents with file:line
- Proposed Solutions: 2-3 options with pros/cons
- Acceptance Criteria: Testable checklist

### 9. Summary Report

```markdown
## Review Complete

**Target:** PR #XXX - [Title]
**Branch:** [branch-name]

### Findings Summary

| Severity | Count | Status |
|----------|-------|--------|
| P1 Critical | X | BLOCKS MERGE |
| P2 Important | X | Should fix |
| P3 Nice-to-have | X | Optional |

### Agents Used

**From active runtime user agents:**
- [dynamically list agents that ran]

**From plugins:**
- [dynamically list plugin agents that ran]

### Skills Applied

- [dynamically list skills that were loaded]

### Output

- [ ] prd.json updated with review_findings (if plan folder)
- [ ] Todo files created in todos/ (if PR review)
- [ ] PR comments posted (if requested)

### Next Steps

**If P1 findings exist:**
1. Address all P1 issues before merge
2. Re-run review after fixes

**For all findings:**
1. Triage: `/triage`
2. Fix, validate, ship: `/workflows-finalize`
3. Track progress in todo files or prd.json
```

## Discovery Reference

### Agent Paths

```
~/.claude/agents/*.md
~/.codex/agents/*.toml
~/.config/opencode/agents/*.md
runtime plugin agent paths when exposed
```

### Skill Paths

```
~/.agents/skills/*/SKILL.md
runtime plugin skill paths when exposed
```

### Integration with workflows

When reviewing a plan folder:
1. Read prd.json stories
2. Map findings to specific stories
3. Update story with `review_findings` array
4. Add review event to log
5. `/workflows-work` can then address findings per-story
6. `/workflows-finalize` can fix, validate, and ship
