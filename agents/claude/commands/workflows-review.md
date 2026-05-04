---
description: "Perform exhaustive code reviews using multi-agent analysis and dynamic skill discovery"
argument-hint: "[PR number, GitHub URL, branch name, or plan folder path]"
---

# Review

<review_target> $ARGUMENTS </review_target>

Always load and execute the workflows-review skill for this command:

```
skill: workflows-review
```

Do not answer directly from this wrapper; the skill is the command body.
Pass the review target above to the skill.
