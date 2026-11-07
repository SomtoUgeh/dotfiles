#!/usr/bin/env bash
# Executor 2 for Claude on a project VM, the same two entries as julds
# (docs/boat-t3-workspace.md, "MCP gateways"):
#   executor_v2        cloud Executor (executor-v2.julds.com), token ~/.config/executor-v2/cloud.token
#   executor_v2_local  the Mac's Executor on 127.0.0.1:4312 through a boat reverse tunnel
#                      (Mac: julds-executor-bridge <sandbox id> no), key ~/.config/executor-v2/mac.token
# Both tokens are boat environment secret files:
#   boat env set-file <env> .config/executor-v2/cloud.token   (and mac.token)
# Runs as `user`. Idempotent.
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
mkdir -p "$HOME/.local/bin"

npm install -g --prefix "$HOME/.local" --no-fund --no-audit --loglevel=error mcp-remote@0.13.5

wrapper() { # <name> <url> <token file> [extra mcp-remote args]
  local name=$1 url=$2 token=$3
  shift 3
  cat >"$HOME/.local/bin/$name" <<W
#!/bin/sh
# Stdio bridge to Executor 2 at $url. Written by devvm-executor.sh.
T=\$(cat "\$HOME/.config/executor-v2/$token")
exec "\$(command -v node || echo /usr/local/bin/node)" "\$HOME/.local/lib/node_modules/mcp-remote/dist/proxy.js" $url --transport http-only $* --header "Authorization: Bearer \$T"
W
  chmod 755 "$HOME/.local/bin/$name"
}
wrapper executor-v2-mcp https://executor-v2.julds.com/mcp cloud.token
wrapper executor-v2-mac-mcp http://127.0.0.1:4312/mcp mac.token --allow-http

chmod 700 "$HOME/.config/executor-v2"
chmod 600 "$HOME"/.config/executor-v2/*.token
for n in executor_v2:executor-v2-mcp executor_v2_local:executor-v2-mac-mcp; do
  claude mcp get "${n%%:*}" >/dev/null 2>&1 || claude mcp add --scope user "${n%%:*}" -- "$HOME/.local/bin/${n#*:}"
done
claude mcp list 2>/dev/null | grep -E '^executor'
