---
description: "Remove AI slop from code (branch) or writing (edit/detect)"
agent: build
---

# Deslop

Description: Remove AI slop from code (branch) or writing (edit/detect)

Arguments: `[optional: file path | paste draft | is this AI?]`

Preferred workflow: `deslop`


<target> $ARGUMENTS </target>

Always load and execute the `deslop` workflow/skill for this command.

Do not answer directly from this wrapper; the skill is the command body.
Pass the target above to the skill.

Routing is in the skill: code (branch/file), write (draft), or detect
("is this AI" / audit without rewrite).
