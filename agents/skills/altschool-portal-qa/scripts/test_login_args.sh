#!/usr/bin/env bash
# Argument and secret-handling checks for login.sh (no live browser).
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
login="$dir/login.sh"
fail=0

expect_status() {
  local want="$1"
  shift
  local got=0
  local output=""
  set +e
  output="$("$@" 2>&1)"
  got=$?
  set -e
  if [[ "$got" -ne "$want" ]]; then
    printf 'FAIL status %s want %s for %s\n%s\n' "$got" "$want" "$*" "$output"
    fail=1
  fi
  if printf '%s' "$output" | grep -Ei 'AUTH_SECRET|BEGIN [A-Z]|encryption-key contents'; then
    printf 'FAIL output looked like a secret leak\n%s\n' "$output"
    fail=1
  fi
}

expect_status 2 "$login"
expect_status 2 "$login" --app portal
expect_status 2 "$login" --app nope --target prod
expect_status 2 "$login" --app portal --target nope
expect_status 2 "$login" --app portal --target prod --password secret
expect_status 2 "$login" --app core --target prod

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
printf 'login.sh argument tests passed\n'
