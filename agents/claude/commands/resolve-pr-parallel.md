---
description: "Resolve all PR comments using parallel processing, then extract reusable conventions"
argument-hint: "[optional: PR number or current PR]"
---

# Resolve PR Parallel

<target> $ARGUMENTS </target>

This command is a wrapper. Its body is the resolve-pr-parallel skill, which is in the
skill library and not on this disk. Do not call the Skill tool for it.

Load the skill with the Executor MCP server's `skills` tool, then execute it:

```
tool: skills
input: {"app": "skills", "name": "resolve-pr-parallel"}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the target above to the skill.
