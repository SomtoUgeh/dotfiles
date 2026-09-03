#!/usr/bin/env bash
#
# apply_github_rulesets.sh — apply a GitHub repository ruleset across repos.
#
#   apply_github_rulesets.sh --repo dotfiles              # dry run, one repo
#   apply_github_rulesets.sh --repo dotfiles --apply
#   apply_github_rulesets.sh --all --apply                # every admin repo
#   apply_github_rulesets.sh --all --ruleset signed-commits --apply
#
# Dry run is the DEFAULT. Nothing is sent without --apply.
#
# Idempotent: a plain POST creates a NEW ruleset every time, so this looks for
# an existing ruleset with the same name and PUTs it instead.
#
# Payloads live in config/gh/rulesets/. See the README there — in particular,
# do not apply signed-commits until local signing verifiably works.

set -u

# Resolve through the ~/bin symlink to find the repo's config directory.
SELF="$0"
while [ -L "$SELF" ]; do
  link="$(readlink "$SELF")"
  case "$link" in
    /*) SELF="$link" ;;
    *)  SELF="$(dirname "$SELF")/$link" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
RULESET_DIR="${RULESET_DIR:-$SCRIPT_DIR/../config/gh/rulesets}"

RULESET="default-branch"
MODE="dry"
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)    TARGET="$2"; shift 2 ;;
    --all)     TARGET="__all__"; shift ;;
    --ruleset) RULESET="$2"; shift 2 ;;
    --apply)   MODE="apply"; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
grn() { printf '\033[0;32m%s\033[0m\n' "$1"; }
ylw() { printf '\033[1;33m%s\033[0m\n' "$1"; }

PAYLOAD="$RULESET_DIR/$RULESET.json"
[ -f "$PAYLOAD" ] || { red "no such ruleset: $PAYLOAD"; ls "$RULESET_DIR"/*.json 2>/dev/null; exit 2; }
[ -n "$TARGET" ]  || { red "specify --repo NAME or --all"; exit 2; }

command -v gh >/dev/null || { red "gh is not installed (brew install gh)"; exit 1; }
gh auth status >/dev/null 2>&1 || { red "gh is not authenticated (gh auth login)"; exit 1; }

# Read the ruleset name without hard-depending on any one parser: a fresh
# machine may have jq missing and /usr/bin/python3 blocked behind the Xcode
# licence prompt.
if command -v jq >/dev/null; then
  NAME="$(jq -r .name "$PAYLOAD")"
elif python3 -c "" 2>/dev/null; then
  NAME="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['name'])" "$PAYLOAD")"
else
  NAME="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PAYLOAD" | head -1)"
fi
[ -n "$NAME" ] || { red "could not read .name from $PAYLOAD"; exit 2; }
OWNER="$(gh api user -q .login)"

echo "ruleset : $RULESET  (name: $NAME)"
echo "owner   : $OWNER"
echo "mode    : $([ "$MODE" = apply ] && echo APPLY || echo 'DRY RUN — nothing will be sent')"
echo

if [ "$TARGET" = "__all__" ]; then
  repos="$(gh repo list "$OWNER" --limit 200 --json name,viewerPermission \
            -q '.[] | select(.viewerPermission=="ADMIN") | .name')"
else
  repos="$TARGET"
fi

n_ok=0; n_skip=0; n_fail=0
for repo in $repos; do
  existing="$(gh api "repos/$OWNER/$repo/rulesets" -q ".[] | select(.name==\"$NAME\") | .id" 2>/dev/null | head -1)"

  if [ "$MODE" = "dry" ]; then
    if [ -n "$existing" ]; then ylw "  would UPDATE  $repo  (ruleset id $existing)"
    else                        echo "  would CREATE  $repo"; fi
    n_skip=$((n_skip+1)); continue
  fi

  if [ -n "$existing" ]; then
    if gh api -X PUT "repos/$OWNER/$repo/rulesets/$existing" --input "$PAYLOAD" >/dev/null 2>&1; then
      grn "  updated  $repo"; n_ok=$((n_ok+1))
    else
      red "  FAILED   $repo (update)"; n_fail=$((n_fail+1))
    fi
  else
    if gh api -X POST "repos/$OWNER/$repo/rulesets" --input "$PAYLOAD" >/dev/null 2>&1; then
      grn "  created  $repo"; n_ok=$((n_ok+1))
    else
      red "  FAILED   $repo (create — no admin rights, or archived?)"; n_fail=$((n_fail+1))
    fi
  fi
done

echo
if [ "$MODE" = "dry" ]; then
  ylw "Dry run: $n_skip repo(s) would change. Re-run with --apply."
else
  echo "applied: $n_ok   failed: $n_fail"
  [ "$n_fail" -gt 0 ] && exit 1
fi
exit 0
