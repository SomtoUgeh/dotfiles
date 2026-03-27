---
name: workflows:review
description: Perform exhaustive code reviews using multi-agent analysis and dynamic skill discovery
argument-hint: "[PR number, GitHub URL, branch name, or plan folder path]"
effort: max
---

# Review

<review_target> #$ARGUMENTS </review_target>

Load and execute the review skill:

```
skill: review
```

Pass the review target above to the skill.
