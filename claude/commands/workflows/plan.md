---
name: workflows:plan
description: Transform feature descriptions into well-structured specs and executable PRDs
argument-hint: "[feature description, bug report, or improvement idea]"
---

# Create a plan for a new feature or bug fix

## Introduction

**Note: The current year is 2026.** Use this when dating plans and searching for recent documentation.

Transform feature descriptions, bug reports, or improvement ideas into:
1. **spec.md** - Human-readable plan with rationale, context, and design decisions
2. **prd.json** - Machine-executable story breakdown for systematic implementation

## Feature Description

<feature_description> #$ARGUMENTS </feature_description>

**If the feature description above is empty, ask the user:** "What would you like to plan? Please describe the feature, bug fix, or improvement you have in mind."

Do not proceed until you have a clear feature description from the user.

### 0. Idea Refinement

**Check for existing plan folder or brainstorm first:**

Before asking questions, look for existing plan folders that match this feature:

```bash
ls -la docs/plans/*/brainstorm.md 2>/dev/null
ls -la docs/plans/*/spec.md 2>/dev/null
```

**Relevance criteria:** A brainstorm is relevant if:
- The folder name or brainstorm content semantically matches the feature description
- Created within the last 14 days
- If multiple candidates match, use the most recent one

**If a relevant brainstorm exists:**
1. Read the brainstorm document
2. Announce: "Found brainstorm from [date]: [topic]. Using as context for planning."
3. **Check for shaping format** — look for `shaping: true` in frontmatter, R table, shapes, fit check
4. **Skip the idea refinement questions below** — the brainstorm already answered WHAT to build

**If shaping format detected:**
- Extract R table → primary source for acceptance criteria
- Extract selected shape + parts table → technical approach structure
- Extract flagged unknowns (⚠️) → open questions / spike candidates
- Extract Frame (Source, Problem, Outcome) → spec problem statement
- Use R table as input to SpecFlow and story generation

**If standard brainstorm format:**
- Extract key decisions, chosen approach, and open questions
- Use brainstorm decisions as input to the research phase

**If multiple brainstorms could match:**
Use **AskUserQuestion tool** to ask which brainstorm to use, or whether to proceed without one.

**If no brainstorm found (or not relevant), run idea refinement:**

Refine the idea through collaborative dialogue using the **AskUserQuestion tool**; making sure to interview me relentlessly until we reach a shared understanding - walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

- Ask questions one at a time to understand the idea fully
- Prefer multiple choice questions when natural options exist
- Focus on understanding: purpose, constraints and success criteria
- Continue until the idea is clear OR user says "proceed"

**Gather signals for research decision.** During refinement, note:

- **User's familiarity**: Do they know the codebase patterns? Are they pointing to examples?
- **User's intent**: Speed vs thoroughness? Exploration vs execution?
- **Topic risk**: Security, payments, external APIs warrant more caution
- **Uncertainty level**: Is the approach clear or open-ended?

**Skip option:** If the feature description is already detailed, offer:
"Your description is clear. Should I proceed with research, or would you like to refine it further?"

## Main Tasks

### 1. Local Research (Always Runs - Parallel)

<thinking>
First, I need to understand the project's conventions, existing patterns, and any documented learnings. This is fast and local - it informs whether external research is needed.
</thinking>

Run this agent to gather local context:

- Task repo-research-analyst(feature_description)

**What to look for:**
- Existing patterns, CLAUDE.md/README.md/AGENTS.md guidance, technology familiarity, pattern consistency

These findings inform the next step.

### 1.5. Research Decision

Based on signals from Step 0 and findings from Step 1, decide on external research.

**High-risk topics → always research.** Security, payments, external APIs, data privacy. The cost of missing something is too high. This takes precedence over speed signals.

**Strong local context → skip external research.** Codebase has good patterns, CLAUDE.md has guidance, user knows what they want. External research adds little value.

**Uncertainty or unfamiliar territory → research.** User is exploring, codebase has no examples, new technology. External perspective is valuable.

**Announce the decision and proceed.** Brief explanation, then continue. User can redirect if needed.

Examples:
- "Your codebase has solid patterns for this. Proceeding without external research."
- "This involves payment processing, so I'll research current best practices first."

### 1.5b. External Research (Conditional)

**Only run if Step 1.5 indicates external research is valuable.**

Run these agents in parallel:

- Task best-practices-researcher(feature_description)
- Task framework-docs-researcher(feature_description)

### 1.6. Consolidate Research

After all research steps complete, consolidate findings:

- Document relevant file paths from repo research (e.g., `src/services/exampleService.ts:42`)
- Note external documentation URLs and best practices (if external research was done)
- List related PRs discovered
- Capture CLAUDE.md conventions

**Optional validation:** Briefly summarize findings and ask if anything looks off or missing before proceeding to planning.

### 2. Planning & Structure

<thinking>
Think like a product manager - what would make this spec clear and actionable? Consider multiple perspectives
</thinking>

**Ticket & Branch:**

First, extract or ask for the ticket number:

- [ ] Check if feature description contains a Jira URL (e.g., `https://swissblocktech.atlassian.net/browse/HAW-1222`)
- [ ] If URL found, extract ticket number (e.g., `HAW-1222`)
- [ ] If no URL/ticket, use **AskUserQuestion tool**: "Is there a Jira ticket for this work? (e.g., HAW-1234, or 'none')"

**Branch Naming Convention:**

Format: `[ticket-number]-[description-kebab-case]`

Examples:
- `HAW-1222-user-authentication`
- `HAW-1456-fix-checkout-race-condition`
- `HAW-890-refactor-api-client`

If no ticket: use `type/description-kebab-case` (e.g., `feat/user-authentication`, `fix/checkout-race-condition`)

**Folder & Title:**

- [ ] Draft clear, searchable title using conventional format (e.g., `feat: Add user authentication`, `fix: Cart total calculation`)
- [ ] Determine type: feat, fix, refactor
- [ ] Create folder name: `YYYY-MM-DD-<type>-<descriptive-kebab-name>`
  - Example: `feat: Add User Authentication` → `2026-01-21-feat-user-authentication/`
  - Keep it descriptive (3-5 words) so plans are findable by context

**Create Branch:**

- [ ] Derive branch name: `[ticket]-[kebab-description]` (e.g., `HAW-1222-user-authentication`)
- [ ] Check if branch exists: `git branch --list [branch-name]`
- [ ] If not exists, create and checkout: `git checkout -b [branch-name]`
- [ ] If exists, confirm with user before switching

**Stakeholder Analysis:**

- [ ] Identify who will be affected (end users, developers, operations)
- [ ] Consider implementation complexity and required expertise

**Content Planning:**

- [ ] Choose appropriate detail level based on complexity and audience
- [ ] List all necessary sections for the chosen template
- [ ] Gather supporting materials (error logs, screenshots, design mockups)
- [ ] Prepare code examples or reproduction steps if applicable

### 3. SpecFlow Analysis

After planning the structure, run SpecFlow Analyzer to validate and refine the feature specification:

- Task spec-flow-analyzer(feature_description, research_findings)

**SpecFlow Analyzer Output:**

- [ ] Review SpecFlow analysis results
- [ ] Incorporate any identified gaps or edge cases
- [ ] Update acceptance criteria based on SpecFlow findings

### 3.5. Breadboard (Conditional)

**Gate:** Only run if the selected shape has **3+ parts**. Skip for simple shapes.

**Trigger:** Shaping-format brainstorm with a selected shape containing enough parts to warrant detailed affordance mapping.

When breadboarding:

1. Load the `/breadboarding` skill as methodology reference
2. Take the selected shape's parts table as input
3. Produce affordance tables:
   - **Places table** — bounded contexts of interaction
   - **UI Affordances table** — things users see and interact with
   - **Code Affordances table** — methods, handlers, data stores
   - **Data Stores table** — state that persists and is read/written
4. Optionally produce Mermaid visualization

**Slicing:**

After breadboarding, slice into vertical increments (V1-V9 max):

| # | Slice | Mechanism | Demo |
|---|-------|-----------|------|
| V1 | [name] | [part refs] | "[demo statement]" |
| V2 | [name] | [part refs] | "[demo statement]" |

Each slice must have:
- Name describing the increment
- Mechanism refs (which shape parts it demonstrates)
- Affordances list (which U/N/S are added)
- Demo statement (what can be shown to a stakeholder)

Add breadboard tables + slice summary as a section in spec.md.

### 4. Choose Spec Detail Level

Select how comprehensive the spec should be. Simpler is mostly better.

#### MINIMAL (Quick Spec)

**Best for:** Simple bugs, small improvements, clear features

**Includes:**

- Problem statement or feature description
- Basic acceptance criteria
- Essential context only

**Structure:**

````markdown
---
title: [Title]
type: [feat|fix|refactor]
date: YYYY-MM-DD
---

# [Title]

## Problem

[Brief problem/feature description]

## Solution

[High-level approach]

## Acceptance Criteria

- [ ] Core requirement 1
- [ ] Core requirement 2

## Context

[Any critical information]

## References

- Similar pattern: `src/example.ts:42`
- Documentation: [relevant_docs_url]
````

#### STANDARD (Most Features)

**Best for:** Most features, complex bugs, team collaboration

**Includes everything from MINIMAL plus:**

- Detailed background and motivation
- Technical considerations
- Success metrics
- Dependencies and risks

**Structure:**

```markdown
---
title: [Title]
type: [feat|fix|refactor]
date: YYYY-MM-DD
---

# [Title]

## Overview

[Comprehensive description]

## Problem Statement

[Why this matters, what pain it solves]

## Proposed Solution

[High-level approach with rationale]

## Technical Considerations

- Architecture impacts
- Performance implications
- Security considerations

## Acceptance Criteria

- [ ] Detailed requirement 1
- [ ] Detailed requirement 2
- [ ] Testing requirements

## Success Metrics

[How we measure success]

## Dependencies & Risks

[What could block or complicate this]

## References

- Similar pattern: `src/services/example.ts:42`
- Best practices: [documentation_url]
- Related PR: #[pr_number]
```

#### COMPREHENSIVE (Major Features)

**Best for:** Major features, architectural changes, complex integrations

**Includes everything from STANDARD plus:**

- Detailed implementation phases
- Alternative approaches considered
- Extensive technical specifications
- Risk mitigation strategies

**Structure:**

```markdown
---
title: [Title]
type: [feat|fix|refactor]
date: YYYY-MM-DD
---

# [Title]

## Overview

[Executive summary]

## Problem Statement

[Detailed problem analysis]

## Proposed Solution

[Comprehensive solution design]

## Technical Approach

### Architecture

[Detailed technical design]

### Implementation Phases

#### Phase 1: [Foundation]

- Tasks and deliverables
- Success criteria

#### Phase 2: [Core Implementation]

- Tasks and deliverables
- Success criteria

#### Phase 3: [Polish & Optimization]

- Tasks and deliverables
- Success criteria

## Alternative Approaches Considered

[Other solutions evaluated and why rejected]

## Acceptance Criteria

### Functional Requirements

- [ ] Detailed functional criteria

### Non-Functional Requirements

- [ ] Performance targets
- [ ] Security requirements
- [ ] Accessibility standards

## Success Metrics

[Detailed KPIs and measurement methods]

## Dependencies & Prerequisites

[Detailed dependency analysis]

## Risk Analysis & Mitigation

[Comprehensive risk assessment]

## Future Considerations

[Extensibility and long-term vision]

## References

### Internal

- Architecture: `src/core/architecture.ts:15`
- Similar feature: `src/features/example.ts:42`

### External

- Framework docs: [url]
- Best practices: [url]

### Related Work

- PR: #[pr_number]
- Design doc: [link]
```

### 5. Spec Formatting

<thinking>
Focus on human readability and decision context. This is the document humans read to understand WHY.
</thinking>

**Content Quality:**

- [ ] Clear problem/motivation - why this matters
- [ ] Technical approach with rationale for choices
- [ ] Alternatives considered and why rejected (if applicable)
- [ ] Code references use `file:line` format (e.g., `src/auth/login.ts:42`)

**Markdown Best Practices:**

- [ ] Clear heading hierarchy (##, ###)
- [ ] Code examples with syntax highlighting
- [ ] Task lists (- [ ]) for acceptance criteria
- [ ] Collapsible `<details>` sections for verbose content

**Example code block with file reference:**

````markdown
```typescript
// src/services/userService.ts:42
function processUser(user: User): void {
  // Implementation here
}
```
````

**Collapsible section for verbose content:**

````markdown
<details>
<summary>Full error stacktrace</summary>

```
Error details here...
```

</details>
````

### 6. PRD Generation

<thinking>
Break the spec into atomic, executable stories. This is the document machines read to track progress.
</thinking>

After writing spec.md, generate prd.json with executable story breakdown.

**Story Source Selection:**

If breadboard slices exist (from Step 3.5), use them to generate stories:
- Each slice V1-V9 → one story (or story group if slice is large)
- Slice demo statement → acceptance criteria
- Slice mechanism refs → story title context
- Slice affordance list → implementation guidance in story description
- Slice ordering (V1 first) → story priority + depends_on

If no breadboard (simple shapes or non-shaping brainstorm), extract stories from spec as usual.

**Story Extraction Rules:**

- [ ] Each story is atomic - single action, no "and"
- [ ] Stories have clear acceptance criteria (Given/When/Then format)
- [ ] Dependencies between stories are explicit
- [ ] Skills hint at relevant slash commands for implementation

**Category Assignment:**

Each story must have exactly one category:
- `functional` - Core feature behavior
- `ui` - User interface components and styling
- `integration` - External systems, APIs, third-party services
- `edge-case` - Error handling, boundary conditions
- `performance` - Optimization, caching, efficiency

**PRD Schema:**

```json
{
  "title": "feature-name",
  "ticket": "HAW-1222",
  "branch": "HAW-1222-feature-name",
  "spec_path": "docs/plans/YYYY-MM-DD-<type>-<name>/spec.md",
  "created_at": "2026-01-30T12:00:00Z",
  "stories": [
    {
      "id": 1,
      "title": "User can create account",
      "category": "functional",
      "skills": [],
      "validation_agents": [],
      "depends_on": [],
      "acceptance_criteria": [
        "Given signup form, when valid data submitted, account is created",
        "Given signup form, when email exists, error message displays"
      ],
      "status": "pending",
      "priority": 10,
      "completed_at": null,
      "commit": null,
      "review_findings": []
    },
    {
      "id": 2,
      "title": "Account creation shows success feedback",
      "category": "ui",
      "skills": [],
      "validation_agents": [],
      "depends_on": [1],
      "acceptance_criteria": [
        "Given successful creation, when complete, success toast appears",
        "Given successful creation, when complete, user redirected to dashboard"
      ],
      "status": "pending",
      "priority": 20,
      "completed_at": null,
      "commit": null,
      "review_findings": []
    }
  ],
  "log": []
}
```

**Note:** `skills` and `validation_agents` are initially empty. Run `/deepen-plan` to:
1. Discover all available skills from `~/.claude/skills/` and plugins
2. Match skills to stories based on category, keywords, and tech stack
3. Assign validation agents for post-implementation review

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `ticket` | string\|null | Jira ticket number (e.g., `HAW-1222`), null if none |
| `branch` | string | Git branch name: `[ticket]-[description]` or `type/description` |
| `id` | number | Unique integer, starts at 1 |
| `title` | string | Single action, imperative, no "and" |
| `category` | string | One of: functional, ui, integration, edge-case, performance |
| `skills` | array | Slash command skills for implementation (populated by /deepen-plan) |
| `validation_agents` | array | Review agents to run after implementation (populated by /deepen-plan) |
| `depends_on` | array | Story IDs that must complete first |
| `acceptance_criteria` | array | Given/When/Then statements (min 1) |
| `status` | string | One of: pending, in_progress, blocked, completed |
| `priority` | number | Unique, spaced by 10 (10, 20, 30...) |
| `completed_at` | null\|string | ISO8601 timestamp when completed |
| `commit` | null\|string | Commit SHA that completed the story |
| `review_findings` | array | Findings from validation_agents or /workflows:review |

**Log Entry Shape (populated during /workflows:work):**

```json
{
  "timestamp": "2026-01-30T14:30:00Z",
  "story_id": 1,
  "action": "status_change",
  "from": "pending",
  "to": "in_progress",
  "agent": "claude-opus-4-5"
}
```

**Review Finding Shape (populated by validation_agents or /workflows:review):**

```json
{
  "severity": "P1",
  "category": "security",
  "agent": "security-sentinel",
  "finding": "SQL injection risk in user input",
  "file": "src/api/users.ts:42",
  "suggestion": "Use parameterized queries",
  "status": "resolved",
  "resolved_at": "2026-01-30T15:00:00Z"
}
```

**Finding status values:**
- `logged` - Finding recorded, not yet addressed
- `resolved` - Finding fixed
- `wontfix` - Intentionally not fixing (with justification)

**PRD Generation Checklist:**

- [ ] `ticket` field set (or null if no ticket)
- [ ] `branch` field matches created branch name
- [ ] All acceptance criteria from spec are covered by stories
- [ ] Stories are ordered by dependency (blockers have lower priority numbers)
- [ ] No circular dependencies
- [ ] Initial skills is empty array (populated by /deepen-plan)
- [ ] Initial validation_agents is empty array (populated by /deepen-plan)
- [ ] Initial review_findings is empty array (populated by validation_agents or /workflows:review)
- [ ] Initial status is always "pending"
- [ ] Initial completed_at and commit are always null
- [ ] Initial log is always empty array

### 7. Final Review

**Pre-write Checklist:**

- [ ] Folder name is descriptive and findable
- [ ] spec.md sections are complete for chosen detail level
- [ ] prd.json stories cover all acceptance criteria
- [ ] Dependencies are correctly mapped
- [ ] Code references use file:line format
- [ ] ERD mermaid diagram included if new models introduced

## Output Structure

**Folder:** `docs/plans/YYYY-MM-DD-<type>-<descriptive-name>/`

**Contents:**
```
docs/plans/2026-01-30-feat-user-authentication/
  brainstorm.md    # optional, if created via /workflows:brainstorm
  spec.md          # human-readable plan
  prd.json         # machine-executable stories
```

**Examples:**
- `docs/plans/2026-01-15-feat-user-authentication/`
- `docs/plans/2026-02-03-fix-checkout-race-condition/`
- `docs/plans/2026-03-10-refactor-api-client-extraction/`

**Invalid:**
- `docs/plans/2026-01-15-feat-thing/` (not descriptive)
- `docs/plans/2026-01-15-feat-new-feature/` (too vague)
- `docs/plans/feat-user-auth/` (missing date prefix)

## Post-Generation Options

After writing spec.md and prd.json, use the **AskUserQuestion tool**:

**Question:** "Plan ready at `docs/plans/YYYY-MM-DD-<type>-<name>/`. What would you like to do next?"

**Options:**
1. **Review spec** - Open spec.md in editor
2. **Review PRD** - Show prd.json story breakdown
3. **Run `/deepen-plan`** - Enhance spec with parallel research agents
4. **Run `/codex-review`** - Independent cross-model review via Codex CLI
5. **Start `/workflows:work`** - Begin implementing stories locally
6. **Start `/workflows:work` on remote** - Begin in Claude Code web (background)
7. **Simplify** - Reduce detail level or story count

**Based on selection:**
- **Review spec** → Run `open docs/plans/<folder>/spec.md`
- **Review PRD** → Display prd.json contents formatted
- **`/deepen-plan`** → Call /deepen-plan with spec path
- **`/codex-review`** → Call /codex-review with folder path. Iterative review loop: Codex reviews plan, Claude revises, repeat until approved.
- **`/workflows:work`** → Call /workflows:work with folder path
- **`/workflows:work` on remote** → Run `/workflows:work docs/plans/<folder>/ &`
- **Simplify** → Ask "What should I simplify?" then regenerate

**Note:** If running with ultrathink enabled, automatically run `/deepen-plan` after creation.

Loop back to options after Simplify until user selects `/workflows:work`.

NEVER CODE! Just research and write the plan.
