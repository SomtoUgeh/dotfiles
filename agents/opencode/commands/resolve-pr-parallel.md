---
description: "Resolve all PR comments using parallel processing, then extract reusable conventions"
agent: build
---

# Resolve PR Parallel

Description: Resolve all PR comments using parallel processing, then extract reusable conventions

Arguments: `[optional: PR number or current PR]`

Preferred workflow: `resolve-pr-parallel`


<target> $ARGUMENTS </target>

Always load and execute the `resolve-pr-parallel` workflow/skill for this command.

Do not answer directly from this wrapper; the skill is the command body.
Pass the target above to the skill.
