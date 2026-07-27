---
description: "Code review: closeout (default), axes (Standards+Spec), or full (workflows-review)"
argument-hint: "[closeout|axes|full] [--base ref] [--max-priority P0|P1|P2|P3] [target]"
---

# Code review

<target> $ARGUMENTS </target>

Always load and execute the code-review skill for this command:

```
skill: code-review
```

Do not answer directly from this wrapper; the skill is the command body.
Pass the target above to the skill.

Modes are defined in the skill: **closeout** (default ship gate), **axes**
(Standards + Spec), **full** (hands off to workflows-review).
