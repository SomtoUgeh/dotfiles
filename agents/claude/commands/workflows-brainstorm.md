---
description: "Shape a feature through collaborative R/S/fit-check dialogue before planning implementation"
argument-hint: "[feature idea or problem to explore]"
---

# Brainstorm

<feature_description> $ARGUMENTS </feature_description>

This command is a wrapper. Its body is the workflows-brainstorm skill, which is in the
skill library and not on this disk. Do not call the Skill tool for it.

Load the skill with the Executor MCP server's `skills` tool, then execute it:

```
tool: skills
input: {"app": "skills", "name": "workflows-brainstorm"}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the feature description above to the skill.
