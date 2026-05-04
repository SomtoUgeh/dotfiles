# Agents

Agent configuration for Claude Code, Codex, and OpenCode.

## Layout

- `shared/`: shared instructions with inline ethos, standalone ethos, hook
  scripts, and MCP server inventory.
- `claude/`: Claude Code settings, MCP, plugins, helper scripts, commands, and
  agents. `CLAUDE.md` symlinks to shared instructions.
- `codex/`: Codex instructions, config, and TOML agents.
- `opencode/`: OpenCode instructions, config, commands, and agents.

Each tool folder owns real files in that tool's format, except shared
instruction symlinks. Keep shared scripts and server inventory in `shared/`; do
not put tool-specific syntax there.
