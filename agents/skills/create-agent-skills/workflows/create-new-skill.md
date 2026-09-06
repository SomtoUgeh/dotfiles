# Create a New Skill

Read [structure](../references/skill-structure.md) and [core principles](../references/core-principles.md).

1. Use the user's task, intended runtimes, and supplied examples to define scope and observable success. Ask only for missing information that materially changes the skill.
2. Search existing skills and native capabilities. Extend an appropriate owner when authorized rather than creating a conflicting duplicate.
3. Research external contracts using current primary documentation and matching released packages. Keep installed/project versions distinct from registry latest. Do not ask permission for necessary read-only research.
4. Choose a single workflow or a router according to [recommended structure](../references/recommended-structure.md). A router is useful for distinct tasks, not a required upgrade.
5. Resolve the requested installation root. In this dotfiles setup, `~/.agents/skills` is a configured canonical-library link; verify it before writing. Use a temporary directory when testing.
6. Run the initializer when useful, replacing the example name/path:

```bash
uv run python ~/.agents/skills/create-agent-skills/scripts/init_skill.py example-skill --path /chosen/skill-root
```

7. Replace TODOs with a quoted descriptive YAML string and useful Markdown instructions. Remove unused example resources. Write complete workflows and directly linked references only where needed.
8. Validate the skill, then execute representative success and failure cases. See [verify-skill.md](verify-skill.md). A passing scaffold only proves structure; unfinished TODOs are not a completed skill.
9. Verify discovery in the intended harnesses. Add native wrappers only when required and authorized; do not copy native model/tool metadata into shared content.
10. Package only when distribution was requested. Inspect archive members and test unpacked behavior. The packager rejects symbolic links and excludes its own output, `.git`, and Python caches; inspect for other unintended files yourself.

Complete when the requested skill is usable, examples/resources agree, the performed checks pass, and unverified integrations are named. Preserve existing authorization; no extra “ready to build” gate is required.
