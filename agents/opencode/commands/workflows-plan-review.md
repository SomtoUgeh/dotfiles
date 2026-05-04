---
description: "Founder-mode plan review — stress-test a plan before implementation begins"
agent: build
---

# Plan Review

Description: Founder-mode plan review — stress-test a plan before implementation begins

Arguments: `[plan folder path, PR number, or feature description]`

Preferred workflow: `workflows-plan-review`


## Review Target

<review_target> $ARGUMENTS </review_target>

Always load and execute the `workflows-plan-review` workflow/skill for this command.

Do not answer directly from this wrapper; the skill is the command body.
Pass the review target above to the skill's "Detect Review Target" step.
