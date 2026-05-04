# Rust/Cargo (if installed)
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Machine-local secrets; never committed.
[ -f "$HOME/.config/agent-secrets/context7.zsh" ] && . "$HOME/.config/agent-secrets/context7.zsh"

# Remove stale Claude-Warden injector from inherited environments.
if [[ "${NODE_OPTIONS:-}" == *"/Users/swissblock/dev/claude-warden/capture/interceptor.js"* ]]; then
  unset NODE_OPTIONS
fi
