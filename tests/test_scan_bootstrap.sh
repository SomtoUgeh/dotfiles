#!/usr/bin/env bash
# Offline bootstrap tests: no network, package installation, or host configuration changes.
set -eu
set -o pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../scripts" && pwd -P)
T=$(mktemp -d)
T=$(CDPATH= cd -- "$T" && pwd -P)
trap 'rm -rf "$T"' EXIT
export ROOT T
sed '$d' "$ROOT/scan.sh" > "$T/functions.sh"
mkdir -p "$T/local target" "$T/infected target"
printf 'safe text\n' > "$T/local target/readme.txt"
printf 'global.%s="A8-%s-1";\n' i 3997 > "$T/infected target/payload.js"
# The test transport copies only checked-in trusted scanner sources.
cat > "$T/driver.sh" <<'DRIVER'
#!/bin/bash
. "$T/functions.sh"
download() {
  printf 'download %s\n' "${1##*/}" >> "$T/events"
  [ "$CASE" != download-fail ] || fail 'fixture download failure'
  cp "$ROOT/${1##*/}" "$2" || fail 'unknown fixture download'
  [ "$CASE" != corrupt ] || printf 'corrupt\n' >> "$2"
}
setup_dependencies() {
  printf 'setup\n' >> "$T/events"
  [ "$CASE" != dependencies-fail ] || fail 'fixture dependency failure'
  if [ "$CASE" = real ]; then
    WORM_GUARD_SCRIPT_DIR=$SCAN_WORK
    . "$SCAN_WORK/worm_guard_runtime.sh"
    worm_guard_runtime || fail 'test runtime unavailable'
    return
  fi
  # Replace verified scanner only after verification, to inspect launch behavior.
  cat > "$SCAN_WORK/scan_repo.sh" <<'SCANNER'
printf 'scan\n' >> "$T/events"
printf '%s\n' "$@" > "$T/args"
[ "$CASE" != signal ] || kill -TERM "$$"
exit "$FIXTURE_EXIT"
SCANNER
  cp "$SCAN_WORK/scan_repo.sh" "$SCAN_WORK/scan_remote.sh"
}
github_login() { printf 'login\n' >> "$T/events"; }
main "$@"
DRIVER
run() {
  expected=$1; shift
  : > "$T/events"
  rm -f "$T/args"
  rc=0
  /bin/bash "$T/driver.sh" "$@" > "$T/output" 2>&1 || rc=$?
  if [ "$rc" != "$expected" ]; then
    cat "$T/output"
    printf 'FAIL %s: expected %s got %s\n' "$CASE" "$expected" "$rc" >&2
    exit 1
  fi
}
export CASE=stub FIXTURE_EXIT=0
run 0 local "$T/local target"
printf '%s\n' "$T/local target" > "$T/expected"
cmp "$T/expected" "$T/args"
[ "$(grep -c '^download ' "$T/events")" = 6 ]
echo 'PASS embedded manifest matches actual scanner files; local path with spaces forwarded'
run 0 local "$T/local target" --include-generated --details --workstation --check-signing
printf '%s\n' "$T/local target" --include-generated --details --workstation --check-signing > "$T/expected"
cmp "$T/expected" "$T/args"
echo 'PASS local scope and detail arguments forwarded'
run 0 repo owner/repo --ref 'feature/a+b#ref'
printf '%s\n' --account default --repo owner/repo --ref 'feature/a+b#ref' > "$T/expected"
cmp "$T/expected" "$T/args"
run 0 repo owner/repo
printf '%s\n' --account default --repo owner/repo > "$T/expected"
cmp "$T/expected" "$T/args"
echo 'PASS remote default-account and exact ref argument forwarding'
for FIXTURE_EXIT in 0 1 2 7 127; do
  export FIXTURE_EXIT
  expected=$FIXTURE_EXIT
  case "$expected" in 0|1|2) ;; *) expected=2 ;; esac
  run "$expected" local "$T/local target"
done
export CASE=signal FIXTURE_EXIT=0
run 2 local "$T/local target"
echo 'PASS scanner statuses 0/1/2 preserved; unexpected errors and signals become incomplete'
for CASE in corrupt download-fail dependencies-fail; do
  export CASE
  run 2 local "$T/local target"
  ! grep -q '^scan$' "$T/events"
  if [ "$CASE" != dependencies-fail ]; then ! grep -q '^setup$' "$T/events"; fi
done
echo 'PASS checksum, transport and dependency errors cannot launch scanner'
export CASE=stub
run 2 invalid
[ ! -s "$T/events" ]
run 2 local "$T/missing"
[ ! -s "$T/events" ]
run 2 local "$T/local target" extra
[ ! -s "$T/events" ]
run 2 local "$T/local target" --unknown
[ ! -s "$T/events" ]
run 2 repo bad-repo
[ ! -s "$T/events" ]
run 2 repo owner/repo --ref ''
[ ! -s "$T/events" ]
run 2 repo owner/repo --invalid main
[ ! -s "$T/events" ]
run 0 --help
[ ! -s "$T/events" ]
echo 'PASS invalid arguments rejected before download or setup; help is offline'
export CASE=real
run 0 local "$T/local target"
run 1 local "$T/infected target"
echo 'PASS real local scanner finds inert known-positive fixture and accepts clean fixture'
# Dispatch tests replace command lookup and every mutation-capable package helper.
cat > "$T/packages.sh" <<'PACKAGES'
. "$T/functions.sh"
command() {
  if [ "${1:-}" = -v ]; then
    case "$2" in
      brew|apt-get|dnf) [ "$2" = "$MANAGER" ]; return ;;
    esac
  fi
  builtin command "$@"
}
brew() { printf 'brew %s\n' "$*" >> "$T/packages"; }
as_root() { printf 'root %s\n' "$*" >> "$T/packages"; }
download() { fail 'package dispatch must not download'; }
install_packages "$OS" git jq
PACKAGES
for MANAGER in brew apt-get dnf none; do
  export MANAGER
  OS=Linux; [ "$MANAGER" != brew ] || OS=Darwin
  export OS
  : > "$T/packages"
  rc=0
  /bin/bash "$T/packages.sh" > "$T/output" 2>&1 || rc=$?
  if [ "$MANAGER" = none ]; then
    [ "$rc" = 2 ] && [ ! -s "$T/packages" ]
  else
    [ "$rc" = 0 ]
    case "$MANAGER" in
      brew) printf 'brew install git jq\n' > "$T/expected" ;;
      apt-get) printf 'root apt-get update\nroot apt-get install -y git jq\n' > "$T/expected" ;;
      dnf) printf 'root dnf install -y git jq\n' > "$T/expected" ;;
    esac
    cmp "$T/expected" "$T/packages"
  fi
done
echo 'PASS brew/apt/dnf dispatch and unsupported-manager failure without package execution'
cat > "$T/auth.sh" <<'AUTH'
. "$T/functions.sh"
gh() {
  printf '%s\n' "$*" >> "$T/auth-log"
  [ "${GH_HOST:-}" = github.com ] || return 89
  # Aggregate status would fail because of an unrelated expired saved account.
  [ "$*" = 'api rate_limit' ] || return 1
  [ "$GH_TOKEN" = fixture-valid ] || return 1
  printf '{"resources":{"core":{"remaining":5000}}}\n'
}
github_login
AUTH
for auth_case in valid invalid; do
  : > "$T/auth-log"
  rc=0
  GH_HOST=other.example GH_TOKEN="fixture-$auth_case" /bin/bash "$T/auth.sh" > "$T/output" 2>&1 || rc=$?
  if [ "$auth_case" = valid ]; then [ "$rc" = 0 ]; else [ "$rc" = 2 ]; fi
  printf 'api rate_limit\n' > "$T/expected"
  cmp "$T/expected" "$T/auth-log"
done
echo 'PASS login probe pins GitHub host, checks selected credentials and never logs in with invalid token'
echo 'All bootstrap tests passed with /bin/bash (no network or installation).'
