---
name: workflows:review
description: Perform exhaustive code reviews using multi-agent analysis and dynamic skill discovery
argument-hint: "[PR number, GitHub URL, branch name, or plan folder path]"
---

# Review Command

Perform exhaustive code reviews using multi-agent analysis, dynamic skill/agent discovery, and optional prd.json integration.

## Prerequisites

- Git repository with GitHub CLI (`gh`) installed and authenticated
- Clean main/master branch
- Proper permissions to create worktrees and access the repository

## Review Target

<review_target> #$ARGUMENTS </review_target>

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
- [ ] If different branch → offer worktree: `gwt new <branch>` (use absolute paths after)
- [ ] Fetch PR metadata: `gh pr view --json title,body,files,baseRefName`
- [ ] If plan folder provided → read prd.json for story context

### 1b. Deslop Pre-pass

Run `/deslop` against the changed files. This removes unnecessary comments, defensive over-engineering, type hacks, style inconsistencies, and over-abstraction.

- If reviewing a PR/branch: deslop all changed files
- If reviewing a plan folder: skip (no code to deslop)

If deslop makes changes, note them before proceeding:

```markdown
**Deslop pre-pass:** [summary of what was cleaned]
```

If no slop found, proceed silently.

### 1c. Simplify Pass

Run `/simplify` on the changed files. This catches different issues than deslop:
- **Deslop** removes AI slop (comments, defensive code, type hacks)
- **Simplify** reviews for reuse, quality, and efficiency — then fixes

```
skill: simplify
```

- If reviewing a PR/branch: simplify all changed files
- If reviewing a plan folder: skip (no code to simplify)

If simplify makes changes, note them:

```markdown
**Simplify pass:** [summary of what was improved]
```

If no improvements found, proceed silently.

### 2. Discover & Launch ALL Review Agents

You MUST discover and run agents. This is not optional. Do not skip agents. Do not rationalize running fewer agents.

**Discover Review Agents:**

```bash
# Core and auxiliary agents
find ~/.claude/agents/review -name "*.md" 2>/dev/null

# Plugin agents (pr-review-toolkit and others)
find ~/.claude/plugins -path "*/agents/*.md" 2>/dev/null
```

**Extract agent metadata:**

```bash
for agent in $(find ~/.claude/agents ~/.claude/plugins -path "*/agents/*.md" 2>/dev/null); do
  name=$(sed -n '/^---$/,/^---$/p' "$agent" | grep "^name:" | cut -d: -f2- | xargs)
  category=$(dirname "$agent" | xargs basename)
  echo "AGENT|$name|$category"
done
```

**Agent sources:**

| Source | Agents | Purpose |
|--------|--------|---------|
| `~/.claude/agents/review/` | security-sentinel, performance-oracle, architecture-strategist, code-simplicity-reviewer, kieran-typescript-reviewer, pattern-recognition-specialist | Core review |
| `~/.claude/agents/design/` | design-implementation-reviewer, figma-design-sync | UI review |
| `~/.claude/agents/research/` | git-history-analyzer | Historical context |
| pr-review-toolkit plugin | code-reviewer, silent-failure-hunter, type-design-analyzer, pr-test-analyzer, comment-analyzer | PR-specific review |
| pr-review-toolkit plugin | code-simplifier | Active code simplification |

**Simplification Agents - Different Roles:**

| Agent | Type | When to Use |
|-------|------|-------------|
| `code-simplicity-reviewer` | Audit | Identifies complexity issues, flags for review |
| `code-simplifier` | Refactor | Actively simplifies code, applies changes |

Use `code-simplicity-reviewer` during review phase, `code-simplifier` after implementation for cleanup.

**Discover Relevant Skills:**

```bash
find ~/.claude/skills -name "SKILL.md" 2>/dev/null
find ~/.claude/plugins -path "*/skills/*/SKILL.md" 2>/dev/null
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

- Task security-sentinel("Review these changed files for security vulnerabilities: <changed_files>")
- Task performance-oracle("Review these changed files for performance issues: <changed_files>")
- Task architecture-strategist("Review these changed files for architectural concerns: <changed_files>")
- Task code-simplicity-reviewer("Review these changed files for unnecessary complexity: <changed_files>")
- Task pattern-recognition-specialist("Review these changed files for anti-patterns: <changed_files>")
- Task code-reviewer("Review these changed files for code quality issues: <changed_files>")

Every single one. No exceptions.

**Conditional Agents:**

| Condition | Agent | Source |
|-----------|-------|--------|
| TypeScript files | `kieran-typescript-reviewer` | `~/.claude/agents/review/` |
| UI components | `design-implementation-reviewer` | `~/.claude/agents/design/` |
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
Task git-history-analyzer: "Analyze historical context for changed files"
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

#### Option C: PR Comments (for quick reviews)

Post findings directly to PR:

```bash
gh pr comment <pr_number> --body "$(cat <<'EOF'
## Code Review Findings

### P1 - Critical (Blocks Merge)
- [ ] **Security**: SQL injection in `src/api/users.ts:42`

### P2 - Important
- [ ] **Performance**: N+1 query in `src/services/posts.ts:87`

### P3 - Nice-to-have
- [ ] **Quality**: Unused import in `src/utils/helpers.ts:3`
EOF
)"
```

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

**From ~/.claude/agents/:**
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
2. Fix approved items: `/resolve-todo-parallel`
3. Track progress in todo files or prd.json
```

## Discovery Reference

### Agent Paths

```
~/.claude/agents/review/*.md      → Core review agents
~/.claude/agents/design/*.md      → Design review agents
~/.claude/agents/research/*.md    → Research agents
~/.claude/plugins/**/agents/*.md  → Plugin agents
```

### Skill Paths

```
~/.claude/skills/*/SKILL.md
~/.claude/plugins/**/skills/*/SKILL.md
```

### Integration with /sm-work

When reviewing a plan folder:
1. Read prd.json stories
2. Map findings to specific stories
3. Update story with `review_findings` array
4. Add review event to log
5. `/sm-work` can then address findings per-story
