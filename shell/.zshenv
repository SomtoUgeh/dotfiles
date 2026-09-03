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

# ============================================================================
# 1Password SSH agent
# ============================================================================
# ~/.ssh/config sets IdentityAgent, which covers `ssh` itself — but ssh-add,
# ssh-keygen -Y and other agent-aware tools read SSH_AUTH_SOCK and would
# otherwise talk to Apple's launchd agent and report "no identities".
# Guarded on the socket existing, so the cloud worker (file-based keys, no
# 1Password) and any Linux box are unaffected.
_op_agent="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
[ -S "$_op_agent" ] && export SSH_AUTH_SOCK="$_op_agent"
unset _op_agent

# Machine-local secrets; never committed.
[ -f "$HOME/.config/agent-secrets/context7.zsh" ] && . "$HOME/.config/agent-secrets/context7.zsh"
