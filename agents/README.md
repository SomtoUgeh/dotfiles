# Agents

Agent configuration for Claude Code, Codex, and OpenCode.

## Layout

- `shared/`: shared instructions with inline ethos, standalone ethos, hook
  scripts, and MCP server inventory.
- `claude/`: Claude Code settings, MCP, plugins, helper scripts, commands, and
  agents. `CLAUDE.md` symlinks to shared instructions.
- `codex/`: Codex instructions, config, and TOML agents.
- `opencode/`: OpenCode instructions, config, commands, and agents.
- `skills/`: shared `SKILL.md` packages exposed at `~/.agents/skills`.

Each tool folder owns real files in that tool's format, except shared
instruction symlinks. Keep shared scripts and server inventory in `shared/`; do
not put tool-specific syntax there.

## Shared Skills

`agents/skills` is the canonical shared skill source.

The installer links it to:

- `~/.agents/skills` for Codex and OpenCode discovery
- `~/.claude/skills` for Claude Code's native skill path
- `~/.codex/hooks.json` and `~/.codex/config.toml` are rendered locally from
  templates so paths use this machine's `$HOME` and dotfiles path.

OpenCode setup includes:

- `~/.config/opencode/AGENTS.md`
- `~/.config/opencode/opencode.jsonc`
- `~/.config/opencode/agents`
- `~/.config/opencode/commands`
- `~/.config/opencode/plugins` for local hook plugins

Do not replace `~/.codex/skills`; Codex can keep local-only skills there while
also reading the shared `~/.agents/skills` path.
