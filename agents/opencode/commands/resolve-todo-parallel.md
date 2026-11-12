---
description: "Resolve all pending CLI todos using parallel processing"
agent: build
---

# Resolve Todo Parallel

Description: Resolve all pending CLI todos using parallel processing

Arguments: `[optional: specific todo ID or pattern]`

Preferred workflow: `resolve-todo-parallel`


<target> $ARGUMENTS </target>

This command is a wrapper. Its body is the `resolve-todo-parallel` skill, which is in the
Skillhub library. Do not load it with the skill tool.

Load the skill through the Executor MCP server, then execute it:

```
tool: call
input: {"calls": {"path": "tools.skillhub.read", "input": {"name": "resolve-todo-parallel"}}}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the target above to the skill.
