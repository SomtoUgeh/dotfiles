---
name: workflows-plan
description: Transform feature descriptions into well-structured specs and executable PRDs
---

# Create a plan for a new feature or bug fix

## Runtime Tools

When this skill needs user questions, todo/progress tracking, subagents, or another skill, use the active runtime equivalents in [RUNTIME_TOOLS.md](../RUNTIME_TOOLS.md).


Follow the active shared and project instruction files. `ETHOS.md` is a human reference, not an additional mandatory runtime source.

## Introduction

Use the current date from the active environment when dating plans. Treat dated examples as illustrative.

Transform feature descriptions, bug reports, or improvement ideas into:
1. **spec.md** - Human-readable plan with rationale, context, and design decisions
2. **prd.json** - Machine-executable story breakdown for systematic implementation

## Feature Description

<feature_description> $ARGUMENTS </feature_description>

Resolve the feature from the invocation, current conversation, or named brainstorm/plan. `$ARGUMENTS` is illustrative input notation, not a shell variable. Ask what to plan only if no objective can be resolved from those sources.

### 0. Idea Refinement

**Check for existing plan folder or brainstorm first:**

Before asking questions, look for existing plan folders that match this feature:

```bash
ls -la docs/plans/*/brainstorm.md 2>/dev/null
ls -la docs/plans/*/spec.md 2>/dev/null
```

**Relevance criteria:** A brainstorm is relevant if:
- The folder name or brainstorm content semantically matches the feature description
- The user-selected artifact takes precedence regardless of age
- Use recency as a discovery aid; verify decisions against the current task rather than discarding an older relevant document

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
Use **structured user-question tool** to ask which brainstorm to use, or whether to proceed without one.

**If no brainstorm found (or not relevant), run idea refinement:**

Ask only questions that resolve material uncertainty. Use existing conversation and repository evidence first; continue independent research while awaiting an answer.

- Ask questions one at a time to understand the idea fully
- Prefer multiple choice questions when natural options exist
- Focus on understanding: purpose, constraints and success criteria
- Continue until the idea is clear OR user says "proceed"

**Gather signals for research decision.** During refinement, note:

- **User's familiarity**: Do they know the codebase patterns? Are they pointing to examples?
- **User's intent**: Speed vs thoroughness? Exploration vs execution?
- **Topic risk**: Security, payments, external APIs warrant more caution
- **Uncertainty level**: Is the approach clear or open-ended?

If the feature description is already clear, proceed directly to research without another confirmation.

## Main Tasks

### 1. Local Research (Always Runs - Parallel)

Gather local context. Delegate only when a callable researcher can answer a bounded question independently; otherwise research locally:

- Launch subagent `repo-research-analyst` with prompt (feature_description)

**What to look for:**
- Existing patterns, active project instructions (AGENTS.md, CLAUDE.md, README.md, OPENCODE.md), technology familiarity, pattern consistency

These findings inform the next step.

### 1.5. Research Decision

Based on signals from Step 0 and findings from Step 1, decide on external research.

**High-risk topics → always research.** Security, payments, external APIs, data privacy. The cost of missing something is too high. This takes precedence over speed signals.

**Strong local context → skip external research.** Codebase has good patterns, project instructions have guidance, user knows what they want. External research adds little value.

**Uncertainty or unfamiliar territory → research.** User is exploring, codebase has no examples, new technology. External perspective is valuable.

**Announce the decision and proceed.** Brief explanation, then continue. User can redirect if needed.

Examples:
- "Your codebase has solid patterns for this. Proceeding without external research."
- "This involves payment processing, so I'll research current best practices first."

### 1.5b. External Research (Conditional)

**Only run if Step 1.5 indicates external research is valuable.**

When independent questions justify delegation and callable roles are available, use the relevant researchers below. Otherwise do this research locally; do not require both agents for the same question:

- Launch subagent `best-practices-researcher` with prompt (feature_description)
- Launch subagent `framework-docs-researcher` with prompt (feature_description)

### 1.6. Consolidate Research

After all research steps complete, consolidate findings:

- Document relevant file paths from repo research (e.g., `src/services/exampleService.ts:42`)
- Note external documentation URLs and best practices (if external research was done)
- List related PRs discovered
- Capture active project instruction conventions

Briefly summarize findings and proceed; ask only about an unresolved decision that changes the plan.

### 1.7. Choose Detail Level

Honor a requested detail level; otherwise choose proportionately from the levels below and state the choice. Ask only when the audience or deliverable is unclear.

**Question:** "What level of detail do you want for this spec?"

**Options:**
1. **MINIMAL** — Quick spec. Problem + solution + acceptance criteria. Best for simple bugs, small improvements, clear features.
2. **STANDARD** — Most features. Adds background, technical considerations, success metrics, dependencies/risks.
3. **COMPREHENSIVE** — Major features, architectural changes. Adds the applicable architecture, backend, contract, UI, and frontend documents to the overview. Record key decisions first, derive dependent choices, and verify those choices against requirements.

**Default recommendation:** STANDARD unless the feature is trivially small (MINIMAL) or involves major architecture, multiple system layers, or complex integrations (COMPREHENSIVE).

**For COMPREHENSIVE:** The planning steps below still run. Step 4 produces an overview plus the supporting documents the feature needs; do not invent UI or backend scope to fill a template.

### 2. Planning & Structure

**Ticket & Branch:**

First, extract or ask for the ticket number:

- [ ] Check if feature description contains a ticket URL (e.g., `https://yourorg.atlassian.net/browse/PROJ-1222`)
- [ ] If URL found, extract ticket number (e.g., `PROJ-1222`)
- [ ] If no ticket is supplied or discoverable, use null; a ticket is optional.

**Branch Naming Convention:**

Format: `feat/[ticket-number]-[description-kebab-case]`

Examples:
- `feat/PROJ-1222-user-authentication`
- `fix/PROJ-1456-checkout-race-condition`
- `refactor/PROJ-890-api-client`

If no ticket: use `type/description-kebab-case` (e.g., `feat/user-authentication`, `fix/checkout-race-condition`)

**Folder & Title:**

- [ ] Draft clear, searchable title using conventional format (e.g., `feat: Add user authentication`, `fix: Cart total calculation`)
- [ ] Determine type: feat, fix, refactor
- [ ] Create folder name: `YYYY-MM-DD-<type>-<descriptive-kebab-name>`
  - Example: `feat: Add User Authentication` → `2026-01-21-feat-user-authentication/`
  - Keep it descriptive (3-5 words) so plans are findable by context

**Proposed branch:** Record the intended branch name in the plan using the repository convention. Do not create or switch branches during planning; implementation owns workspace setup.

**Stakeholder Analysis:**

- [ ] Identify who will be affected (end users, developers, operations)
- [ ] Consider implementation complexity and required expertise

**Content Planning:**

- [ ] Choose appropriate detail level based on complexity and audience
- [ ] List all necessary sections for the chosen template
- [ ] Gather supporting materials (error logs, screenshots, design mockups)
- [ ] Prepare code examples or reproduction steps if applicable

### 3. SpecFlow Analysis

After planning the structure, validate flows and gaps locally or with a callable SpecFlow Analyzer when a separate review is useful:

- Launch subagent `spec-flow-analyzer` with prompt (feature_description, research_findings)

**SpecFlow Analyzer Output:**

- [ ] Review SpecFlow analysis results
- [ ] Verify identified gaps and edge cases; incorporate in-scope corrections and ask before adopting an outside reviewer's direction change
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

### 4. Generate the chosen spec

Read [spec-templates.md](references/spec-templates.md) for the selected MINIMAL, STANDARD, or COMPREHENSIVE format. Use only the sections the requested scope needs.

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

- [ ] Each story delivers one coherent, verifiable outcome, including the error paths needed to make it complete; do not split by wording or technical layer alone
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

Read [prd-schema.md](references/prd-schema.md) for the schema, field meanings, examples, and validation checklist. Validate unique IDs, valid dependencies, acyclicity, and coverage of every acceptance criterion.

### 6.5. Mandatory Diagrams

No non-trivial flow goes undiagrammed. Use ASCII art inline while thinking through flows, then produce Mermaid diagrams for the final spec.md.

**Produce all that apply:**
1. **System architecture** — new components and their relationships to existing ones
2. **Data flow** — including shadow paths (nil, empty, error)
3. **State machine** — for every new stateful object, include invalid transitions
4. **Processing pipeline** — for background jobs, queues, multi-step transforms
5. **Decision tree** — for complex branching logic
6. **Dependency graph** — what depends on what, build/deploy order

Use an available Mermaid renderer or `technical-svg-diagrams` when an exported diagram is needed. Do not require an uninstalled skill.

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
  brainstorm.md    # optional, if created via /workflows-brainstorm
  spec.md          # human-readable plan
  prd.json         # machine-executable stories
```

**Contents (COMPREHENSIVE; supporting documents only where applicable):**
```
docs/plans/2026-01-30-feat-user-authentication/
  brainstorm.md    # optional, if created via /workflows-brainstorm
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

Report the plan location and offer relevant next actions in prose. If the user already requested the next stage, continue under that authorization.

**Options:**
1. **Review specs** - Open spec.md and list its supporting documents
2. **Review PRD** - Show prd.json story breakdown
3. **Run `/workflows-deepen-plan`** - Enhance spec with parallel research agents
4. **Run `/workflows-plan-review`** - Independent plan review
5. **Start `/workflows-work`** - Begin implementing stories locally
6. **Start `/workflows-work` on remote** - Begin in the configured remote agent runtime (background)
7. **Simplify** - Reduce detail level or story count

**Based on selection:**
- **Review specs** → Open `docs/plans/<folder>/spec.md` with the active runtime's file viewer. For COMPREHENSIVE, also list the supporting documents that were produced.
- **Review PRD** → Display prd.json contents formatted
- **`/workflows-deepen-plan`** → Call /workflows-deepen-plan with spec path
- **`/workflows-plan-review`** → Call /workflows-plan-review with folder path. Iterative review loop: review the plan, the active agent revises, repeat until approved.
- **`/workflows-work`** → Call /workflows-work with folder path
- **`/workflows-work` on remote** → Use the available remote harness with its documented invocation and explicit target; a slash command is not a shell executable.
- **Simplify** → Ask "What should I simplify?" then regenerate

Deepen the plan when requested or needed to resolve a concrete gap; do not infer a new workflow from a model effort setting.

After a requested simplification, report the revised plan. Planning alone does not authorize implementation; if the user requested planning followed by implementation, finish this phase and continue into that authorized workflow.
