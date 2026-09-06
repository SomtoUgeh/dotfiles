#!/usr/bin/env bash
# Offline integration tests. The mock rejects every API endpoint not declared here.
set -eu
set -o pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../scripts" && pwd -P)
SCANNER_BASH=${1:-/bin/bash}
export REAL_FILE=$(command -v file)
export REAL_JQ=$(command -v jq)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/fixtures"

printf 'ok();\n' > "$T/fixtures/safe"
printf 'no();\n' > "$T/fixtures/other"
printf 'import {createRequire} from "module"; const require=createRequire(import.meta.url);\n' > "$T/fixtures/shim"
awk 'BEGIN{for(i=0;i<4000;i++)printf "x";print ""}' > "$T/fixtures/minified"
{
  printf 'const x=1;'
  awk 'BEGIN{for(i=0;i<80;i++)printf "\t"}'
  printf 'global.%s="A8-%s-1";\n' 'i' '3997'
} > "$T/fixtures/tiny"
printf 'notes about branch_%s.json\n' 'structure' > "$T/fixtures/docs"
printf 'not-a-font\n' > "$T/fixtures/fakefont"
printf 'wOF2real-font\n' > "$T/fixtures/font"
printf '\000\001\002\003' > "$T/fixtures/binary"
printf '\377\376g\000l\000o\000b\000a\000l\000.\000i\000=\000"\000A\0008\000-\0003\0009\0009\0007\000-\0001\000"\000;\000\n\000' > "$T/fixtures/utf16"
cp "$ROOT/scan_remote.sh" "$T/fixtures/scanner"
cp "$ROOT/worm_guard_patterns.py" "$T/fixtures/core"
{
  printf '"TMfKQEd7TJJa5xNZ%s"\n' 'JZ2Lep838vrzrs7mAP'
  printf '%s%s\n' '\u0068\u0074\u0074\u0070' '\u0063\u0068\u0069\u006c\u0064'
  printf '%s\n' 'require("\u0061")'
  printf '%s%s\n' 'ghu_' 'AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII'
} > "$T/fixtures/union"

for name in safe other shim minified tiny docs fakefont font binary utf16 scanner core union; do
  upper=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')
  eval "export SHA_$upper=$(git hash-object --no-filters "$T/fixtures/$name")"
  eval "export SIZE_$upper=$(wc -c < "$T/fixtures/$name" | tr -d ' ')"
done
export FIXTURE_DIR="$T/fixtures"

cat > "$T/bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$MOCK_LOG"
[ "${GH_HOST:-}" = github.com ] || { printf 'GH_HOST was not pinned to github.com\n' >&2; exit 89; }
if [ "${EXPECT_DEFAULT_AUTH:-}" = 1 ]; then
  [ "${GH_CONFIG_DIR-unset}" = "$EXPECTED_GH_CONFIG" ] || exit 89
  [ "${GH_TOKEN-unset}" = "$EXPECTED_GH_TOKEN" ] || exit 89
  [ "${GITHUB_TOKEN-unset}" = "$EXPECTED_GITHUB_TOKEN" ] || exit 89
fi
if [ "$1" = auth ]; then
  [ "$*" = 'auth status --hostname github.com' ] || exit 90
  [ "$MOCK_CASE" != auth ] && [ "$MOCK_CASE" != inactive-auth ] || exit 1
  exit 0
fi
[ "$1" = api ] || exit 90
endpoint=$2
case "$endpoint" in
  user)
    [ "$MOCK_CASE" != auth ] || exit 1
    [ -z "${GITHUB_TOKEN:-}" ] || { printf 'inherited GITHUB_TOKEN reached personal account\n' >&2; exit 89; }
    printf 'tester\n'
    ;;
  rate_limit)
    [ "$MOCK_CASE" != default-auth ] || exit 1
    [ "$MOCK_CASE" != rate-fraction ] || { printf '{"resources":{"core":{"remaining":199.5}}}\n'; exit; }
    printf '{"resources":{"core":{"remaining":5000}}}\n'
    ;;
  user/repos*)
    [[ " $* " = *' --paginate '* && " $* " != *' --slurp '* ]] || exit 91
    case "$MOCK_CASE" in
      empty-auto|inventory|inventory-missing|ignore-other) printf '[]\n' ;;
      malformed-repos) printf '[{"full_name":4,"permissions":{"pull":true}}]\n' ;;
      *) printf '[{"full_name":"test/auto","permissions":{"pull":true}}]\n[]\n' ;;
    esac
    ;;
  repos/*/branches\?*)
    [ "$MOCK_CASE" != refs-error ] || exit 1
    [[ " $* " = *' --paginate '* && " $* " != *' --slurp '* ]] || exit 91
    case "$MOCK_CASE" in
      pages-empty) exit 0 ;;
      pages-malformed) printf '[{"name":'; exit 0 ;;
      pages-object) printf '{}\n'; exit 0 ;;
      pages-rate) printf '[]\n'; printf 'API rate limit exceeded\n' >&2; exit 1 ;;
      pages-merged)
        printf '[{"name":"main","commit":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},{"name":"page-two","commit":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}]\n'
        ;;
      *) printf '[{"name":"main","commit":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}]\n[{"name":"page-two","commit":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}]\n' ;;
    esac
    ;;
  repos/*/tags\?*)
    [[ " $* " = *' --paginate '* && " $* " != *' --slurp '* ]] || exit 91
    if [ "$MOCK_CASE" = tagged ]; then
      printf '[{"name":"v1","commit":{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}]\n[]\n'
    else
      printf '[]\n[]\n'
    fi
    ;;
  repos/*/commits/*)
    [ "$MOCK_CASE" != commit-error ] || exit 1
    if [ -n "${EXPECTED_COMMIT_ENDPOINT:-}" ]; then
      [ "$endpoint" = "$EXPECTED_COMMIT_ENDPOINT" ] || exit 93
    fi
    if [ "$MOCK_CASE" = midrun-cache-corrupt ]; then
      if [ -f "$WORMGUARD_STATE/first-ref-started" ]; then
        cp "$FIXTURE_DIR/other" "$WORMGUARD_STATE/blob-cache/$SHA_SAFE"
      else
        touch "$WORMGUARD_STATE/first-ref-started"
      fi
    fi
    printf '{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","commit":{"author":{"name":"Tester","email":"a@example.test"},"committer":{"name":"Tester","email":"a@example.test"}}}\n'
    ;;
  repos/*/git/trees/*)
    [ "$MOCK_CASE" != tree-error ] || exit 1
    [ "$MOCK_CASE" != malformed-tree ] || { printf '{"tree":[{"type":"blob","path":"x","sha":"bad","size":1}],"truncated":false}\n'; exit; }
    case "$MOCK_CASE" in
      infected|signal-*)
        jq -n --arg a "$SHA_TINY" --argjson az "$SIZE_TINY" --arg b "$SHA_DOCS" --argjson bz "$SIZE_DOCS" \
          --arg c "$SHA_FAKEFONT" --argjson cz "$SIZE_FAKEFONT" \
          '{tree:[{type:"blob",mode:"100644",path:"src/tiny.js",sha:$a,size:$az},
                  {type:"blob",mode:"100644",path:"SECURITY",sha:$b,size:$bz},
                  {type:"blob",mode:"100644",path:"assets/renamed.woff2",sha:$c,size:$cz}],truncated:false}'
        ;;
      benign)
        jq -n --arg a "$SHA_MINIFIED" --argjson az "$SIZE_MINIFIED" --arg b "$SHA_SHIM" --argjson bz "$SIZE_SHIM" \
          '{tree:[{type:"blob",mode:"100644",path:"bundle.js",sha:$a,size:$az},
                  {type:"blob",mode:"100644",path:"vite.config.mjs",sha:$b,size:$bz}],truncated:false}'
        ;;
      path-sensitive)
        jq -n --arg a "$SHA_MINIFIED" --argjson az "$SIZE_MINIFIED" \
          '{tree:[{type:"blob",mode:"100644",path:"bundle.js",sha:$a,size:$az},
                  {type:"blob",mode:"100644",path:"vite.config.mjs",sha:$a,size:$az}],truncated:false}'
        ;;
      scanner-source)
        jq -n --arg a "$SHA_SCANNER" --argjson az "$SIZE_SCANNER" \
          '{tree:[{type:"blob",mode:"100755",path:"scripts/scan_remote.sh",sha:$a,size:$az}],truncated:false}'
        ;;
      core-source|union-rules)
        if [ "$MOCK_CASE" = core-source ]; then a=$SHA_CORE; az=$SIZE_CORE; else a=$SHA_UNION; az=$SIZE_UNION; fi
        jq -n --arg a "$a" --argjson az "$az" \
          '{tree:[{type:"blob",mode:"100644",path:"source.py",sha:$a,size:$az}],truncated:false}'
        ;;
      utf16)
        jq -n --arg a "$SHA_UTF16" --argjson az "$SIZE_UTF16" \
          '{tree:[{type:"blob",mode:"100644",path:"utf16.js",sha:$a,size:$az}],truncated:false}'
        ;;
      gitlink)
        printf '{"tree":[{"type":"commit","mode":"160000","path":"vendor/sub","sha":"cccccccccccccccccccccccccccccccccccccccc"}],"truncated":false}\n'
        ;;
      truncated)
        jq -n --arg a "$SHA_SAFE" --argjson az "$SIZE_SAFE" \
          '{tree:[{type:"blob",mode:"100644",path:"safe.js",sha:$a,size:$az}],truncated:true}'
        ;;
      hash-error|size-error|blob-error|rate-error)
        jq -n --arg a "$SHA_SAFE" --argjson az "$SIZE_SAFE" \
        '{tree:[{type:"blob",mode:"100644",path:"safe.js",sha:$a,size:$az}],truncated:false}'
        ;;
      path-artifact)
        jq -n --arg a "$SHA_SAFE" --argjson az "$SIZE_SAFE" --arg p "temp_""auto_push.bat" \
          '{tree:[{type:"blob",mode:"100644",path:$p,sha:$a,size:$az}],truncated:false}'
        ;;
      control-path)
        jq -n --arg a "$SHA_DOCS" --argjson az "$SIZE_DOCS" --arg p $'evil\u001b]8;;forged\a\nline.js' \
          '{tree:[{type:"blob",mode:"100644",path:$p,sha:$a,size:$az}],truncated:false}'
        ;;
      bad-sha)
        printf '{"tree":[{"type":"blob","mode":"100644","path":"safe.js","sha":"../../escape","size":6}],"truncated":false}\n'
        ;;
      *)
        jq -n --arg a "$SHA_SAFE" --argjson az "$SIZE_SAFE" --arg f "$SHA_FONT" --argjson fz "$SIZE_FONT" \
          --arg b "$SHA_BINARY" --argjson bz "$SIZE_BINARY" \
          '{tree:[{type:"blob",mode:"100644",path:"safe.js",sha:$a,size:$az},
                  {type:"blob",mode:"100644",path:"copy.txt",sha:$a,size:$az},
                  {type:"blob",mode:"100644",path:"fonts/brand.woff2",sha:$f,size:$fz},
                  {type:"blob",mode:"100644",path:"image.bin",sha:$b,size:$bz}],truncated:false}'
        ;;
    esac
    ;;
  repos/*/git/blobs/*)
    sha=${endpoint##*/}
    case "$MOCK_CASE" in
      signal-*)
        if [ "$sha" = "$SHA_DOCS" ]; then
          kill -"${MOCK_CASE#signal-}" "$PPID"
        fi
        ;;
    esac
    if [ "$MOCK_CASE" = blob-error ]; then exit 1; fi
    if [ "$MOCK_CASE" = rate-error ]; then printf 'API rate limit exceeded\n' >&2; exit 1; fi
    file=""
    for name in safe other shim minified tiny docs fakefont font binary utf16 scanner core union; do
      upper=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')
      eval "candidate=\${SHA_$upper}"
      [ "$sha" != "$candidate" ] || { file="$FIXTURE_DIR/$name"; break; }
    done
    [ -n "$file" ] || exit 92
    [ "$MOCK_CASE" != hash-error ] || file="$FIXTURE_DIR/other"
    content=$(base64 < "$file")
    size=$(wc -c < "$file" | tr -d ' ')
    [ "$MOCK_CASE" != size-error ] || size=$((size + 1))
    jq -n --arg sha "$sha" --arg content "$content" --argjson size "$size" \
      '{sha:$sha,encoding:"base64",content:$content,size:$size}'
    ;;
  repos/*)
    full=${endpoint#repos/}
    [ "$full" != test/missing ] || exit 1
    jq -n --arg full "$full" '{full_name:$full,default_branch:"main",permissions:{pull:true,push:false}}'
    ;;
  *) printf 'unmocked API: %s\n' "$endpoint" >&2; exit 92 ;;
esac
MOCK
cat > "$T/bin/sleep" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
cat > "$T/bin/sort" <<'MOCK'
#!/usr/bin/env bash
[ "${MOCK_CASE:-}" != sort-error ] || exit 1
exec /usr/bin/sort "$@"
MOCK
cat > "$T/bin/file" <<'MOCK'
#!/usr/bin/env bash
printf 'classify\n' >> "$MOCK_CLASSIFY_LOG"
exec "$REAL_FILE" "$@"
MOCK
cat > "$T/bin/jq" <<'MOCK'
#!/usr/bin/env bash
if [ "${MOCK_CASE:-}" = ref-encoding-error ] && [ "${1:-}" = -rn ] && [ "${3:-}" = ref ]; then
  exit 1
fi
exec "$REAL_JQ" "$@"
MOCK
chmod +x "$T/bin/gh" "$T/bin/sleep" "$T/bin/sort" "$T/bin/file" "$T/bin/jq"
export PATH="$T/bin:$PATH"
export MOCK_LOG="$T/api.log"
export MOCK_CLASSIFY_LOG="$T/classify.log"

new_case() {
  name=$1
  export WORMGUARD_GH_CONFIG_ROOT="$T/config-$name"
  export WORMGUARD_STATE="$T/state-$name"
  export WORMGUARD_REPOS_FILE="$WORMGUARD_STATE/repos.tsv"
  mkdir -p "$WORMGUARD_GH_CONFIG_ROOT/gh-personal" "$WORMGUARD_STATE"
  touch "$WORMGUARD_GH_CONFIG_ROOT/gh-personal/hosts.yml"
  : > "$MOCK_LOG"
  : > "$MOCK_CLASSIFY_LOG"
}

run_scan() {
  expected=$1
  shift
  rc=0
  "$SCANNER_BASH" "$ROOT/scan_remote.sh" "$@" > "$T/result" 2>&1 || rc=$?
  if [ "$rc" != "$expected" ]; then
    cat "$T/result"
    [ ! -f "$WORMGUARD_STATE/scan-last-run.json" ] || jq '{status,exit_code,counts}' "$WORMGUARD_STATE/scan-last-run.json"
    printf 'FAIL %s with %s: expected %s, got %s\n' "$MOCK_CASE" "$SCANNER_BASH" "$expected" "$rc" >&2
    exit 1
  fi
}

for interrupt_signal in TERM HUP INT; do
  export MOCK_CASE="signal-$interrupt_signal" WORMGUARD_RUN_ID="test-$interrupt_signal"
  new_case "$MOCK_CASE"
  run_scan 2 --account personal --repo test/repo --ref main
  jq -e --arg id "$WORMGUARD_RUN_ID" '.run_id==$id and .scan_complete==false and .status=="incomplete" and .exit_code==2 and .counts.findings>0 and .counts.refs_checked<.counts.refs_attempted' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
done
unset WORMGUARD_RUN_ID
echo 'PASS TERM, HUP and INT preserve findings and report incomplete, never clean'

export MOCK_CASE=clean
new_case clean
run_scan 0 --account personal --repo test/repo --ref main
grep -q 'commit aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$T/result"
grep -q '4 blob occurrence(s), 3 unique verified blob(s), 1 cache hit(s)' "$T/result"
jq -e '.status=="clean" and .counts.text_blobs_scanned==3 and .counts.binary_blobs_classified==1 and .counts.font_blobs_validated==1' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
echo 'PASS clean all-blob classification, immutable SHA log, dedup, evidence'
! grep -Eq '/(branches|tags|activity)' "$MOCK_LOG"
jq -e '.request.ref_scope=="single-ref"' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null

: > "$MOCK_LOG"
run_scan 0 --account personal --repo test/repo --ref main
! grep -q '/git/blobs/' "$MOCK_LOG"
echo 'PASS persistent verified cache avoids API reads and reruns detectors'

for ref_pair in 'main#payload|main%23payload' 'feature/a+b%2F{branch}|feature%2Fa%2Bb%252F%7Bbranch%7D' 'feature/café|feature%2Fcaf%C3%A9'; do
  ref=${ref_pair%%|*}
  encoded_ref=${ref_pair#*|}
  export MOCK_CASE=infected EXPECTED_COMMIT_ENDPOINT="repos/test/repo/commits/$encoded_ref"
  new_case encoded-ref
  run_scan 1 --account personal --repo test/repo --ref "$ref"
  jq -e --arg ref "$ref" '.refs[0].ref==$ref and .status=="findings"' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
done
unset EXPECTED_COMMIT_ENDPOINT
export MOCK_CASE=clean
new_case immutable-ref
run_scan 0 --account personal --repo test/repo --ref aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
new_case wrong-immutable-ref
run_scan 2 --account personal --repo test/repo --ref bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
grep -q 'expected immutable' "$T/result"
echo 'PASS exact ref encoding, original evidence labels and immutable SHA checks'

export MOCK_CASE=ref-encoding-error
new_case ref-encoding-error
run_scan 2 --account personal --repo test/repo --ref main
grep -q 'ref encoding failed' "$T/result"
! grep -q '/commits/' "$MOCK_LOG"
echo 'PASS failed ref encoding stops before requesting a commit'
export MOCK_CASE=clean

new_case corrupt-cache
mkdir -p "$WORMGUARD_STATE/blob-cache"
cp "$T/fixtures/other" "$WORMGUARD_STATE/blob-cache/$SHA_SAFE"
run_scan 2 --account personal --repo test/repo --ref main
grep -q 'SHA validation failed' "$T/result"
echo 'PASS same-size persistent cache corruption fails SHA validation'

export MOCK_CASE=infected
new_case infected
run_scan 1 --account personal --repo test/repo --ref main
grep -q 'hidden-padding.*src/tiny.js' "$T/result"
grep -q 'worm-marker.*src/tiny.js' "$T/result"
grep -q 'worm-artifact.*SECURITY' "$T/result"
grep -q 'fake-font.*assets/renamed.woff2' "$T/result"
echo 'PASS tiny source, extensionless text, campaign marker, renamed font'

export MOCK_CASE=benign
new_case benign
run_scan 0 --account personal --repo test/repo --ref main
grep -q 'createRequire.*vite.config.mjs' "$T/result"
grep -q '0 finding(s), 1 review item(s)' "$T/result"
echo 'PASS innocent minified text and createRequire shim do not become findings'

export MOCK_CASE=scanner-source
new_case scanner-source
run_scan 0 --account personal --repo test/repo --ref main
echo 'PASS detector source does not self-match its split signature literals'
export MOCK_CASE=core-source
new_case core-source
run_scan 0 --account personal --repo test/repo --ref main
echo 'PASS shared core source does not need a marker or filename exemption'

export MOCK_CASE=union-rules
new_case union-rules
run_scan 1 --account personal --repo test/repo --ref main
for label in network-ioc escaped-bootstrap escaped-require oauth-token; do
  grep -q "$label" "$T/result"
done
! grep -q 'AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII' "$T/result" "$WORMGUARD_STATE/scan-last-run.json"
echo 'PASS remote scanning preserves formerly local wallet and escaped-require rules'


for item in 'auth 2' 'rate-fraction 2' 'commit-error 2' 'tree-error 2' 'malformed-tree 2' 'truncated 2' \
  'blob-error 2' 'hash-error 2' 'size-error 2' 'bad-sha 2'; do
  set -- $item
  export MOCK_CASE=$1
  new_case "$MOCK_CASE"
  run_scan "$2" --account personal --repo test/repo --ref main
  echo "PASS fail closed: $MOCK_CASE"
done

export MOCK_CASE=utf16
new_case utf16
run_scan 1 --account personal --repo test/repo --ref main
grep -q 'worm-marker.*utf16.js' "$T/result"
echo 'PASS UTF-16 text is decoded and scanned'

export MOCK_CASE=path-artifact
new_case path
run_scan 1 --account personal --repo test/repo --ref main
grep -q 'worm-artifact-path.*temp_'"auto_push.bat" "$T/result"
echo 'PASS known artifact filename is detected independent of content'

export MOCK_CASE=control-path
new_case control-path
run_scan 1 --account personal --repo test/repo --ref main
if LC_ALL=C grep -q $'\033]' "$T/result"; then
  echo 'FAIL raw OSC terminal escape from Git path reached stdout' >&2
  exit 1
fi
grep -Fq '\\u001b' "$T/result"
jq -e '.findings[0].path | contains("\u001b") and contains("\n")' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
echo 'PASS control characters in paths are escaped for terminal output and preserved in JSON'

export MOCK_CASE=rate-error
new_case rate
run_scan 2 --account personal --repo test/repo --ref main
[ "$(grep -c '/git/blobs/' "$MOCK_LOG")" = 1 ]
grep -q 'scan stopped after an API rate-limit response' "$T/result"
echo 'PASS rate limit stops further blob requests and retains incomplete result'

export MOCK_CASE=gitlink
new_case gitlink
run_scan 0 --account personal --repo test/repo --ref main
grep -q 'not a full submodule-content verdict' "$T/result"
jq -e '.counts.gitlinks_omitted==1 and .exclusions[0].kind=="gitlink"' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
echo 'PASS gitlink omission is explicit in stdout and JSON'

export MOCK_CASE=clean
new_case empty-scope
run_scan 2 --account personal
[ ! -s "$MOCK_LOG" ]
run_scan 2
[ ! -s "$MOCK_LOG" ]
echo 'PASS missing inventory fails before any API request'

export MOCK_CASE=inventory
new_case inventory
printf 'personal\ttest/readonly\n' > "$WORMGUARD_REPOS_FILE"
run_scan 0 --account personal
grep -q '1 repo(s), 2/2 ref(s)' "$T/result"
grep -q 'repos/test/readonly' "$MOCK_LOG"
! grep -q 'user/repos' "$MOCK_LOG"
echo 'PASS inventory scope never enumerates account repositories and scans all ref pages'

export MOCK_CASE=clean
new_case union
printf 'personal\ttest/readonly\n' > "$WORMGUARD_REPOS_FILE"
run_scan 0 --account personal --all-readable
grep -q '2 repo(s), 4/4 ref(s)' "$T/result"
classifications=$(wc -l < "$MOCK_CLASSIFY_LOG" | tr -d ' ')
if [ "$classifications" != 4 ]; then
  echo "FAIL repeated refs reclassified identical verified bytes/path: expected 4 classifications, got $classifications" >&2
  exit 1
fi
echo 'PASS automatic readable repositories union with inventory'
jq -e '.scan_complete==true and .counts.clean_detector_results_reused==12 and .counts.blob_occurrences_checked==16 and .counts.text_blobs_scanned==12 and .counts.binary_blobs_classified==4 and .counts.font_blobs_validated==4' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null

export MOCK_CASE=midrun-cache-corrupt
new_case midrun-cache-corrupt
run_scan 2 --account personal --repo test/repo
grep -q 'SHA validation failed' "$T/result"
jq -e '.scan_complete==false and .counts.refs_checked==1 and .counts.refs_attempted==2' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
echo 'PASS same-run clean memo cannot hide later same-size byte corruption'

export MOCK_CASE=path-sensitive
new_case path-sensitive
run_scan 1 --account personal --repo test/repo --ref main
grep -q 'long-line.*vite.config.mjs' "$T/result"
echo 'PASS clean byte memo respects exact path detection rules'

export MOCK_CASE=infected
new_case repeated-findings
run_scan 1 --account personal --repo test/repo
[ "$(grep -c 'worm-marker.*src/tiny.js' "$T/result")" = 2 ]
jq -e '[.findings[]|select(.path=="src/tiny.js")|.ref]|unique|length==2' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
echo 'PASS repeated infected blobs retain findings on every affected ref'

export MOCK_CASE=sort-error
new_case inventory-transform
printf 'personal\ttest/readonly\n' > "$WORMGUARD_REPOS_FILE"
run_scan 2 --account personal
grep -q 'repository inventory merge failed' "$T/result"
echo 'PASS inventory merge command failure cannot silently drop repositories'

export MOCK_CASE=clean
new_case env-token
export GITHUB_TOKEN=must-not-reach-personal
export GH_HOST=hostile.example
run_scan 0 --account personal --repo test/repo --ref main
unset GITHUB_TOKEN
unset GH_HOST
echo 'PASS personal account clears inherited token variables and pins github.com'

export MOCK_CASE=inventory-missing
new_case missing
printf 'personal\ttest/missing\n' > "$WORMGUARD_REPOS_FILE"
run_scan 2 --account personal
grep -q 'read access could not be verified' "$T/result"
echo 'PASS inaccessible inventory repository cannot be silently skipped'

export MOCK_CASE=ignore-other
new_case ignore
printf 'personal\ttest/readonly\nwork\tbad repo\n' > "$WORMGUARD_REPOS_FILE"
run_scan 0 --account personal
echo 'PASS explicit account ignores other-account inventory rows'

export MOCK_CASE=empty-auto
new_case bad-inventory
printf 'other\ttest/repo\n' > "$WORMGUARD_REPOS_FILE"
run_scan 2
grep -q 'unsupported account' "$T/result"
echo 'PASS unfiltered invalid inventory account fails closed'

export MOCK_CASE=tagged
new_case default-tips
run_scan 0 --account personal --repo test/repo
jq -e '.request.ref_scope=="all-current-tips" and .counts.refs_checked==3 and ([.refs[].ref]|sort)==["refs/heads/main","refs/heads/page-two","refs/tags/v1"]' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
[ ! -e "$WORMGUARD_STATE/watch-personal.tsv" ]
! grep -q '/activity' "$MOCK_LOG"
: > "$MOCK_LOG"
run_scan 0 --account personal --repo test/repo
jq -e '.counts.refs_checked==3' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
! grep -q '/activity' "$MOCK_LOG"
echo 'PASS every manual run scans all current branch and tag tips without activity state'

export MOCK_CASE=refs-error
new_case refs-error
run_scan 2 --account personal --repo test/repo
jq -e '.scan_complete==false and .counts.incomplete_checks>0' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
echo 'PASS failed ref enumeration cannot produce a complete manual scan'

export MOCK_CASE=pages-merged
new_case pages-merged
run_scan 0 --account personal --repo test/repo
jq -e '.scan_complete and .counts.refs_checked==2' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
echo 'PASS older gh merged pagination output retains all refs'
for MOCK_CASE in pages-empty pages-malformed pages-object pages-rate; do
  export MOCK_CASE
  new_case "$MOCK_CASE"
  run_scan 2 --account personal --repo test/repo
  jq -e '.scan_complete==false and .status=="incomplete"' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
  ! grep -q '/commits/' "$MOCK_LOG"
done
[ "$(grep -c '/branches?' "$MOCK_LOG")" = 1 ]
echo 'PASS empty/malformed page streams fail closed and rate-limit errors stop pagination'

export MOCK_CASE=clean
new_case ci
export GH_TOKEN=fixture-token
run_scan 0 --account ci --repo test/repo --ref main
unset GH_TOKEN
grep -q 'github-actions' "$T/result"
echo 'PASS CI installation-token mode does not require user endpoint'

export EXPECT_DEFAULT_AUTH=1
export GH_CONFIG_DIR="$T/normal-gh-config"
export EXPECTED_GH_CONFIG="$GH_CONFIG_DIR"
export EXPECTED_GH_TOKEN=unset EXPECTED_GITHUB_TOKEN=unset
unset GH_TOKEN GITHUB_TOKEN
export MOCK_CASE=inactive-auth
new_case default-config
run_scan 0 --account default --repo test/repo
! grep -q '^auth ' "$MOCK_LOG"
grep -q '^api rate_limit$' "$MOCK_LOG"
grep -q '^api repos/test/repo$' "$MOCK_LOG"
! grep -q '^api user' "$MOCK_LOG"
jq -e '.request.account=="default" and .request.ref_scope=="all-current-tips" and .counts.refs_checked==2' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
echo 'PASS default account checks selected API credentials despite unrelated inactive authentication failure'

export GH_TOKEN=fixture-default-token GITHUB_TOKEN=fixture-github-token
export EXPECTED_GH_TOKEN="$GH_TOKEN" EXPECTED_GITHUB_TOKEN="$GITHUB_TOKEN"
new_case default-tokens
run_scan 0 --account default --repo test/repo --ref main
jq -e '.request.ref_scope=="single-ref" and .counts.refs_checked==1' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
unset GH_TOKEN
export EXPECTED_GH_TOKEN=unset
new_case default-github-token
run_scan 0 --account default --repo test/repo --ref main
echo 'PASS default account preserves both token variables and GITHUB_TOKEN alone'

unset GH_CONFIG_DIR GITHUB_TOKEN
export EXPECTED_GH_CONFIG=unset EXPECTED_GITHUB_TOKEN=unset
export MOCK_CASE=default-auth
new_case default-no-auth
run_scan 2 --account default --repo test/repo
jq -e '.status=="incomplete" and .scan_complete==false and .counts.repositories_checked==0' "$WORMGUARD_STATE/scan-last-run.json" >/dev/null
! grep -q '^api repos/' "$MOCK_LOG"
unset EXPECT_DEFAULT_AUTH EXPECTED_GH_CONFIG EXPECTED_GH_TOKEN EXPECTED_GITHUB_TOKEN
echo 'PASS missing default authentication produces incomplete evidence without repository requests'

export MOCK_CASE=clean
new_case cli
run_scan 2 --account default
run_scan 2 --account default --all-readable
run_scan 2 --account ci --repo test/repo --ref main
run_scan 2 --repo
run_scan 2 --ref main
run_scan 2 --deep
run_scan 2 --reset
run_scan 2 --since 2025-01-01T00:00:00Z
run_scan 2 --quiet
run_scan 2 --all-readable --repo test/repo
[ ! -s "$MOCK_LOG" ]
echo 'PASS invalid CLI combinations fail closed'

ln -s "$ROOT/scan_remote.sh" "$T/bin/scan-remote.sh"
"$SCANNER_BASH" "$T/bin/scan-remote.sh" --selftest > "$T/selftest" 2>&1
grep -q 'selftest passed' "$T/selftest"
echo 'PASS installed remote symlink loads and exercises the shared detector'

echo "All remote scanner integration tests passed with $SCANNER_BASH (no network)."
