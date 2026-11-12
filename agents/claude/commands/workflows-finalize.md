---
description: "Ship-readiness pass: fix, validate, and ship working copy or PR changes. Use after review findings are triaged, or standalone for a final pass before merge."
argument-hint: "[optional: working-copy, pr, or both]"
---

# Finalize

<input> $ARGUMENTS </input>

This command is a wrapper. Its body is the workflows-finalize skill, which is in the
Skillhub library and not on this disk. Do not call the Skill tool for it.

Load the skill through the Executor MCP server, then execute it:

```
tool: call
input: {"calls": {"path": "tools.skillhub.read", "input": {"name": "workflows-finalize"}}}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the input above to the skill.
