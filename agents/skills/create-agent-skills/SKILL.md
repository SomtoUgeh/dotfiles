---
name: create-agent-skills
description: Create, audit, verify, and repair shared agent skills and their scripts, templates, and references across Codex, Claude Code, OpenCode, and Grok. Use when authoring or maintaining SKILL.md resources.
---

# Create and Maintain Agent Skills

Use YAML frontmatter and Markdown headings. Keep portable instructions in the shared skill and native model/tool configuration in each harness. Resolve tools and paths through [RUNTIME_TOOLS.md](../RUNTIME_TOOLS.md).

## Working Rules

- Use the current request to choose the target and workflow. Ask only for material missing context; preserve existing authorization.
- Search existing skills and native capabilities before adding another owner.
- Read affected files fully before editing. Keep useful constraints and supported behavior when restructuring.
- Verify external contracts against installed/project versions, matching released packages, and current primary documentation. A skill's “latest” label is not evidence.
- Keep `SKILL.md` under 500 lines and link directly to conditional resources. Instructions in references must agree with the entrypoint.
- Structural validation, semantic review, local execution, and live integration are different checks. State which passed and which remain unverified.

## Workflows

| Request | Read |
| --- | --- |
| Create a skill | [Create new skill](workflows/create-new-skill.md) |
| Create a domain skill | [Domain skill](workflows/create-domain-expertise-skill.md) |
| Audit structure and consistency | [Audit](workflows/audit-skill.md) |
| Verify facts and behavior | [Verify](workflows/verify-skill.md) |
| Add a reference | [Reference](workflows/add-reference.md) |
| Add a helper script | [Script](workflows/add-script.md) |
| Add an output template | [Template](workflows/add-template.md) |
| Add a workflow | [Workflow](workflows/add-workflow.md) |
| Split an existing skill | [Router extraction](workflows/upgrade-to-router.md) |
| Discuss skill design | [Guidance](workflows/get-guidance.md) |

## Authoring Tools

Resolve these paths from the actual installed skill directory. The configured `~/.agents/skills` link is used below. Replace example names and output paths.

```bash
uv run python ~/.agents/skills/create-agent-skills/scripts/init_skill.py example-skill --path /chosen/skill-root
uv run --script ~/.agents/skills/create-agent-skills/scripts/quick_validate.py /chosen/skill-root/example-skill
uv run --script ~/.agents/skills/create-agent-skills/scripts/package_skill.py /chosen/skill-root/example-skill /chosen/output
```

The initializer creates a parseable scaffold, not finished guidance. Replace TODOs and remove unused examples. The validator checks entrypoint metadata, length, and inline local links; it does not prove reference or workflow correctness. Packaging is only needed when distribution is requested. The packager rejects symlinks and excludes its own output, `.git`, and Python caches; inspect all remaining members before distribution.

Run the tools' isolated regression tests with:

```bash
uv run --script ~/.agents/skills/create-agent-skills/scripts/test_skill_tools.py
```

## References and Templates

- [Format and runtime extensions](references/official-spec.md)
- [Structure](references/skill-structure.md) and [layout choices](references/recommended-structure.md)
- [Core principles](references/core-principles.md) and [best practices](references/best-practices.md)
- [Clear instructions](references/be-clear-and-direct.md) and [common patterns](references/common-patterns.md)
- [API credentials](references/api-security.md)
- [Executable helpers](references/executable-code.md) and [script integration](references/using-scripts.md)
- [Templates](references/using-templates.md)
- [Testing and iteration](references/iteration-and-testing.md)
- [Validation and recovery](references/workflows-and-validation.md)
- [Simple scaffold](templates/simple-skill.md) and [router scaffold](templates/router-skill.md)

## Completion

The declared workflows and resources agree, relevant behavior checks pass, and the result works in the environments actually tested. Report remaining project, device, account, or harness checks precisely. Do not commit, push, or publish without authorization.
