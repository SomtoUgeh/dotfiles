# Core Authoring Principles

1. State the task, scope, and observable outcome. Preserve the user's instructions and authorization across workflow boundaries.
2. Give only the context the agent needs. Prefer one maintained rule to copies that can disagree.
3. Use YAML plus Markdown, as defined in [skill-structure.md](skill-structure.md). XML is not required and has no established general token-efficiency advantage.
4. Match detail to fragility: exact validated sequences for migrations or destructive operations; decision criteria for design and investigation.
5. Keep critical constraints in the entrypoint. Load conditional procedures and domain references only when relevant.
6. Use available tools and the model selected by the harness. Do not impose provider-specific models, roles, or commands in portable instructions.
7. Verify released APIs and installed versions. A live documentation page can describe an unreleased API.
8. Define failure behavior: do not turn missing input, permission errors, partial reads, or failed cleanup into success.
9. Evaluate behavior with representative positive, negative, and failure cases. Report the actual runtime/model and which checks were executed.

A workflow should be complete for its declared scope. It need not attempt every possible task in an entire domain. See [iteration-and-testing.md](iteration-and-testing.md).
