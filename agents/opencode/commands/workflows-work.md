---
description: "Execute work plans efficiently while maintaining quality and finishing features"
agent: build
---

# Work

Description: Execute work plans efficiently while maintaining quality and finishing features

Arguments: `[plan folder path, e.g., docs/plans/2026-01-30-feat-user-auth/] [--swarm]`

Preferred workflow: `workflows-work`


<input> $ARGUMENTS </input>

This command is a wrapper. Its body is the `workflows-work` skill, which is in the
Skillhub library. Do not load it with the skill tool.

Load the skill through the Executor MCP server, then execute it:

```
tool: call
input: {"calls": {"path": "tools.skillhub.read", "input": {"name": "workflows-work"}}}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the input above to the skill.
