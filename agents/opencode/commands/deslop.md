---
description: "Remove AI-generated code slop from current branch"
agent: build
---

# Deslop

Description: Remove AI-generated code slop from current branch

Arguments: `[optional: specific file path]`

Preferred workflow: `deslop`


<target> $ARGUMENTS </target>

Always load and execute the `deslop` workflow/skill for this command.

Do not answer directly from this wrapper; the skill is the command body.
Pass the target above to the skill.
