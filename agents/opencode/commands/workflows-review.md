---
description: "Perform exhaustive code reviews using multi-agent analysis and dynamic skill discovery"
agent: build
---

# Review

Description: Perform exhaustive code reviews using multi-agent analysis and dynamic skill discovery

Arguments: `[PR number, GitHub URL, branch name, or plan folder path]`

Preferred workflow: `workflows-review`


<review_target> $ARGUMENTS </review_target>

Always load and execute the `workflows-review` workflow/skill for this command.

Do not answer directly from this wrapper; the skill is the command body.
Pass the review target above to the skill.
