---
name: so-plan
description: Transform feature descriptions into well-structured specs and executable PRDs
---

# Create a plan for a new feature or bug fix

Adhere to the Builder Ethos (ETHOS.md): Boil the Lake, Search Before Building, User Sovereignty.

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
- Extract flagged unknowns (!) → open questions / spike candidates
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

You MUST run this agent to gather local context. Do not skip:

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

**Briefly summarize findings to the user and ask if anything looks off or missing before proceeding to planning.**

### 1.7. Choose Detail Level

Use the **AskUserQuestion tool** to determine how comprehensive the spec should be. This decision affects how much work goes into subsequent steps.

**Question:** "What level of detail do you want for this spec?"

**Options:**
1. **MINIMAL** — Quick spec. Problem + solution + acceptance criteria. Best for simple bugs, small improvements, clear features.
2. **STANDARD** — Most features. Adds background, technical considerations, success metrics, dependencies/risks.
3. **COMPREHENSIVE** — Major features, architectural changes. Produces 5 documents: ADR, backend spec, DTO contract, UI design spec, frontend spec. Uses a decision cascade model where you make key architectural decisions and everything else derives automatically.

**Default recommendation:** STANDARD unless the feature is trivially small (MINIMAL) or involves major architecture, multiple system layers, or complex integrations (COMPREHENSIVE).

**If user picks COMPREHENSIVE:** The planning steps below still run, but Step 4 will trigger an extended collaborative decision-making process that produces 5 spec documents instead of a single spec.md.

### 2. Planning & Structure

**Ticket & Branch:**

First, extract or ask for the ticket number:

- [ ] Check if feature description contains a ticket URL (e.g., `https://yourorg.atlassian.net/browse/PROJ-1222`)
- [ ] If URL found, extract ticket number (e.g., `PROJ-1222`)
- [ ] If no URL/ticket, use **AskUserQuestion tool**: "Is there a ticket for this work? (e.g., PROJ-1234, or 'none')"

**Branch Naming Convention:**

Format: `[ticket-number]-[description-kebab-case]`

Examples:
- `PROJ-1222-user-authentication`
- `PROJ-1456-fix-checkout-race-condition`
- `PROJ-890-refactor-api-client`

If no ticket: use `type/description-kebab-case` (e.g., `feat/user-authentication`, `fix/checkout-race-condition`)

**Folder & Title:**

- [ ] Draft clear, searchable title using conventional format (e.g., `feat: Add user authentication`, `fix: Cart total calculation`)
- [ ] Determine type: feat, fix, refactor
- [ ] Create folder name: `YYYY-MM-DD-<type>-<descriptive-kebab-name>`
  - Example: `feat: Add User Authentication` → `2026-01-21-feat-user-authentication/`
  - Keep it descriptive (3-5 words) so plans are findable by context

**Create Branch:**

- [ ] Derive branch name: `[ticket]-[kebab-description]` (e.g., `PROJ-1222-user-authentication`)
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

### 3.5. Breadboard

**Gate:** Run when a shaping-format brainstorm exists (detected by `shaping: true` frontmatter and a selected shape).

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

### 3.6. Breadboard Reflection

**Gate:** Run after Step 3.5 produces breadboard tables.

1. Load the `/breadboard-reflection` skill as methodology reference
2. Trace each key user story through the wiring — does the path tell a coherent story?
3. Apply the naming test to each affordance — one idiomatic verb per affordance
4. Flag smells: incoherent wiring, missing paths, bundled affordances, naming resistance
5. Fix any issues found: split affordances, correct wiring, update tables

If changes are made, re-render the breadboard tables and update the slice summary before proceeding.

### 4. Generate Spec(s) by Detail Level

Use the detail level chosen in Step 1.7. Simpler is mostly better.

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

**Best for:** Major features, architectural changes, complex integrations spanning backend + frontend

**Produces 5 documents** instead of a single spec.md:

1. **adr.md** — Architecture Decision Record: every significant decision, who made it, why, alternatives rejected
2. **backend.md** — Backend Tech Spec: data model, API design, business logic, security, testing
3. **dtos.md** — DTO Contract Spec: shared + feature-specific request/response types with example payloads
4. **ui-design.md** — UI Design Tech Spec: page layouts, component inventory, responsive behavior, accessibility
5. **frontend.md** — Frontend Tech Spec: routing, state management, data fetching, forms, error handling, testing

**Decision Cascade Model:**

Every decision falls into one of three categories:

- **USER DECIDES** — Requires judgment, taste, or domain knowledge. Present 2-4 options with pros/cons tied to specific requirements, a recommendation with concrete rationale. Use **AskUserQuestion tool**, one decision at a time. Wait for answer before proceeding.
- **LLM DERIVES** — Cascades automatically from user decisions. Document what cascaded from which decision. Example: user picks "cursor-based pagination" → derive query parameter names, response envelope shape, cursor encoding, default/max page sizes, UI pagination component props.
- **LLM DECIDES** — Universal best practices (security, accessibility, error handling, performance). Apply silently, document in specs.

**Decision Queue** (ask in dependency order, skip what codebase already answers):

1. Data model shape and entity relationships
2. Status/enum definitions and state machines
3. API design (style, URL structure, endpoints)
4. Auth and permissions model for this feature
5. Frontend state management boundaries
6. Component architecture and granularity
7. Data fetching and cache strategy
8. Form management approach
9. UI interaction patterns (modals vs pages vs drawers)
10. Business logic placement (validation split, computation location)
11. Infrastructure decisions (background jobs, file storage, caching)

**Before asking questions:** Summarize conventions found in codebase, decisions already answered by existing patterns, decisions that don't apply, and roughly how many questions remain.

**After each decision:** Record it for ADR, derive cascading details immediately, confirm cascades briefly: "Got it — [choice]. That means I'll [cascade 1], [cascade 2]. Moving on to [next]."

**After all decisions:** Confirm full set of choices, then write all 5 docs + a consolidating spec.md.

**Consolidating spec.md (COMPREHENSIVE only):**

In addition to the 5 detailed docs, always produce a spec.md that serves as the entry point. This is what downstream tools (so-plan-review, deepen-plan, workflows:work) read first.

```markdown
---
title: [Title]
type: comprehensive
date: YYYY-MM-DD
documents:
  - adr.md
  - backend.md
  - dtos.md
  - ui-design.md
  - frontend.md
---

# [Title]

## Overview
[2-3 paragraph summary of the feature — problem, solution, key decisions]

## Key Architectural Decisions
[Consolidated from adr.md — the 3-5 most important decisions with rationale]

## API Surface
[Consolidated from backend.md + dtos.md — endpoints, key types, data flow]

## UI Approach
[Consolidated from ui-design.md + frontend.md — screens, states, interaction model]

## Acceptance Criteria
[Consolidated from all docs — the complete testable checklist]

## Technical Considerations
[Cross-cutting concerns: security, performance, deployment, risks]

## Detailed Documents
- [adr.md](adr.md) — Full architecture decision record
- [backend.md](backend.md) — Backend tech spec
- [dtos.md](dtos.md) — DTO contract spec
- [ui-design.md](ui-design.md) — UI design tech spec
- [frontend.md](frontend.md) — Frontend tech spec
```

This is NOT a thin index — it must contain enough substance that someone reading only spec.md understands the full plan. The 5 detailed docs are the deep-dive reference.

**Cross-reference before finalizing:**
- Every API endpoint has corresponding DTOs
- Every DTO is referenced by backend endpoint + frontend query/mutation
- Every component in UI design has wiring in frontend spec
- Every data field displayed in UI comes from a response DTO
- Every validation rule appears in both backend and frontend specs
- Every decision in ADR is reflected in specs

### 5. Spec Formatting

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

After writing spec.md, you MUST generate prd.json with executable story breakdown.

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
  "ticket": "PROJ-1222",
  "branch": "PROJ-1222-feature-name",
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
| `ticket` | string\|null | Ticket number (e.g., `PROJ-1222`), null if none |
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

### 6.5. Mandatory Diagrams

No non-trivial flow goes undiagrammed. Use ASCII art inline while thinking through flows, then produce Mermaid diagrams for the final spec.md.

**Produce all that apply:**
1. **System architecture** — new components and their relationships to existing ones
2. **Data flow** — including shadow paths (nil, empty, error)
3. **State machine** — for every new stateful object, include invalid transitions
4. **Processing pipeline** — for background jobs, queues, multi-step transforms
5. **Decision tree** — for complex branching logic
6. **Dependency graph** — what depends on what, build/deploy order

Use `skill: beautiful-mermaid` to render final diagrams as SVG/PNG when needed.

Drawing forces thinking. If you can't diagram it, you don't understand it yet.

### 7. Final Review

**Pre-write Checklist:**

- [ ] Folder name is descriptive and findable
- [ ] spec.md sections are complete for chosen detail level
- [ ] prd.json stories cover all acceptance criteria
- [ ] Dependencies are correctly mapped
- [ ] Code references use file:line format
- [ ] Mandatory diagrams included (architecture, data flow, state machines as applicable)

## Output Structure

**Folder:** `docs/plans/YYYY-MM-DD-<type>-<descriptive-name>/`

**Contents (MINIMAL / STANDARD):**
```
docs/plans/2026-01-30-feat-user-authentication/
  brainstorm.md    # optional, if created via /workflows:brainstorm
  spec.md          # human-readable plan
  prd.json         # machine-executable stories
```

**Contents (COMPREHENSIVE):**
```
docs/plans/2026-01-30-feat-user-authentication/
  brainstorm.md    # optional, if created via /workflows:brainstorm
  spec.md          # consolidating overview (entry point for downstream tools)
  adr.md           # architecture decision record
  backend.md       # backend tech spec
  dtos.md          # DTO contract spec (shared + feature-specific types)
  ui-design.md     # UI design tech spec
  frontend.md      # frontend tech spec
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

After writing spec(s) and prd.json, use the **AskUserQuestion tool**:

**Question:** "Plan ready at `docs/plans/YYYY-MM-DD-<type>-<name>/`. What would you like to do next?"

**Options:**
1. **Review specs** - Open spec.md (or list 5 docs for COMPREHENSIVE)
2. **Review PRD** - Show prd.json story breakdown
3. **Run `/deepen-plan`** - Enhance spec with parallel research agents
4. **Run `/codex-plan-review`** - Independent cross-model review via Codex CLI
5. **Start `/workflows:work`** - Begin implementing stories locally
6. **Start `/workflows:work` on remote** - Begin in Claude Code web (background)
7. **Simplify** - Reduce detail level or story count

**Based on selection:**
- **Review specs** → For MINIMAL/STANDARD: `open docs/plans/<folder>/spec.md`. For COMPREHENSIVE: list all 5 docs and open the one user picks.
- **Review PRD** → Display prd.json contents formatted
- **`/deepen-plan`** → Call /deepen-plan with spec path
- **`/codex-plan-review`** → Call /codex-plan-review with folder path. Iterative review loop: Codex reviews plan, Claude revises, repeat until approved.
- **`/workflows:work`** → Call /workflows:work with folder path
- **`/workflows:work` on remote** → Run `/workflows:work docs/plans/<folder>/ &`
- **Simplify** → Ask "What should I simplify?" then regenerate

**Note:** If running with ultrathink enabled, automatically run `/deepen-plan` after creation.

Loop back to options after Simplify until user selects `/workflows:work`.

NEVER CODE! Just research and write the plan.
