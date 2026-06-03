# ============================================================================
# PATH (portable, applies to ALL shells: login, non-login, interactive, non-interactive)
# ============================================================================
# .zshenv runs for every zsh shell, so PATH set here is also seen by:
#   - SSH commands like `ssh host 'gh ...'`
#   - cron jobs
#   - agent-driven non-interactive invocations
# Each entry is dir-guarded (skipped if the dir doesn't exist) and
# duplicate-guarded (skipped if already in PATH), so this is safe to source
# repeatedly and portable across Mac and Linux.
_add_to_path() {
  local d=$1
  [[ -d "$d" ]] || return
  [[ ":$PATH:" == *":$d:"* ]] && return
  export PATH="$d:$PATH"
}

_add_to_path "$HOME/bin"
_add_to_path "$HOME/.local/bin"   # also covers uv, pipx, and the Claude CLI
_add_to_path "$HOME/.bun/bin"
_add_to_path "$HOME/.cargo/bin"

unset -f _add_to_path

# Rust/Cargo (if installed)
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Machine-local secrets; never committed.
[ -f "$HOME/.config/agent-secrets/context7.zsh" ] && . "$HOME/.config/agent-secrets/context7.zsh"

# Remove stale Claude-Warden injector from inherited environments.
if [[ "${NODE_OPTIONS:-}" == *"/Users/swissblock/dev/claude-warden/capture/interceptor.js"* ]]; then
  unset NODE_OPTIONS
fi
