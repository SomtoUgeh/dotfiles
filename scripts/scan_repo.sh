#!/usr/bin/env bash
#
# worm-guard:allow-signatures
# scan-repo.sh [dir]          scan a repository for git-worm indicators
# scan-repo.sh --selftest     prove the scanner can fail, then clean up
#
# Indicators from the incident case study:
#   sharonrosario.space/case-studies/git-worm-malware-incident
#
# STRUCTURAL LIMIT — read this:
#   This scans a LOCAL clone. In the documented incident 23 of 42 infected
#   repositories had no local copy, and the author's local scanner reported
#   CLEAN every round while telling the truth: her laptop was never infected,
#   her GitHub repositories were. A clean result here says nothing about repos
#   you have not cloned. Enumerate from the GitHub API, not from disk.

set -u
findings=0
red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
grn() { printf '\033[0;32m%s\033[0m\n' "$1"; }
ylw() { printf '\033[1;33m%s\033[0m\n' "$1"; }
hdr() { printf '\n\033[1m%s\033[0m\n' "$1"; }

EXCL=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv)
CODE=(--include='*.js' --include='*.cjs' --include='*.mjs' --include='*.ts'
      --include='*.tsx' --include='*.jsx' --include='*.json' --include='*.jsonc'
      --include='*.sh' --include='*.zsh' --include='*.bash' --include='*.py'
      --include='*.rb' --include='*.yml' --include='*.yaml' --include='*.toml')

scan() {
  local DIR="$1"
  [ -d "$DIR" ] || { red "not a directory: $DIR"; exit 2; }
  printf '\033[1mScanning: %s\033[0m\n' "$(cd "$DIR" && pwd)"

  hdr "1. VS Code dropper (.vscode auto-run task)"
  local vs auto
  vs=$(find "$DIR" \( -name .git -o -name node_modules \) -prune -o -type d -name '.vscode' -print 2>/dev/null)
  if [ -n "$vs" ]; then
    ylw "  .vscode/ present:"; printf '    %s\n' $vs
    auto=$(grep -rlE 'folderOpen|allowAutomaticTasks"[[:space:]]*:[[:space:]]*true' $vs 2>/dev/null)
    if [ -n "$auto" ]; then
      red "  !! AUTO-RUN ON FOLDER OPEN — do not open in VS Code/Cursor:"
      printf '    %s\n' $auto; findings=$((findings+1))
    else grn "  no folderOpen / allowAutomaticTasks:true"; fi
  else grn "  no .vscode/ directory"; fi

  hdr "2. Obfuscation bootstrap markers"
  local m
  m=$(grep -rInE "global\[['\"](!|_V|_t_t)['\"]\]|global\.i[[:space:]]*=|global\.r[[:space:]]*=[[:space:]]*require|A8-3997-1|_\\\$_1e42" \
        "$DIR" "${CODE[@]}" "${EXCL[@]}" 2>/dev/null | head -20)
  if [ -n "$m" ]; then red "  !! campaign/bootstrap marker:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "3. Payload hidden after 50+ spaces (interpreted files only)"
  m=$(grep -rInE ' {50,}[^[:space:]]' "$DIR" "${CODE[@]}" "${EXCL[@]}" 2>/dev/null | grep -vE ':[[:space:]]*(#|//|\*)' | head -20)
  if [ -n "$m" ]; then red "  !! long-whitespace padding in code:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none in code/config files"; fi

  hdr "4. Unicode-escaped requires (defeats naive grep)"
  m=$(grep -rInE 'require\([^)]*\\u00[0-9a-fA-F]{2}' "$DIR" "${CODE[@]}" "${EXCL[@]}" 2>/dev/null | head -10)
  if [ -n "$m" ]; then red "  !! escaped require():"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "5. C2 endpoints"
  m=$(grep -rInE 'trongrid\.io|bsc-dataseed|166\.88\.54\.158' "$DIR" "${EXCL[@]}" 2>/dev/null | head -10)
  if [ -n "$m" ]; then red "  !! C2 reference:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "6. Fake font droppers"
  local bad=0 magic
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    magic=$(head -c 4 "$f" 2>/dev/null)
    case "$f" in
      *.woff2) [ "$magic" = "wOF2" ] || { red "  !! $f not a woff2 (magic '$magic')"; bad=1; } ;;
      *.woff)  [ "$magic" = "wOFF" ] || { red "  !! $f not a woff (magic '$magic')";  bad=1; } ;;
    esac
    case "$f" in *fa-solid-400*|*fa-regular-400*)
      ylw "  note: $(basename "$f") — real FontAwesome ships solid-900, never solid-400" ;;
    esac
  done < <(find "$DIR" \( -name .git -o -name node_modules \) -prune -o -type f \( -name '*.woff2' -o -name '*.woff' \) -print 2>/dev/null)
  [ "$bad" = 0 ] && grn "  font magic bytes OK (or no fonts)" || findings=$((findings+1))

  hdr "7. Worm .gitignore entries"
  m=$(grep -rn -e 'temp_auto_push.bat' -e 'temp_interactive_push.bat' -e 'branch_structure.json' \
        "$DIR" --include='.gitignore' "${EXCL[@]}" 2>/dev/null)
  if [ -n "$m" ]; then red "  !! worm .gitignore entries:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "8. createRequire prepended to ESM config"
  m=$(grep -rIn 'createRequire' "$DIR" --include='*.config.js' --include='*.config.mjs' "${EXCL[@]}" 2>/dev/null)
  if [ -n "$m" ]; then ylw "  createRequire in a config (worm prepends this to ESM configs — verify):"; printf '    %s\n' "$m"
  else grn "  none"; fi

  hdr "9. Dropper blobs anywhere in git history"
  if [ -d "$DIR/.git" ]; then
    local found=0
    for sha in 5e226620 934d5554; do
      if git -C "$DIR" cat-file -e "$sha" 2>/dev/null; then
        red "  !! known dropper blob $sha EXISTS in history"; found=1
      fi
    done
    [ "$found" = 0 ] && grn "  known dropper blobs absent from history" || findings=$((findings+1))
  else ylw "  not a git repo — history not checked"; fi

  hdr "Result"
  if [ "$findings" -eq 0 ]; then
    grn "  No worm indicators found in this clone."
    ylw "  Reminder: this says nothing about repos you have not cloned."
    return 0
  else
    red "  $findings indicator group(s) flagged. Review before opening in an editor."
    return 1
  fi
}

selftest() {
  local T; T=$(mktemp -d)
  mkdir -p "$T/.vscode" "$T/public/fonts"
  printf '{"tasks":[{"label":"eslint-check","runOptions":{"runOn":"folderOpen"}}]}' > "$T/.vscode/tasks.json"
  printf 'module.exports={}%*sglobal.i="A8-3997-1"\n' 60 '' > "$T/vite.config.js"
  printf 'const h=require("\\u0068\\u0074\\u0074\\u0070")\n' > "$T/boot.cjs"
  printf 'fetch("https://trongrid.io/x")\n' > "$T/net.js"
  printf '    not-a-font\n' > "$T/public/fonts/fa-solid-400.woff2"
  printf 'node_modules\nbranch_structure.json\ntemp_auto_push.bat\n' > "$T/.gitignore"
  echo "Running scanner against an inert synthetic sample (no real malware)..."
  echo
  scan "$T"; local rc=$?
  echo
  if [ "$rc" -ne 0 ] && [ "$findings" -ge 6 ]; then
    grn "SELFTEST PASS — $findings/7 detectable groups fired."
  else
    red "SELFTEST FAIL — only $findings groups fired (expected >=6). The scanner is not trustworthy."
  fi
  rm -rf "$T"
  echo "sample destroyed: $T"
}

case "${1:---help}" in
  --selftest) selftest ;;
  --help|-h)  sed -n '2,20p' "$0" ;;
  *)          scan "${1:-.}" ;;
esac
