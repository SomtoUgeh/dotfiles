# Agents

Agent configuration for Claude Code, Codex, OpenCode, and Grok.

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

Cloudflare guidance comes only from this shared library. Do not also install
the Cloudflare skill plugin in individual tools. `agents-sdk` covers agent
building and MCP servers; `sandbox-stable`, `sandbox-next`, and the migration
skill cover the Sandbox SDK. The direct Cloudflare MCP connection is configured
separately and does not require the skill plugin.

Keep one default owner for overlapping skills:

- Shared React guidance contains the full 64-rule set; the Build Web Apps copy
  is disabled. Update the shared index, rule files, and compiled guide together.
- Shared `frontend-design` replaces the standalone Claude frontend-design
  plugin, which is disabled in the tracked Claude and Codex settings.
- Shared `image-to-code` owns screenshot implementation; Product Design's
  other workflows and tools remain available.
- Figma's native design-to-code skill owns its integration. Shared
  `implement-design` is a short fallback for tools without that skill.
- The dedicated Stripe plugin owns Stripe guidance; the older Build Web Apps
  copy is disabled. Shared instructions also load the tracked
  [Stripe compatibility reference](skills/research/references/stripe-compatibility.md)
  for version, SDK, and browser/server compatibility corrections. It overrides
  stale bundled examples without changing the installed plugin.

See [skill ownership](skills/RUNTIME_TOOLS.md#skill-ownership) for routing and
explicit user-choice overrides. Keep installed plugin files unmodified so
upgrades retain their tools, templates, and other skills.

The shared library also keeps one entry point for delegation
(`efficient-frontier`), research (`research`), general motion (`animate`), UI
polish (`emil-design-engineering`), and file todos (`file-todos`, including
triage). `shaping` owns problem definition; `workflows-brainstorm` is a short
save-and-handoff wrapper. Specialized motion skills and planning stages keep
their separate jobs. The Claude and OpenCode `/triage` commands invoke file-todos triage
mode; it does not define another lifecycle.

The installer links it to:

- `~/.agents/skills` for Codex discovery (and as a shared agent-compatible path)
- `~/.claude/skills` for Claude Code's native skill path
- `~/.config/opencode/skills` for OpenCode's native skill path
- `~/.grok/AGENTS.md` for Grok's global instructions; Grok reads skills from
  the neutral path (the cloud installer also links its native skill path)

Model versions belong in each tool's configuration. Shared instructions and
skills use the selected model and describe roles and required capabilities.
See [runtime equivalents](skills/RUNTIME_TOOLS.md) for tool-specific mappings.

Codex config stays host-local. `uv run --script scripts/sync_agent_config.py`
(from the repository root) adds missing template defaults while preserving
existing model choices, MCP/plugin settings, comments, and hook trust records.
It refreshes the managed Git/shaping hooks, preserves custom hooks, and removes
the retired plannotator Stop hook. Changed files get private backups and atomic
replacement. `--check` previews changes without writing. Updated hook definitions
may need review through Codex's native trust interface; the script never grants
trust. New sessions pick up shared instruction changes.

The same sync discovers the installed paths for the three overlapping Codex
plugin skills and disables only those copies. Codex's name selector would also
disable same-named skills from other sources, so these overrides use paths.
Rerun the sync after plugin upgrades to cover new versioned cache paths.
Existing explicit per-path choices are preserved. Plugin caches are never
edited, and the plugins' other skills and tools stay enabled.
Stripe compatibility corrections live in the shared repository and remain in
force after plugin updates; there is no cache patch to reapply.

The Git guard uses a pinned shell parser through `uv`; it checks literal commands
and substitutions independently. It is a tripwire, not a sandbox for aliases or
arbitrary interpreter code. The installer warms its environment before use.
The shaping hook accepts both file edits and multi-file patch payloads.

Run `uv run --script tests/test_agent_setup.py` for hook/config regression
tests and shared skill validation; `bun tests/test_agent_hooks.mjs` checks the
OpenCode adapters. Existing unrelated local settings and
`~/.codex/skills` remain outside the shared library's ownership.

OpenCode setup includes:

- `~/.config/opencode/AGENTS.md`
- `~/.config/opencode/opencode.jsonc`
- `~/.config/opencode/agents`
- `~/.config/opencode/commands`
- `~/.config/opencode/skills` → shared `agents/skills`
- `~/.config/opencode/plugins` for local hook plugins

Do not replace `~/.codex/skills`; Codex can keep local-only skills there while
also reading the shared `~/.agents/skills` path.
