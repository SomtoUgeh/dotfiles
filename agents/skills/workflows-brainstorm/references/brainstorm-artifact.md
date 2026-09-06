# Brainstorm artifact

Read this reference only when saving an authorized shaping result.

Use the repository's established format when one exists. Otherwise write:

```markdown
---
shaping: true
title: <feature title>
type: <feat|fix|refactor>
date: <YYYY-MM-DD>
status: brainstorm
---

# <Feature title>

## Frame

### Source

<Verbatim source material only when the user asked to preserve it. Omit this section otherwise.>

### Problem

<Pain or failure without assuming a solution.>

### Outcome

<Stakeholder-level success.>

## Requirements

| ID | Requirement | Type | Status |
| --- | --- | --- | --- |
| R0 | <full, testable requirement> | <FR|BR|NFR or blank> | Core goal |

## Assumptions

- <Explicit assumption, or "None">

## Open questions

- <Question and whether it blocks planning, or "None">

## Shapes

### A: <descriptive title>

| Part | Mechanism | Flag |
| --- | --- | :---: |
| A1 | <concrete mechanism> | |

<Repeat only for materially different shapes. Add a diagram only when it clarifies flow or wiring.>

## Fit check

| Req | Requirement | Status | A | B |
| --- | --- | --- | :---: | :---: |
| R0 | <full requirement> | Core goal | ✅ | ❌ |

<Put concise failure explanations below the table.>

## Selected shape

**Shape <letter>: <title>**

### Unresolved

- <Flagged unknown and its resolution path, or "None">

## Next step

<The authorized planning handoff, or the next decision the user must make.>
```

Keep the artifact consistent with the active shaping session. Do not add duplicate Open Questions sections, placeholder examples, or a planning handoff the user did not request.
