# Split a Skill into Workflows

Read [recommended structure](../references/recommended-structure.md). Resolve the requested skill and read all affected content before editing.

1. Identify distinct user intents, shared principles, and reusable domain knowledge. A short single-workflow skill may not need splitting; explain a material conflict with the user's requested direction before changing it.
2. Map every existing supported behavior to its destination so extraction does not lose steps, error handling, or constraints.
3. Move procedures into workflows and knowledge into references. Use Markdown headings and relative links from the containing file.
4. Keep critical constraints and routing in the entrypoint. Route from the existing request; ask only for unresolved intent.
5. Link each resource directly from the entrypoint. Remove duplicate maintained rules and repair callers.
6. Verify all original routes and representative outputs, plus missing-input and unavailable-tool cases. Validate links and metadata separately.

Complete when the split preserves behavior and improves conditional loading without adding mandatory questionnaires.
