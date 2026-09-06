# Shared Skill Format and Runtime Extensions

The [Agent Skills specification](https://agentskills.io/specification) defines the portable format. A skill directory contains `SKILL.md`, with YAML frontmatter and a Markdown body. The specification does not require XML or any particular headings.

## Portable metadata

- `name`: 1–64 lowercase letters, digits, and hyphens. No leading, trailing, or consecutive hyphens. Match the directory name.
- `description`: nonempty string, at most 1024 characters; describe the operation and its trigger.
- Optional standard fields include `license`, `compatibility`, and string-valued `metadata`.
- `allowed-tools` is an experimental standard field with runtime-dependent support. It is not a portable permission boundary. This shared library leaves tool-specific metadata in native configuration or wrappers.
- Keep `model`, invocation controls, hooks, and dynamic command substitution out of shared skills. Check the target runtime's current schema when building a native wrapper.

## Discovery

Discovery paths and precedence belong to each runtime, not the file format. This repository exposes its canonical shared library through configured links, including `~/.agents/skills`. Do not infer a runtime's native path from that link.

Claude Code uses `.claude/skills` and `~/.claude/skills`; it can load relevant skills automatically or through explicit invocation. Loading a skill does not universally require confirmation. Plugin skills have their own namespace. Other harnesses have different discovery rules.

Consult [RUNTIME_TOOLS.md](../../RUNTIME_TOOLS.md) and the active catalog. Verify the resolved skill path in each supported harness before claiming installation works.

Sources: [Claude Code](https://code.claude.com/docs/en/skills), [OpenCode](https://opencode.ai/docs/skills/), [Grok](https://docs.x.ai/build/features/skills-plugins-marketplaces).

## Body and resources

Use Markdown headings in this shared library. Keep the entrypoint under 500 lines; link directly to relevant workflows, references, scripts, and templates. Examples containing nested fences need a longer outer fence. Quote YAML strings containing placeholders or punctuation that YAML could interpret as collections.

The local validator checks entrypoint structure and its inline local links. It does not prove every reference, command, API, or workflow correct. Review and exercise those separately.
