---
description: "Code review: closeout (default), axes (Standards+Spec), or full (workflows-review)"
agent: build
---

# Code review

Description: Code review closeout, axes, or full exhaustive hand-off

Arguments: `[closeout|axes|full] [--base ref] [--max-priority P0|P1|P2|P3] [target]`

Preferred workflow: `code-review`


<target> $ARGUMENTS </target>

This command is a wrapper. Its body is the `code-review` skill, which is in the
Skillhub library. Do not load it with the skill tool.

Load the skill through the Executor MCP server, then execute it:

```
tool: call
input: {"calls": {"path": "tools.skillhub.read", "input": {"name": "code-review"}}}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the target above to the skill.

Modes: **closeout** (default ship gate), **axes** (Standards + Spec),
**full** (hands off to workflows-review).
