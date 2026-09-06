---
name: heal-skill
description: Correct a skill whose instructions, paths, commands, or external API guidance were shown to be wrong or stale.
---

# Heal a Skill

Repair the invoked skill and its supporting resources from concrete failure evidence or current authoritative documentation.

## Runtime and Path Resolution

Use the invoked skill path supplied by the active skill catalog or loader. If it is unavailable, search the configured skill roots and the current repository for an exact `name:` match. Never assume the current directory contains `./skills/<name>`. Use the user's current message and conversation context as inputs; do not depend on harness-specific variables.

For questions, progress tracking, delegation, or related skills, use the active runtime equivalents in [RUNTIME_TOOLS.md](../RUNTIME_TOOLS.md) when available, with a plain-language fallback when a mapped capability is absent.

## Workflow

1. Read the target `SKILL.md` fully, then inspect only the related references, scripts, metadata, and callers needed to understand the failure.
2. State the observed failure, the incorrect instruction, the root cause, affected files, and the proposed correction. Use exact errors and current primary sources where an external contract is involved.
3. Preserve authorization already given. If the user explicitly asked to fix or heal the skill, proceed with in-scope edits without requesting approval again. Ask only when the target is ambiguous, the proposed change conflicts with the user's direction, or a separate external action such as publishing or pushing lacks authorization.
4. Make the smallest complete correction. Update all examples and supporting resources that encode the same wrong behavior.
5. Read back the changed sections, run the skill validator when available, and perform a focused behavioral check for scripts or fragile commands.
6. Report changed files, verification, and any remaining uncertainty. Commit only when the user has authorized a commit.

## Success Criteria

- The exact loaded skill was repaired.
- The correction is supported by failure evidence, repository behavior, or current primary documentation.
- Related examples and references agree with the entrypoint.
- No unrelated files or external systems were changed.
