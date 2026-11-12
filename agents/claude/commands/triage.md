---
description: "Triage and categorize findings for the CLI todo system"
argument-hint: "[findings list or source type]"
---

# Triage

<target> $ARGUMENTS </target>

This command is a wrapper. Its body is the file-todos skill, which is in the
Skillhub library and not on this disk. Do not call the Skill tool for it.

Load the skill through the Executor MCP server, then execute it:

```
tool: call
input: {"calls": {"path": "tools.skillhub.read", "input": {"name": "file-todos"}}}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Use the triage mode of the skill.
Pass the target above to the skill.
