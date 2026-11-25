---
description: "Transform feature descriptions into well-structured specs and executable PRDs"
argument-hint: "[feature description, bug report, or improvement idea]"
---

# Plan

<feature_description> $ARGUMENTS </feature_description>

This command is a wrapper. Its body is the workflows-plan skill, which is in the
skill library and not on this disk. Do not call the Skill tool for it.

Load the skill with the Executor MCP server's `skills` tool, then execute it:

```
tool: skills
input: {"app": "skills", "name": "workflows-plan"}
```

When the skill names another file of its folder, read that file with the same
call and `"file": "<path>"` in the input.

Do not answer directly from this wrapper; the skill is the command body. If
you cannot load the skill, say so and stop: do not do the task without it.
Pass the feature description above to the skill.
