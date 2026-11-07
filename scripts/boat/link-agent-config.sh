#!/usr/bin/env bash
# Give a project VM Somto's shared agent setup from the dotfiles repo: skills,
# Claude and Codex instructions, settings, output styles, agents, commands and
# hooks. Same links as install.sh on the Mac and the julds runbook
# (docs/boat-t3-workspace.md). Runs as `user`. Idempotent: devvm-setup.sh runs
# it once, and agent-config-sync.timer runs it after each boot and every hour,
# so skills pushed from the Mac reach the VM without a manual step.
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
P=$HOME/code/personal
D=$P/dotfiles
A=$D/agents

clone_or_pull() { # <repo> <dir>
  if [ -d "$2/.git" ]; then
    git -C "$2" pull -q --ff-only || echo "link-agent-config: $2 did not fast-forward; left as is" >&2
  else
    mkdir -p "$(dirname "$2")"
    git clone -q "git@github.com:SomtoUgeh/$1.git" "$2"
  fi
}
clone_or_pull dotfiles "$D"
# The p3 skills are relative links into this repo.
clone_or_pull p3-stack "$P/p3-stack"

link() { # <source> <target>: move a real file aside once, then link
  mkdir -p "$(dirname "$2")"
  if [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; then return; fi
  if [ -e "$2" ] || [ -L "$2" ]; then mv "$2" "$2.backup.$(date +%Y%m%d_%H%M%S)"; fi
  ln -s "$1" "$2"
}

# Shared skills: the neutral path for Codex, and one link per skill in
# ~/.claude/skills so boat's own `boat` and `synced` folders stay where boat
# puts them.
link "$A/skills" "$HOME/.agents/skills"
mkdir -p "$HOME/.claude/skills"
for s in "$A"/skills/*/; do
  b=$(basename "$s")
  case $b in boat | synced) continue ;; esac
  t=$HOME/.claude/skills/$b
  if [ -e "$t" ] && [ ! -L "$t" ]; then continue; fi
  ln -sfn "${s%/}" "$t"
done
find "$HOME/.claude/skills" -maxdepth 1 -xtype l -delete

# Claude Code
link "$A/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
link "$A/shared/ETHOS.md" "$HOME/.claude/ETHOS.md"
link "$A/claude/settings.json" "$HOME/.claude/settings.json"
link "$A/claude/commands" "$HOME/.claude/commands"
link "$A/claude/agents" "$HOME/.claude/agents"
link "$A/claude/output-styles" "$HOME/.claude/output-styles"
link "$A/shared/hooks/git_guard.py" "$HOME/.claude/hooks/git_guard.py"
link "$A/claude/statusline.sh" "$HOME/.claude/statusline.sh"
link "$A/claude/file-suggestion.sh" "$HOME/.claude/file-suggestion.sh"

# Codex
link "$A/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
link "$A/shared/ETHOS.md" "$HOME/.codex/ETHOS.md"
link "$A/codex/agents" "$HOME/.codex/agents"
uv run -q --script "$D/scripts/sync_agent_config.py"

# Rules for this kind of machine. Claude also reads ~/.claude/rules/*.md, so
# they live beside the shared CLAUDE.md instead of replacing it.
mkdir -p "$HOME/.claude/rules"
cat >"$HOME/.claude/rules/boat-project-vm.md" <<'R'
# This machine

This is a boat project VM for one project. Several agents share it (4 vCPU, 8 GB).

- Read the repository's `AGENTS.md` before you work, and follow it.
- Run e2e runs, production builds and any check that takes more than about a
  minute through `boat-check -- <command>`. It runs on a throwaway boat machine
  and prints the output, the time and the cost. Run `boat-check --help` for options.
- Never run the full e2e suite on this machine.
- Keep at most 3 worktrees. Remove a worktree when its work is merged or abandoned.
- When you call `boat` yourself, always pass the sandbox id. `current` does not
  work in scripts.
- Never quote boat prices from memory. Read `boat limits` or the cost line that
  `boat-check` prints.
R

# Keep a copy outside the clone (the timer runs it) and refresh it from dotfiles.
mkdir -p "$HOME/.local/bin"
self=$D/scripts/boat/link-agent-config.sh
if [ -f "$self" ]; then install -m 755 "$self" "$HOME/.local/bin/link-agent-config"; fi
u=$HOME/.config/systemd/user
if [ ! -f "$u/agent-config-sync.timer" ]; then
  export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  mkdir -p "$u"
  printf '[Unit]\nDescription=Pull dotfiles and relink the shared agent config\n[Service]\nType=oneshot\nExecStart=%%h/.local/bin/link-agent-config\n' >"$u/agent-config-sync.service"
  printf '[Unit]\nDescription=Sync the shared agent config after boot and every hour\n[Timer]\nOnBootSec=3min\nOnUnitActiveSec=1h\n[Install]\nWantedBy=timers.target\n' >"$u/agent-config-sync.timer"
  systemctl --user daemon-reload
  systemctl --user enable --now agent-config-sync.timer
fi

echo "link-agent-config: $(find "$HOME/.claude/skills" -maxdepth 1 -type l | wc -l) skills linked, dotfiles $(git -C "$D" rev-parse --short HEAD)"
