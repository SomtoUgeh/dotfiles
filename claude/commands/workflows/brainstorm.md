---
name: workflows:brainstorm
description: Explore requirements and approaches through collaborative dialogue before planning implementation
argument-hint: "[feature idea or problem to explore]"
---

# Brainstorm a Feature or Improvement

**Note: The current year is 2026.** Use this when dating brainstorm documents.

Brainstorming helps answer **WHAT** to build through collaborative dialogue. It precedes `/workflows:plan`, which answers **HOW** to build it.

## Feature Description

<feature_description> #$ARGUMENTS </feature_description>

**If the feature description above is empty, ask the user:** "What would you like to explore? Please describe the feature, problem, or improvement you're thinking about."

Do not proceed until you have a feature description from the user.

## Execution Flow

### Phase 0: Assess Requirements Clarity

Evaluate whether brainstorming is needed based on the feature description.

**Clear requirements indicators:**
- Specific acceptance criteria provided
- Referenced existing patterns to follow
- Described exact expected behavior
- Constrained, well-defined scope

**If requirements are already clear:**
Use **AskUserQuestion tool** to suggest: "Your requirements seem detailed enough to proceed directly to planning. Should I run `/workflows:plan` instead, or would you like to explore the idea further?"

### Phase 1: Understand the Idea

#### 1.1 Repository Research (Lightweight)

Run a quick repo scan to understand existing patterns:

- Task repo-research-analyst("Understand existing patterns related to: <feature_description>")

Focus on: similar features, established patterns, CLAUDE.md guidance.

#### 1.2 Collaborative Dialogue

Use the **AskUserQuestion tool** to ask questions **one at a time**.

**Guidelines:**
- Prefer multiple choice when natural options exist
- Start broad (purpose, users) then narrow (constraints, edge cases)
- Validate assumptions explicitly
- Ask about success criteria

**Exit condition:** Continue until the idea is clear OR user says "proceed"

### Phase 2: Explore Approaches

Propose **2-3 concrete approaches** based on research and conversation.

For each approach, provide:
- Brief description (2-3 sentences)
- Pros and cons
- When it's best suited

Lead with your recommendation and explain why. Apply YAGNI—prefer simpler solutions.

Use **AskUserQuestion tool** to ask which approach the user prefers.

### Phase 3: Determine Folder Name

Before writing the brainstorm document, determine the plan folder name:

- [ ] Determine type: feat, fix, refactor
- [ ] Create folder name: `YYYY-MM-DD-<type>-<descriptive-kebab-name>`
  - Example: `feat: Add User Authentication` → `2026-01-21-feat-user-authentication/`
  - Keep it descriptive (3-5 words) so plans are findable by context

This folder will later contain spec.md and prd.json when `/workflows:plan` runs.

### Phase 4: Capture the Design

Write brainstorm document to `docs/plans/YYYY-MM-DD-<type>-<name>/brainstorm.md`.

**Create the folder first:**
```bash
mkdir -p docs/plans/YYYY-MM-DD-<type>-<name>
```

**Document structure:**

```markdown
---
title: [Feature Title]
type: [feat|fix|refactor]
date: YYYY-MM-DD
status: brainstorm
---

# [Feature Title]

## What We're Building

[2-3 sentences describing the feature from user's perspective]

## Why This Approach

**Chosen approach:** [Name/summary]

**Rationale:**
- [Key reason 1]
- [Key reason 2]

**Trade-offs accepted:**
- [Trade-off 1]

## Key Decisions

- [Decision 1]: [Brief rationale]
- [Decision 2]: [Brief rationale]

## Approaches Considered

### [Approach 1 - Chosen]
[Brief description, why chosen]

### [Approach 2 - Rejected]
[Brief description, why rejected]

## Open Questions

- [Question 1]
- [Question 2]

## Next Steps

Run `/workflows:plan` to create spec.md and prd.json in this folder.
```

### Phase 5: Handoff

Use **AskUserQuestion tool** to present next steps:

**Question:** "Brainstorm captured at `docs/plans/YYYY-MM-DD-<type>-<name>/brainstorm.md`. What would you like to do next?"

**Options:**
1. **Proceed to planning** - Run `/workflows:plan` (will auto-detect this brainstorm)
2. **Refine design further** - Continue exploring
3. **Done for now** - Return later

## Output Summary

When complete, display:

```
Brainstorm complete!

Folder: docs/plans/YYYY-MM-DD-<type>-<name>/
  brainstorm.md  ← created

Key decisions:
- [Decision 1]
- [Decision 2]

Next: Run `/workflows:plan` to create spec.md and prd.json
```

## Important Guidelines

- **Stay focused on WHAT, not HOW** - Implementation details belong in the plan
- **Ask one question at a time** - Don't overwhelm
- **Apply YAGNI** - Prefer simpler approaches
- **Keep outputs concise** - 200-300 words per section max
- **Use the final folder name** - Same folder will hold spec.md and prd.json later

NEVER CODE! Just explore and document decisions.
