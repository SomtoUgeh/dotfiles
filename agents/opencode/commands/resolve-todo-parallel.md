---
description: "Resolve all pending CLI todos using parallel processing"
agent: build
---

# Resolve Todo Parallel

Description: Resolve all pending CLI todos using parallel processing

Arguments: `[optional: specific todo ID or pattern]`

Preferred workflow: `resolve-todo-parallel`


<target> $ARGUMENTS </target>

Always load and execute the `resolve-todo-parallel` workflow/skill for this command.

Do not answer directly from this wrapper; the skill is the command body.
Pass the target above to the skill.
