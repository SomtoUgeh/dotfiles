# Get Skill Design Guidance

Use [core principles](../references/core-principles.md) and [recommended structure](../references/recommended-structure.md).

Infer the task, repetition, intended output, and runtime from the current request. Ask only for material missing context. Check whether an existing skill, native capability, or short direct instruction already serves it.

Recommend a simple entrypoint for one short workflow; use a router for distinct supported tasks with shared domain knowledge. Identify essential constraints, conditional references, and any helper whose deterministic behavior matters.

Explain the proposed structure and its tradeoffs. A request for advice alone does not require creating a skill. If creation is already requested, continue with [create-new-skill.md](create-new-skill.md) without asking for the same approval again.

Complete when the user has an actionable answer or the authorized creation work is finished.
