---
description: "Remove AI slop from code (branch) or writing (edit/detect)"
agent: build
---

# Deslop

Description: Remove AI slop from code (branch) or writing (edit/detect)

Arguments: `[optional: file path | paste draft | is this AI?]`

Preferred workflow: `deslop`


<target> $ARGUMENTS </target>

This command is a wrapper. Its body is the `deslop` skill, which is in the
Skillhub library. Do not load it with the skill tool.

Load the skill through the Executor MCP server, then execute it:

```
tool: call
input: {"calls": {"path": "tools.skillhub.read", "input": {"name": "deslop"}}}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the target above to the skill.

Routing is in the skill: code (branch/file), write (draft), or detect
("is this AI" / audit without rewrite).
