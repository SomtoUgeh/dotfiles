---
description: "Code review: closeout (default), axes (Standards+Spec), or full (workflows-review)"
argument-hint: "[closeout|axes|full] [--base ref] [--max-priority P0|P1|P2|P3] [target]"
---

# Code review

<target> $ARGUMENTS </target>

This command is a wrapper. Its body is the code-review skill, which is in the
Skillhub library and not on this disk. Do not call the Skill tool for it.

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

Modes are defined in the skill: **closeout** (default ship gate), **axes**
(Standards + Spec), **full** (hands off to workflows-review).
