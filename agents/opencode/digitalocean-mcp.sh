#!/usr/bin/env bash
# Start the DigitalOcean MCP server with a token from 1Password.
# Field name is `token` (1Password Shell Plugins). Do not print the secret.
set -euo pipefail

PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"
REF="${DIGITALOCEAN_OP_REF:-op://Personal/DigitalOcean API Token/token}"

token="$(op read "$REF")"
if [ -z "$token" ]; then
  echo "digitalocean-mcp: failed to read $REF" >&2
  exit 1
fi

export DIGITALOCEAN_API_TOKEN="$token"
export DIGITALOCEAN_ACCESS_TOKEN="$token"
unset token

exec npx -y @digitalocean/mcp --services accounts,droplets,networking,docs
