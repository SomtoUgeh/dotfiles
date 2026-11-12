#!/usr/bin/env bash
# Give a project VM Somto's shared agent setup from the dotfiles repo: skills,
# Claude and Codex instructions, settings, output styles, agents, commands and
# hooks. Same links as install.sh on the Mac and the julds runbook
# (docs/boat-t3-workspace.md). Runs as `user`. Idempotent: devvm-setup.sh runs
# it once, and agent-config-sync.timer runs it after each boot and every hour,
# so skills pushed from the Mac reach the VM without a manual step.
set -euo pipefail
# `bun link` puts the skillhub command into ~/.bun/bin, which is not in the timer's PATH.
export PATH=$HOME/.bun/bin:$HOME/.local/bin:$PATH
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

# No Skillhub on this VM: the neutral path for Codex, and one link per skill
# in ~/.claude/skills so boat's own `boat` and `synced` folders stay where
# boat puts them.
link_every_skill() {
  local s b t
  link "$A/skills" "$HOME/.agents/skills"
  for s in "$A"/skills/*/; do
    b=$(basename "$s")
    case $b in boat | synced) continue ;; esac
    t=$HOME/.claude/skills/$b
    if [ -e "$t" ] && [ ! -L "$t" ]; then continue; fi
    ln -sfn "${s%/}" "$t"
  done
  find "$HOME/.claude/skills" -maxdepth 1 -xtype l -delete
  skills="$(find "$HOME/.claude/skills" -maxdepth 1 -type l | wc -l) skills linked"
}

# Skillhub manages this VM: the tools load skills from the library through
# Executor, and only the active skills are in the tool folders. Remove the
# links that an earlier run of this script made, keep the links that Skillhub
# owns and boat's own folders, then let Skillhub put the active set in place.
leave_skills_to_skillhub() {
  local owned t name removed=0 neutral=$HOME/.agents/skills
  # A real folder there is an adopted one. Keep it.
  if [ ! -d "$neutral" ] || [ -L "$neutral" ]; then link "$A/skills" "$neutral"; fi
  skills="skills left as they are"
  # Skillhub does not guess what it owns when the ledger is damaged. Nor does this script.
  if ! owned=$(jq -r --arg f "$HOME/.claude/skills" '.folders[$f].entries // {} | keys[]' "$ledger" 2>/dev/null); then
    echo "link-agent-config: cannot read $ledger; the skill links are left as they are" >&2
    return
  fi
  for t in "$HOME"/.claude/skills/*; do
    [ -L "$t" ] || continue
    name=$(basename "$t")
    [ "$(readlink "$t")" = "$A/skills/$name" ] || continue
    if grep -qxF -- "$name" <<<"$owned"; then continue; fi
    rm "$t"
    removed=$((removed + 1))
  done
  skills="skills left to Skillhub ($removed links of this script removed)"
  if ! command -v skillhub >/dev/null; then
    echo "link-agent-config: the skillhub command is not on the path; the active skills were not synced" >&2
    return
  fi
  # Codex reads the neutral path. As one link to the shared folder it shows
  # every skill. The adopt makes it a real folder with only the active skills.
  # `skillhub uninstall --yes` puts the link back.
  if [ -L "$neutral" ] && ! skillhub adopt "$neutral" --yes; then
    echo "link-agent-config: skillhub adopt of ~/.agents/skills did not complete" >&2
  fi
  # An adopt that changes nothing does not sync, so the sync always runs.
  if ! skillhub sync; then
    echo "link-agent-config: skillhub sync failed; the active skills are as the last sync left them" >&2
  fi
}

# Shared skills. The first `skillhub sync` on this VM writes the ledger, and
# from then on Skillhub delivers the skills. `skillhub uninstall --yes` removes
# the ledger, and the next run links every skill again.
ledger=${SKILLHUB_HOME:-$HOME/.skillhub}/managed.json
mkdir -p "$HOME/.claude/skills"
if [ -f "$ledger" ]; then leave_skills_to_skillhub; else link_every_skill; fi

# Claude Code
link "$A/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
link "$A/shared/ETHOS.md" "$HOME/.claude/ETHOS.md"
link "$A/claude/settings.json" "$HOME/.claude/settings.json"
link "$A/claude/commands" "$HOME/.claude/commands"
link "$A/claude/agents" "$HOME/.claude/agents"
link "$A/claude/output-styles" "$HOME/.claude/output-styles"
link "$A/shared/hooks/git_guard.py" "$HOME/.claude/hooks/git_guard.py"
link "$A/skills/shaping" "$HOME/.claude/hooks/shaping"
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

This is a boat project VM for one project. Several agents share it (8 vCPU, 16 GB).

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

echo "link-agent-config: $skills, dotfiles $(git -C "$D" rev-parse --short HEAD)"
