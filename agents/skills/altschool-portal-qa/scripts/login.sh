#!/usr/bin/env bash
# Login to Portal or Core using an encrypted agent-browser auth profile.
# Never accepts a password argument. Never prints profile JSON.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: login.sh --app portal|core --target prod|local|preview [--profile NAME]

Logs in with agent-browser auth login. Passwords stay in the encrypted
profile (or 1Password --password-stdin when saving a profile separately).

  --app       portal (student) or core (admin)
  --target    prod, local (Caddy HTTPS), or preview (trycloudflare)
  --profile   override encrypted auth profile name
  --session   agent-browser session (default: portal-qa)
EOF
}

app=""
target=""
profile_override=""
session="${AGENT_BROWSER_SESSION:-portal-qa}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      app="${2:-}"
      shift 2
      ;;
    --target)
      target="${2:-}"
      shift 2
      ;;
    --profile)
      profile_override="${2:-}"
      shift 2
      ;;
    --session)
      session="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --password|--password=*|-p)
      printf 'login.sh refuses password flags. Save an encrypted profile with --password-stdin.\n' >&2
      exit 2
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$app" || -z "$target" ]]; then
  usage >&2
  exit 2
fi
if [[ "$app" != "portal" && "$app" != "core" ]]; then
  printf 'app must be portal or core\n' >&2
  exit 2
fi
if [[ "$target" != "prod" && "$target" != "local" && "$target" != "preview" ]]; then
  printf 'target must be prod, local, or preview\n' >&2
  exit 2
fi

if ! command -v agent-browser >/dev/null 2>&1; then
  printf 'agent-browser is required\n' >&2
  exit 1
fi

origin=""
profile=""

case "$app-$target" in
  portal-prod)
    origin="https://portal.altschoolafrica.com"
    profile="altschool-portal-diagnosis"
    ;;
  portal-local)
    origin="https://portal-altschool.localhost"
    profile="altschool-portal-local"
    ;;
  core-local)
    origin="https://core-altschool.localhost"
    profile="altschool-core-local"
    ;;
  core-prod)
    origin="${ALTSCHOOL_CORE_PROD_ORIGIN:-}"
    profile="altschool-core-diagnosis"
    if [[ -z "$origin" ]]; then
      printf 'core production origin is not recorded in this skill. Set ALTSCHOOL_CORE_PROD_ORIGIN and use --profile if needed.\n' >&2
      exit 2
    fi
    ;;
  portal-preview|core-preview)
    preview_file="${HOME}/.altschool-preview.json"
    if [[ ! -s "$preview_file" ]]; then
      printf 'preview target requires %s from bun run dev:preview\n' "$preview_file" >&2
      exit 1
    fi
    key="$app"
    [[ "$app" == "portal" ]] && key="student"
    origin="$(python3 - "$preview_file" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
data = json.load(open(path))
url = None
if isinstance(data, dict):
    if isinstance(data.get(key), str):
        url = data[key]
    elif isinstance(data.get("apps"), dict):
        item = data["apps"].get(key)
        if key == "student":
            item = item or data["apps"].get("portal")
        if isinstance(item, str):
            url = item
        elif isinstance(item, dict):
            url = item.get("url") or item.get("origin")
    elif isinstance(data.get("urls"), dict):
        url = data["urls"].get(key)
if not url:
    sys.stderr.write("could not resolve preview origin from known keys\n")
    sys.exit(1)
print(url.rstrip("/"))
PY
)"
    profile="altschool-portal-diagnosis"
    [[ "$app" == "core" ]] && profile="altschool-core-local"
    ;;
esac

if [[ -n "$profile_override" ]]; then
  profile="$profile_override"
fi
signin="${origin}/auth/signin"

if ! agent-browser auth list 2>/dev/null | grep -q "$profile"; then
  printf 'missing auth profile %s. Create it with auth save --password-stdin from a 1Password item.\n' "$profile" >&2
  exit 1
fi

enc_key="${AGENT_BROWSER_HOME:-$HOME/.agent-browser}/.encryption-key"
if [[ -z "${AGENT_BROWSER_ENCRYPTION_KEY:-}" && -f "$enc_key" ]]; then
  AGENT_BROWSER_ENCRYPTION_KEY="$(tr -d '\n' < "$enc_key")"
  export AGENT_BROWSER_ENCRYPTION_KEY
fi

persist_name="altschool-${app}-${target}"

printf 'login %s %s via profile %s (session %s)\n' "$app" "$origin" "$profile" "$session"

agent-browser --session "$session" --session-name "$persist_name" open "$signin"
agent-browser --session "$session" wait --load networkidle
agent-browser --session "$session" auth login "$profile"
agent-browser --session "$session" wait --load networkidle

url="$(agent-browser --session "$session" get url 2>/dev/null || true)"
printf 'url %s\n' "$url"

case "$url" in
  */auth/signin*)
    printf 'still on sign-in — login did not complete. Snapshot the form; do not dump credentials.\n' >&2
    agent-browser --session "$session" snapshot -i || true
    exit 1
    ;;
esac

printf 'login completed (url is not /auth/signin)\n'
