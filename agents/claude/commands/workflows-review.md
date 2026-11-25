---
description: "Perform exhaustive code reviews using multi-agent analysis and dynamic skill discovery"
argument-hint: "[PR number, GitHub URL, branch name, or plan folder path]"
---

# Review

<review_target> $ARGUMENTS </review_target>

This command is a wrapper. Its body is the workflows-review skill, which is in the
skill library and not on this disk. Do not call the Skill tool for it.

Load the skill with the Executor MCP server's `skills` tool, then execute it:

```
tool: skills
input: {"app": "skills", "name": "workflows-review"}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the review target above to the skill.
