# Audit a Skill

Read [structure](../references/skill-structure.md) and [verification](verify-skill.md). Use the named target; enumerate candidates only when selection is unresolved.

## Inspect

Read the entrypoint, supporting resources, executable helpers, and relevant callers. Track unread or inaccessible files. Check metadata, naming, actual links, Markdown fences, authorization, route selection, runtime assumptions, duplicated rules, and error behavior.

The entrypoint validator does not inspect all references or execute workflows. Use a separate all-resource link check and semantic review. Distinguish harmless hypothetical examples from broken required resources.

## Verify

Use the verification workflow for external APIs, scripts, and behavior. Record structural, semantic, local execution, and live integration coverage separately. A high structural score cannot stand in for runtime correctness.

## Report and repair

Present concrete findings with path, consequence, and evidence. Apply verified fixes when repair is already authorized, then re-run affected checks. An audit-only request produces findings without unnecessary edits or files.

Complete when the declared scope is accounted for, confirmed defects are addressed within authorization, and remaining unverified checks are explicit.
