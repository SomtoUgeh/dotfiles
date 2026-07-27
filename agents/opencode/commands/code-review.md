---
description: "Code review: closeout (default), axes (Standards+Spec), or full (workflows-review)"
agent: build
---

# Code review

Description: Code review closeout, axes, or full exhaustive hand-off

Arguments: `[closeout|axes|full] [--base ref] [--max-priority P0|P1|P2|P3] [target]`

Preferred workflow: `code-review`


<target> $ARGUMENTS </target>

Always load and execute the `code-review` workflow/skill for this command.

Do not answer directly from this wrapper; the skill is the command body.
Pass the target above to the skill.

Modes: **closeout** (default ship gate), **axes** (Standards + Spec),
**full** (hands off to workflows-review).
