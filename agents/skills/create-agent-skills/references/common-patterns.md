# Common Skill Patterns

## Template

Use a template when the output has a stable contract. Distinguish mandatory machine-readable fields from optional presentation sections. Populate from evidence and remove unused placeholders.

## Examples

Pair representative input with expected output. Include a negative or boundary case when the operation is fragile. Examples explain behavior; they do not grant authorization to execute the illustrated commands.

## Conditional routing

Choose a workflow from the current request. For example, route “explain” to an answer and “implement” to an edit workflow. Ask only if the distinction remains material and unresolved. Use [recommended-structure.md](recommended-structure.md) when a router is justified.

## Progressive disclosure

Keep the task contract inline and link directly to conditional resources. Do not force every task to read every reference. Ensure the linked instructions agree with the entrypoint and use real installed paths.

## Validation loop

Validate a candidate result, fix confirmed defects, and rerun affected checks. Stop retrying an unchanged failing operation; investigate the cause. Track coverage and incomplete checks independently from passing checks.

## Runtime-specific syntax

Dynamic command injection, file mentions, slash-command metadata, and MCP tool naming vary by harness. Keep executable loader syntax out of portable examples. Check [RUNTIME_TOOLS.md](../../RUNTIME_TOOLS.md) and the active tool schema rather than assuming a universal naming convention.
