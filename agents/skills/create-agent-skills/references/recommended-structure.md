# Choosing a Skill Structure

Use a single entrypoint for one short workflow. Use a router when distinct user intents need different procedures. A line-count threshold alone does not justify a router.

```text
skill-name/
  SKILL.md
  workflows/       # optional procedures
  references/      # optional domain knowledge
  scripts/         # optional executable helpers
  templates/       # optional output structures
```

Keep constraints that apply to every workflow inline. Infer the route from the user's request; ask only when a material ambiguity remains. Do not require the user to select an option they already named.

Each workflow contains its required reading, steps, verification, and completion criteria. Link to it from the entrypoint. Each reference contains reusable facts with sources, compatibility limits, and complete examples where appropriate.

Use the [simple template](../templates/simple-skill.md) or [router template](../templates/router-skill.md). Replace placeholders and remove irrelevant sections before delivery. Route only to existing resources, and retain all supported behavior when splitting an existing skill.
