# Rust/Cargo (if installed)
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Remove stale Claude-Warden injector from inherited environments.
if [[ "${NODE_OPTIONS:-}" == *"/Users/swissblock/dev/claude-warden/capture/interceptor.js"* ]]; then
  unset NODE_OPTIONS
fi
