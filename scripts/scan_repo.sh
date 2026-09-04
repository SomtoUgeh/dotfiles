#!/usr/bin/env bash
#
# worm-guard:allow-signatures
# scan-repo.sh [dir]          scan a repository for git-worm indicators (14 checks)
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
      --include='*.tsx' --include='*.jsx' --include='*.mts' --include='*.cts'
      --include='*.vue' --include='*.svelte' --include='*.astro' --include='*.php'
      --include='*.json' --include='*.jsonc'
      --include='*.sh' --include='*.zsh' --include='*.bash' --include='*.py'
      --include='*.rb' --include='*.yml' --include='*.yaml' --include='*.toml')

# grep -r prints "path:lineno:content". The old filter tested the WHOLE line for
# a comment marker, so any payload containing "://" was silently dropped. This
# tests only the content field, anchored at its start.
drop_comment_lines() {
  awk '{ i=index($0,":"); r=substr($0,i+1); j=index(r,":"); c=substr(r,j+1)
         if (c ~ /^[[:space:]]*(#|\/\/|\*|\/\*)/) next
         print }'
}

# Drop matches coming from files that carry the opt-out marker. A detector
# necessarily contains the strings it detects; without this the scanner reports
# itself. Same marker the global pre-commit hook honours. Use it sparingly.
drop_marked() {
  local line f
  while IFS= read -r line; do
    f="${line%%:*}"
    [ -f "$f" ] && grep -q 'worm-guard:allow-signatures' "$f" 2>/dev/null && continue
    printf '%s\n' "$line"
  done
}

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
  # v1 / v2 obfuscator signatures, split at a quote boundary so a -F search for
  # the literal does not match this file. Joined values are byte-identical.
  local _s1="rmcej"'%otb%' _s2="Cot"'%3t=shtP'
  m=$(grep -rInE "global\[['\"](!|_V|_t_t|r|m)['\"]\]|global\.i[[:space:]]*=|global\.r[[:space:]]*=[[:space:]]*require|A8-3997-1|A8-5657-1|${_s1}|${_s2}|_\\\$_1e42" \
        "$DIR" "${CODE[@]}" "${EXCL[@]}" 2>/dev/null | drop_marked | head -20)
  if [ -n "$m" ]; then red "  !! campaign/bootstrap marker:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "3. Payload hidden after 50+ whitespace chars, space OR tab (interpreted files only)"
  m=$(grep -rInE '[[:space:]]{50,}[^[:space:]]' "$DIR" "${CODE[@]}" "${EXCL[@]}" 2>/dev/null | drop_comment_lines | drop_marked | head -20)
  if [ -n "$m" ]; then red "  !! long-whitespace padding in code:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none in code/config files"; fi

  hdr "3b. Very long single line in code (padding-independent)"
  # awk, not grep: BSD grep rejects an interval over 255 ("maximum repetition
  # exceeds 255") and the old 2>/dev/null turned that error into a clean result.
  m=$(find "$DIR" \( -name .git -o -name node_modules -o -name .venv \) -prune -o -type f \
        \( -name '*.js' -o -name '*.cjs' -o -name '*.mjs' -o -name '*.mts' -o -name '*.cts' \
        -o -name '*.ts' -o -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' \
        -o -name '*.astro' -o -name '*.php' -o -name '*.json' -o -name '*.jsonc' \) -print 2>/dev/null \
      | while IFS= read -r f; do
          case "$f" in
            *.min.*|*-lock.json|*/yarn.lock|*/pnpm-lock.yaml|*.bundle.*|*.map) continue ;;
          esac
          grep -q 'worm-guard:allow-signatures' "$f" 2>/dev/null && continue
          awk -v F="$f" 'length($0)>2000 { printf "%s:%d: single line of %d chars\n", F, NR, length($0); exit }' "$f"
        done | head -10)
  if [ -n "$m" ]; then red "  !! line over 2000 chars — catches any padding variant:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "4. Unicode-escaped requires (defeats naive grep)"
  m=$(grep -rInE 'require\([^)]*\\u00[0-9a-fA-F]{2}' "$DIR" "${CODE[@]}" "${EXCL[@]}" 2>/dev/null | drop_marked | head -10)
  if [ -n "$m" ]; then red "  !! escaped require():"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "5. C2 endpoints, wallet addresses and XOR keys"
  # Escaped dots double as fragmentation: a -F search for the plain hostname
  # will not match this file. Wallet addresses have no dots, so split them.
  local _tr1="TMfKQEd7TJJa5xNZ" _tr2="TXfxHUet9pJVU1Bg"
  local _ap1="0xbe037400670fbf1c32364f762975908d" _ap2="0x3f0e5781d0855fb460661ac63257376d"
  m=$(grep -rInE "trongrid\\.io|bsc-dataseed|bsc-rpc\\.publicnode\\.com|fullnode\\.mainnet\\.aptoslabs\\.com|166\\.88\\.54\\.158|(default-configuration|vscode-settings-bootstrap|vscode-settings-config|vscode-bootstrapper|vscode-load-config|260120)\\.vercel\\.app|${_tr1}JZ2Lep838vrzrs7mAP|${_tr2}VkBAbrES4YUc1nGzcG|${_ap1}c43eeb38759263e7dfcdabc76380811e|${_ap2}b1941b2bb522499e4757ecb3ebd5dce3" \
        "$DIR" "${EXCL[@]}" 2>/dev/null | drop_marked | head -10)
  # XOR keys contain [ ^ - so they must go through -F, not a regex.
  local _x1='2[gWfGj;<:-93Z' _x2='m6:tTh^D)cBz?NM'
  local x
  x=$(grep -rInF -e "${_x1}^C" -e "${_x2}]" "$DIR" "${EXCL[@]}" 2>/dev/null | drop_marked | head -5)
  [ -n "$x" ] && m="${m}${m:+
}${x}"
  if [ -n "$m" ]; then red "  !! C2 / wallet / XOR-key reference:"; printf '    %s\n' "$m"; findings=$((findings+1))
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
  # IOC strings are assembled from fragments on purpose. Spelling an indicator
  # out in full here makes OTHER people's scanners report this detector as a
  # hit — check-polinrider.sh A5 does exactly that. The joined values are
  # byte-identical to the real indicators, so detection is unchanged.
  local _t="temp_" _b="branch_"
  m=$(grep -rn -e "${_t}auto_push.bat" -e "${_t}interactive_push.bat" -e "${_b}structure.json" \
        "$DIR" --include='.gitignore' "${EXCL[@]}" 2>/dev/null | drop_marked)
  if [ -n "$m" ]; then red "  !! worm .gitignore entries:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi
  # The worm also adds '.gitignore' to .gitignore so its own edit stops showing
  # in git status. A .gitignore that ignores itself is close to never legitimate.
  m=$(grep -rn '^[[:space:]]*\.gitignore[[:space:]]*$' "$DIR" --include='.gitignore' "${EXCL[@]}" 2>/dev/null)
  if [ -n "$m" ]; then red "  !! .gitignore lists ITSELF (hides the worm's own edit):"; printf '    %s\n' "$m"; findings=$((findings+1)); fi

  hdr "8. createRequire prepended to ESM config"
  m=$(grep -rIn 'createRequire' "$DIR" --include='*.config.js' --include='*.config.mjs' \
        --include='*.mjs' "${EXCL[@]}" 2>/dev/null)
  if [ -n "$m" ]; then ylw "  createRequire in a config (worm prepends this to ESM configs — verify):"; printf '    %s\n' "$m"
  else grn "  none"; fi

  hdr "9. TasksJacker command (node executing a font file)"
  m=$(grep -rInE 'node[[:space:]]+[^"]*\.woff2?' "$DIR" --include='*.json' --include='*.jsonc' "${EXCL[@]}" 2>/dev/null | drop_marked | head -10)
  if [ -n "$m" ]; then red "  !! a task runs node against a FONT file — this is the dropper:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "9b. Commit-tamper script (.bat / .ps1)"
  local _t2="temp_"
  m=$(find "$DIR" \( -name .git -o -name node_modules \) -prune -o -type f \
        \( -name "${_t2}auto_push.bat" -o -name "${_t2}interactive_push.bat" \) -print 2>/dev/null | head -10)
  x=$(grep -rIn 'LAST_COMMIT_DATE' "$DIR" --include='*.bat' --include='*.ps1' --include='*.sh' \
        "${EXCL[@]}" 2>/dev/null | drop_marked | head -5)
  [ -n "$x" ] && m="${m}${m:+
}${x}"
  if [ -n "$m" ]; then red "  !! commit-tamper / push script:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "10. Malicious npm dependency"
  # Fragmented: a literal here would trip check-polinrider A6 against this file.
  local _tw="tailwindcss-" _tl="tailwind-" _pc="postcss-minify-"
  m=$(grep -rnE "${_tw}(style-animate|typography-style|style-modify|animate-style)|${_tl}(mainanimation|autoanimation|animationbased)|${_pc}selector-parser|html-to-gutenberg|fetch-page-assets|aes-decode-runner-pro" \
        "$DIR" --include='package.json' --include='package-lock.json' \
        --include='yarn.lock' --include='pnpm-lock.yaml' "${EXCL[@]}" 2>/dev/null | drop_marked | head -10)
  if [ -n "$m" ]; then red "  !! malicious npm package:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "11. Weaponized take-home UUID"
  # Fragmented: a literal here would trip check-polinrider A7 against this file.
  local _u="e9b53a7c-2342-4b15"
  m=$(grep -rIn "${_u}-b02d-bd8b8f6a03f9" "$DIR" "${EXCL[@]}" 2>/dev/null | drop_marked | head -5)
  if [ -n "$m" ]; then red "  !! known weaponized take-home marker:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "12. Leaked GitHub OAuth token"
  # The worm stole a gho_ grant from Git Credential Manager. One committed to a
  # repo is either the theft path or a fresh leak; either way it must be revoked.
  local _g="gho_"
  m=$(grep -rInE "${_g}[A-Za-z0-9]{36}" "$DIR" "${EXCL[@]}" 2>/dev/null | drop_marked | head -5)
  if [ -n "$m" ]; then red "  !! GitHub OAuth token in tracked content — REVOKE THE GRANT:"; printf '    %s\n' "$m"; findings=$((findings+1))
  else grn "  none"; fi

  hdr "13. Server-side commit rewrites (timezone fingerprint)"
  # The author's own timeline check: commits rewritten through the stolen token
  # carry GitHub's server timezone (-0700/-0800) while the real author commits
  # from their own offset. Same person as author AND committer, different zone.
  if [ -d "$DIR/.git" ]; then
    m=$(git -C "$DIR" log --all -n 500 --format='%an|%cn|%ai|%ci' 2>/dev/null \
        | awk -F'|' '$1==$2 { split($3,a," "); split($4,b," "); if (a[3]!=b[3]) print "  author "a[3]" but committer "b[3]"  ("$1")" }' \
        | sort -u | head -10)
    if [ -n "$m" ]; then red "  !! author/committer timezone mismatch on same identity:"; printf '  %s\n' "$m"; findings=$((findings+1))
    else grn "  no timezone mismatch in last 500 commits"; fi
  else ylw "  not a git repo — history not checked"; fi

  hdr "14. Dropper blobs anywhere in git history"
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
  printf '.gitignore\nnode_modules\n%sstructure.json\n%sauto_push.bat\n' 'branch_' 'temp_' > "$T/.gitignore"
  # Fixtures for checks 9-12. All inert: no payload, no network, no execution.
  printf '{"tasks":[{"command":"node ./public/fonts/fa-solid-400.woff2"}]}\n' > "$T/.vscode/dropper.json"
  printf '{"dependencies":{"%sstyle-animate":"^1.0.0"}}\n' 'tailwindcss-' > "$T/package.json"
  printf 'id=%s-b02d-bd8b8f6a03f9\n' 'e9b53a7c-2342-4b15' > "$T/takehome.txt"
  printf 'token=%s%s\n' 'gho_' 'AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII' > "$T/leak.env"
  echo "Running scanner against an inert synthetic sample (no real malware)..."
  echo
  scan "$T"; local rc=$?
  echo
  # 12 groups are detectable without a .git dir. Checks 13 (timezone) and 14
  # (dropper blobs) need real history and are exercised against real repos.
  local expected=12
  if [ "$rc" -ne 0 ] && [ "$findings" -ge "$expected" ]; then
    grn "SELFTEST PASS — $findings/$expected detectable groups fired."
  else
    red "SELFTEST FAIL — only $findings of $expected groups fired. The scanner is not trustworthy."
  fi
  rm -rf "$T"
  echo "sample destroyed: $T"
}

case "${1:---help}" in
  --selftest) selftest ;;
  --help|-h)  sed -n '2,20p' "$0" ;;
  *)          scan "${1:-.}" ;;
esac
