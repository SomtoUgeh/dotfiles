---
description: "Enhance a plan with dynamic skill/agent discovery and targeted research"
agent: build
---

# Deepen Plan

Description: Enhance a plan with dynamic skill/agent discovery and targeted research

Arguments: `[path to plan folder, e.g., docs/plans/2026-01-30-feat-user-auth/]`

Preferred workflow: `workflows-deepen-plan`


<plan_path> $ARGUMENTS </plan_path>

This command is a wrapper. Its body is the `workflows-deepen-plan` skill, which is in the
Skillhub library. Do not load it with the skill tool.

Load the skill through the Executor MCP server, then execute it:

```
tool: call
input: {"calls": {"path": "tools.skillhub.read", "input": {"name": "workflows-deepen-plan"}}}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the plan path above to the skill.
