---
name: workflows-brainstorm
description: Save a completed shaping session as a repository brainstorm artifact and hand it off to planning. Use when the user invokes the brainstorm workflow or asks to persist shaped decisions for later planning.
---

# Brainstorm Save and Handoff

This workflow wraps the `shaping` skill. Shaping owns requirements, solution shapes, fit checks, selection, spikes, and slicing decisions; do not reproduce or alter that method here.

## Shape

Use the active or completed shaping result when one exists; the latest save or
handoff request supplies authorization, path, and template choices rather than
a new feature description. For a new topic, use the user's feature request. Ask
what problem to explore only when neither the topic nor a shaping result is available.

Load and follow [`shaping`](../shaping/SKILL.md). If the request is already specified well enough to plan or implement, continue with the user's requested outcome instead of forcing a brainstorm ceremony.

## Save

Create a brainstorm file only when the user authorized a durable artifact or asked to continue through a repository workflow that requires one. Otherwise return the shaped result in the conversation.

Before saving, read [references/brainstorm-artifact.md](references/brainstorm-artifact.md). Follow an existing repository path or template when one is defined. Otherwise use:

```text
docs/plans/YYYY-MM-DD-<type>-<descriptive-kebab-name>/brainstorm.md
```

Use the runtime's current date. Keep the name descriptive and use `feat`, `fix`, or `refactor` when one applies. Add `shaping: true` frontmatter so the repository's consistency hook can recognize the document.

## Hand off

Report the artifact path, requirement count, selected shape, and unresolved unknowns. Continue into planning or implementation only when the user's request authorizes it. Otherwise offer the relevant next step without creating more files, changing branches, staging, committing, pushing, or commenting externally.

When planning is authorized, use the repository's planning workflow or
[`workflows-plan`](../workflows-plan/SKILL.md). Pass the artifact path, confirmed
requirements, selected shape, assumptions, and unresolved items. Continue from
those decisions without repeating shaping; resolve only gaps that block planning.
