---
description: "Remove AI slop from code (branch) or writing (edit/detect)"
argument-hint: "[optional: file path | paste draft | is this AI?]"
---

# Deslop

<target> $ARGUMENTS </target>

This command is a wrapper. Its body is the deslop skill, which is in the
skill library and not on this disk. Do not call the Skill tool for it.

Load the skill with the Executor MCP server's `skills` tool, then execute it:

```
tool: skills
input: {"app": "skills", "name": "deslop"}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the target above to the skill.

Routing is in the skill: code (branch/file), write (draft), or detect
("is this AI" / audit without rewrite).
