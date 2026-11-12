---
description: "Shape a feature through collaborative R/S/fit-check dialogue before planning implementation"
agent: build
---

# Brainstorm

Description: Shape a feature through collaborative R/S/fit-check dialogue before planning implementation

Arguments: `[feature idea or problem to explore]`

Preferred workflow: `workflows-brainstorm`


<feature_description> $ARGUMENTS </feature_description>

This command is a wrapper. Its body is the `workflows-brainstorm` skill, which is in the
Skillhub library. Do not load it with the skill tool.

Load the skill through the Executor MCP server, then execute it:

```
tool: call
input: {"calls": {"path": "tools.skillhub.read", "input": {"name": "workflows-brainstorm"}}}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the feature description above to the skill.
