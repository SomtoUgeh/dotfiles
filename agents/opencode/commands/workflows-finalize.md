---
description: "Ship-readiness pass: fix, validate, and ship working copy or PR changes. Use after review findings are triaged, or standalone for a final pass before merge."
agent: build
---

# Finalize

Description: Ship-readiness pass: fix, validate, and ship working copy or PR changes. Use after review findings are triaged, or standalone for a final pass before merge.

Arguments: `[optional: working-copy, pr, or both]`

Preferred workflow: `workflows-finalize`


<input> $ARGUMENTS </input>

Always load and execute the `workflows-finalize` workflow/skill for this command.

Do not answer directly from this wrapper; the skill is the command body.
Pass the input above to the skill.
