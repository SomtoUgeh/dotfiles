#!/usr/bin/env bash
#
# scan_repo.sh [dir] [--include-generated] [--details] [--workstation] [--check-signing]
# scan_repo.sh --selftest     run one inert smoke test in a temporary directory
#
# Exit codes: 0 no findings in scope, 1 matches/review signals, 2 incomplete.
# Default excludes untracked build caches; --include-generated reads them too.
# --details shows every location and error (default: 3 examples per group).
#
# Scans readable files, Git metadata, and stored blobs in discovered repositories.
# Missing history/objects or unreadable data make inspection incomplete. This is
# a known-indicator check, not proof that this Mac or remote refs are clean.
# --workstation adds local process/startup checks outside the repository.
# --check-signing reviews missing signature headers in up to 20 recent commits.

set -u

# Resolve installed symlinks before loading adjacent trusted helpers.
WORM_GUARD_ENTRY=$0
while [ -L "$WORM_GUARD_ENTRY" ]; do
  WORM_GUARD_PARENT=$(CDPATH= cd -- "$(dirname -- "$WORM_GUARD_ENTRY")" && pwd -P) || exit 2
  WORM_GUARD_ENTRY=$(/usr/bin/readlink "$WORM_GUARD_ENTRY") || exit 2
  case "$WORM_GUARD_ENTRY" in /*) ;; *) WORM_GUARD_ENTRY="$WORM_GUARD_PARENT/$WORM_GUARD_ENTRY" ;; esac
done
WORM_GUARD_SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$WORM_GUARD_ENTRY")" && pwd -P) || exit 2
. "$WORM_GUARD_SCRIPT_DIR/worm_guard_runtime.sh" || exit 2

red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
grn() { printf '\033[0;32m%s\033[0m\n' "$1"; }

run_scan() {
  local target="$1" script_dir script_path rc

  [ -d "$target" ] || { red "Scan could not start: target is not a directory. Check the directory path and retry (exit 2)."; return 2; }
  target=$(CDPATH= cd -- "$target" && pwd -P) \
    || { red "scan target could not be resolved"; return 2; }
  script_dir=$WORM_GUARD_SCRIPT_DIR
  script_path="$script_dir/scan_repo.sh"
  worm_guard_runtime || return 2
  worm_guard_python "$script_dir/worm_guard_local.py" "$target" "$script_path" "${2:-0}" "${3:-0}" "${4:-0}" "${5:-0}"
  rc=$?
  case "$rc" in
    0)  return 0 ;;
    10) return 1 ;;
    20) return 2 ;;
    *)  red "inspection incomplete: scanner runtime failed"; return 2 ;;
  esac
}

selftest() {
  local sample output rc result=1
  sample=$(mktemp -d "${TMPDIR:-/tmp}/scan-repo-selftest.XXXXXX") \
    || { red "selftest could not create a temporary directory"; return 2; }
  output="$sample/output"
  trap 'rm -rf -- "$sample"' EXIT HUP INT TERM
  mkdir -p "$sample/repo/.vscode" || return 2
  printf '{"tasks":[{"runOptions":{"runOn":"folderOpen"}}]}\n' > "$sample/repo/.vscode/tasks.json"
  printf 'module.exports={}%*sglobal.%s="A8-%s-1"\n' 60 '' 'i' '3997' > "$sample/repo/config"
  run_scan "$sample/repo" > "$output" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'editor task can run' "$output" && grep -q 'known bootstrap signature' "$output"; then
    grn "SELFTEST PASS — inert auto-run and bootstrap fixtures were detected."
    result=0
  else
    red "SELFTEST FAIL — scanner did not detect the inert fixtures (exit $rc)."
    sed -n '1,240p' "$output"
  fi
  rm -rf -- "$sample"
  trap - EXIT HUP INT TERM
  return "$result"
}

main() {
  local target=. target_set=0 include_generated=0 details=0 workstation=0 check_signing=0
  if [ "$#" -eq 0 ]; then sed -n '2,16p' "$0"; return 0; fi
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --selftest) [ "$#" -eq 1 ] && [ "$target_set" -eq 0 ] || return 2; selftest; return $? ;;
      --help|-h) sed -n '2,16p' "$0"; return 0 ;;
      --include-generated) include_generated=1 ;;
      --details) details=1 ;;
      --workstation) workstation=1 ;;
      --check-signing) check_signing=1 ;;
      --) shift; [ "$#" -eq 1 ] && [ "$target_set" -eq 0 ] || return 2; target=$1; target_set=1 ;;
      -*) red "inspection incomplete: unknown option $1"; return 2 ;;
      *) [ "$target_set" -eq 0 ] || { red 'inspection incomplete: expected one directory'; return 2; }; target=$1; target_set=1 ;;
    esac
    shift
  done
  run_scan "$target" "$include_generated" "$details" "$workstation" "$check_signing"
}

main "$@"
