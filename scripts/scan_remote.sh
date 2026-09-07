#!/usr/bin/env bash
#
# scan_remote.sh                    scan all branch/tag tips in the explicit inventory
# scan_remote.sh --all-readable     opt in to all readable GitHub repositories
# scan_remote.sh --account personal check one configured account
# scan_remote.sh --account default --repo owner/name use normal gh authentication
# scan_remote.sh --repo owner/name  check one readable repository
# scan_remote.sh --repo R --ref REF scan one ref or immutable commit
# scan_remote.sh --selftest         run local detector checks without network
#
# Every GitHub request is a GET. Repository content is decoded as inert bytes,
# checked against its Git blob SHA and size, and never executed or checked out.
#
# Exit 0: requested coverage completed without campaign or review signals.
# Exit 1: requested coverage completed with campaign or review signals.
# Exit 2: requested coverage is incomplete or could not be proved.

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
set -o pipefail
export LC_ALL=C
export GH_HOST=github.com

ALL_READABLE=0
ONLY_ACCOUNT=""
ONLY_REPO=""
ONLY_REF=""
SELFTEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --account|--repo|--ref)
      [ $# -ge 2 ] && [ -n "$2" ] || { echo "missing value for $1" >&2; exit 2; } ;;
  esac
  case "$1" in
    --all-readable) ALL_READABLE=1; shift ;;
    --account) ONLY_ACCOUNT="$2"; shift 2 ;;
    --repo) ONLY_REPO="$2"; shift 2 ;;
    --ref) ONLY_REF="$2"; shift 2 ;;
    --selftest) SELFTEST=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ "$ALL_READABLE" = 0 ] || [ -z "$ONLY_REPO" ] || { echo '--all-readable cannot be combined with --repo' >&2; exit 2; }
[ -z "$ONLY_REF" ] || [ -n "$ONLY_REPO" ] || { echo '--ref requires --repo' >&2; exit 2; }
[ -z "$ONLY_REPO" ] || printf '%s' "$ONLY_REPO" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || { echo '--repo must be owner/name' >&2; exit 2; }
case "$ONLY_ACCOUNT" in
  ""|personal|work) ;;
  default)
    [ -n "$ONLY_REPO" ] || { echo '--account default requires --repo' >&2; exit 2; } ;;
  ci)
    [ -n "$ONLY_REPO" ] && [ -n "$ONLY_REF" ] || { echo '--account ci requires --repo and --ref' >&2; exit 2; }
    [ -n "${GH_TOKEN:-}" ] || { echo '--account ci requires GH_TOKEN' >&2; exit 2; } ;;
  *) echo "unknown account: $ONLY_ACCOUNT" >&2; exit 2 ;;
esac

red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
grn() { printf '\033[0;32m%s\033[0m\n' "$1"; }
ylw() { printf '\033[1;33m%s\033[0m\n' "$1"; }
hdr() { printf '\n\033[1m%s\033[0m\n' "$1"; }

STATE_DIR="${WORMGUARD_STATE:-$HOME/.local/state/worm-guard}"
GH_CONFIG_ROOT="${WORMGUARD_GH_CONFIG_ROOT:-$HOME/.config}"
REPOS_FILE="${WORMGUARD_REPOS_FILE:-$STATE_DIR/repos.tsv}"
EVIDENCE_FILE="$STATE_DIR/scan-last-run.json"
CACHE_DIR="$STATE_DIR/blob-cache"
RUN_STARTED=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
RUN_ID="${WORMGUARD_RUN_ID:-$RUN_STARTED-$$}"
RUN_FINISHED=0
STOP_REASON=""

findings=0
reviews=0
advisories=0
repeated_console_items=0
unknowns=0
accounts_checked=0
repos_checked=0
refs_attempted=0
refs_checked=0
blob_occurrences=0
unique_blobs=0
cache_hits=0
detector_cache_hits=0
text_blobs=0
binary_blobs=0
font_blobs=0
gitlinks=0
API_STOP=0
WORK=""
EVIDENCE_READY=0
EVIDENCE_FAILED=0

record_json() { # destination kind message repo ref sha path
  if ! jq -nc --arg kind "$2" --arg message "$3" --arg repo "${4:-}" \
    --arg ref "${5:-}" --arg sha "${6:-}" --arg path "${7:-}" \
    '{kind:$kind,message:$message,repo:$repo,ref:$ref,sha:$sha,path:$path}' >> "$1"; then
    EVIDENCE_FAILED=1
  fi
  return 0
}
show_signal() { # severity message; evidence is recorded separately on every ref
  local key
  if [ "$EVIDENCE_READY" = 1 ]; then
    if key=$(printf '%s\0' "${CURRENT_REPO:-}" "${CURRENT_BLOB_SHA:-${CURRENT_SHA:-}}" "${CURRENT_PATH:-}" "$1" "$2" | git hash-object --stdin); then
      if [ -f "$WORK/shown/$key" ]; then
        repeated_console_items=$((repeated_console_items + 1))
        return
      fi
      : > "$WORK/shown/$key" || EVIDENCE_FAILED=1
    else
      EVIDENCE_FAILED=1
    fi
  fi
  case "$1" in
    indicator) red "  !! $2" ;;
    review) ylw "  ?  $2" ;;
    advisory) printf '  i  %s\n' "$2" ;;
  esac
}
note() {
  show_signal indicator "$1"
  findings=$((findings + 1))
  [ "$EVIDENCE_READY" = 0 ] || record_json "$WORK/findings.jsonl" indicator "$1" "${CURRENT_REPO:-}" "${CURRENT_REF:-}" "${CURRENT_SHA:-}" "${CURRENT_PATH:-}"
}
review() {
  show_signal review "$1"
  reviews=$((reviews + 1))
  [ "$EVIDENCE_READY" = 0 ] || record_json "$WORK/reviews.jsonl" review "$1" "${CURRENT_REPO:-}" "${CURRENT_REF:-}" "${CURRENT_SHA:-}" "${CURRENT_PATH:-}"
}
advisory() {
  show_signal advisory "$1"
  advisories=$((advisories + 1))
  [ "$EVIDENCE_READY" = 0 ] || record_json "$WORK/advisories.jsonl" advisory "$1" "${CURRENT_REPO:-}" "${CURRENT_REF:-}" "${CURRENT_SHA:-}" "${CURRENT_PATH:-}"
}
unknown() {
  red "  ?? $1"
  unknowns=$((unknowns + 1))
  [ "$EVIDENCE_READY" = 0 ] || record_json "$WORK/incomplete.jsonl" incomplete "$1" "${CURRENT_REPO:-}" "${CURRENT_REF:-}" "${CURRENT_SHA:-}" "${CURRENT_PATH:-}"
}

write_evidence() { # exit status
  local rc=$1 status finished tmp complete=false
  [ "$EVIDENCE_READY" = 1 ] || return 0
  finished=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  case "$rc" in
    0) status=clean ;;
    1) status=findings ;;
    *) status=incomplete ;;
  esac
  if [ "$RUN_FINISHED" = 1 ] && { [ "$rc" = 0 ] || [ "$rc" = 1 ]; }; then complete=true; fi
  tmp="$EVIDENCE_FILE.tmp.$$"
  jq -n \
    --arg started_at "$RUN_STARTED" --arg finished_at "$finished" --arg status "$status" \
    --arg run_id "$RUN_ID" --argjson scan_complete "$complete" \
    --arg account_filter "$ONLY_ACCOUNT" --arg repo_filter "$ONLY_REPO" --arg ref_filter "$ONLY_REF" \
    --arg inventory "$REPOS_FILE" --argjson all_readable "$ALL_READABLE" \
    --argjson exit_code "$rc" \
    --argjson accounts "$accounts_checked" --argjson repos "$repos_checked" \
    --argjson refs_attempted "$refs_attempted" --argjson refs_checked "$refs_checked" \
    --argjson blob_occurrences "$blob_occurrences" --argjson unique_blobs "$unique_blobs" \
    --argjson cache_hits "$cache_hits" --argjson text_blobs "$text_blobs" \
    --argjson detector_cache_hits "$detector_cache_hits" \
    --argjson binary_blobs "$binary_blobs" --argjson font_blobs "$font_blobs" \
    --argjson gitlinks "$gitlinks" --argjson findings_count "$findings" \
    --argjson reviews_count "$reviews" --argjson incomplete_count "$unknowns" \
    --argjson advisory_count "$advisories" \
    --slurpfile ref_rows "$WORK/refs.jsonl" --slurpfile finding_rows "$WORK/findings.jsonl" \
    --slurpfile review_rows "$WORK/reviews.jsonl" --slurpfile incomplete_rows "$WORK/incomplete.jsonl" \
    --slurpfile advisory_rows "$WORK/advisories.jsonl" \
    --slurpfile exclusion_rows "$WORK/exclusions.jsonl" '
      {schema:1,run_id:$run_id,scan_complete:$scan_complete,started_at:$started_at,finished_at:$finished_at,status:$status,exit_code:$exit_code,
       request:{account:$account_filter,repo:$repo_filter,ref:$ref_filter,ref_scope:(if $ref_filter=="" then "all-current-tips" else "single-ref" end),inventory_file:$inventory,all_readable:($all_readable==1)},
       counts:{accounts_checked:$accounts,repositories_checked:$repos,refs_attempted:$refs_attempted,
         refs_checked:$refs_checked,blob_occurrences_checked:$blob_occurrences,unique_blobs_verified:$unique_blobs,
         verified_cache_hits:$cache_hits,text_blobs_scanned:$text_blobs,binary_blobs_classified:$binary_blobs,
         clean_detector_results_reused:$detector_cache_hits,
         font_blobs_validated:$font_blobs,gitlinks_omitted:$gitlinks,findings:$findings_count,
         review_items:$reviews_count,advisory_items:$advisory_count,incomplete_checks:$incomplete_count},
       refs:$ref_rows,findings:$finding_rows,reviews:$review_rows,incomplete:$incomplete_rows,
       advisories:$advisory_rows,
       exclusions:$exclusion_rows,
       coverage:["requested: fetch every blob in each returned recursive tree or load it from verified cache",
         "requested: check decoded blobs against Git blob SHA and size",
         "requested: scan all text without a size threshold",
         "requested: validate tracked font-extension blobs by format magic; scan_complete determines whether requested checks finished"],
       limitations:["current branch and tag tips only; commit history, pull-request refs, releases, LFS objects, Actions artifacts, packages, and gists are outside this run",
         "recursive Git trees are an API view; a truncated or malformed tree makes the run incomplete",
         "gitlinks are recorded but submodule repositories are not recursively scanned",
         "binary blobs receive fixed indicator-byte checks, not executable analysis or proof of safety",
         "verified decoded blobs are retained in the local state cache until that cache is manually removed",
         "signature detection cannot prove absence of an unknown variant"]}' > "$tmp" && mv "$tmp" "$EVIDENCE_FILE"
}

print_summary() {
  echo
  case "$1" in
    0) grn 'COMPLETE — no campaign or review signals in the documented scope.' ;;
    1) ylw 'COMPLETE — campaign or review signals require investigation.' ;;
    *) red 'INCOMPLETE — requested coverage could not be established.' ;;
  esac
  printf 'Coverage: %s account(s), %s repo(s), %s/%s ref(s); %s blob occurrence(s), %s unique verified blob(s), %s cache hit(s).\n' \
    "$accounts_checked" "$repos_checked" "$refs_checked" "$refs_attempted" "$blob_occurrences" "$unique_blobs" "$cache_hits"
  printf 'Signals: %s campaign match(es), %s review signal(s), %s advisory item(s); %s incomplete check(s).\n' \
    "$findings" "$reviews" "$advisories" "$unknowns"
  if [ "$repeated_console_items" -gt 0 ]; then
    printf '%s repeated message(s) omitted above; every ref occurrence remains in JSON evidence.\n' "$repeated_console_items"
  fi
  [ "$gitlinks" -eq 0 ] || ylw "$gitlinks gitlink(s) were recorded as omissions; this is not a full submodule-content verdict."
  printf 'Matches do not establish execution or infection. Evidence: %s\n' "$EVIDENCE_FILE"
}

finish() {
  local rc=$?
  trap - EXIT
  trap '' HUP INT TERM
  if [ "$EVIDENCE_READY" = 1 ]; then
    if [ "$RUN_FINISHED" != 1 ] || [ -n "$STOP_REASON" ]; then
      unknown "${STOP_REASON:-scan ended before all requested checks finished}"
      rc=2
    fi
    if [ "$unknowns" -gt 0 ] || [ "$repos_checked" -eq 0 ] ||
       [ "$accounts_checked" -eq 0 ] || [ "$refs_checked" -ne "$refs_attempted" ]; then
      rc=2
    elif [ "$rc" = 0 ] || [ "$rc" = 1 ]; then
      if [ "$findings" -gt 0 ] || [ "$reviews" -gt 0 ]; then rc=1; else rc=0; fi
    else
      rc=2
    fi
  fi
  [ "$EVIDENCE_FAILED" = 0 ] || rc=2
  if ! write_evidence "$rc"; then
    red "could not write $EVIDENCE_FILE"
    rc=2
  fi
  [ "$EVIDENCE_READY" = 0 ] || print_summary "$rc"
  [ -z "$WORK" ] || rm -rf "$WORK"
  exit "$rc"
}
trap finish EXIT
trap 'STOP_REASON="scan interrupted by SIGHUP"; exit 2' HUP
trap 'STOP_REASON="scan interrupted by SIGINT"; exit 2' INT
trap 'STOP_REASON="scan interrupted by SIGTERM"; exit 2' TERM

# This self-test operates only on inert fixtures and needs no API.
if [ "$SELFTEST" = 1 ]; then
  worm_guard_runtime || exit 2
  t=$(mktemp -d) || exit 2
  pad=$(printf '\t%.0s' $(seq 1 80))
  printf 'const safe = 1;%srequire("child_process")\n' "$pad" > "$t/tiny.js"
  printf '%s\n' "$(printf 'x%.0s' $(seq 1 4000))" > "$t/minified.js"
  printf 'import {create%s} from "module"; const require=create%s(import.meta.url);\n' Require Require > "$t/shim.mjs"
  fail=0
  worm_guard_python "$WORM_GUARD_SCRIPT_DIR/worm_guard_patterns.py" text tiny.js "$t/tiny.js" > "$t/result" || fail=1
  grep -q 'hidden-padding' "$t/result" || fail=1
  worm_guard_python "$WORM_GUARD_SCRIPT_DIR/worm_guard_patterns.py" text bundle.js "$t/minified.js" > "$t/result" || fail=1
  [ ! -s "$t/result" ] || fail=1
  worm_guard_python "$WORM_GUARD_SCRIPT_DIR/worm_guard_patterns.py" text shim.mjs "$t/shim.mjs" > "$t/result" || fail=1
  grep -q '^finding' "$t/result" && fail=1
  rm -rf "$t"
  [ "$fail" = 0 ] && { grn 'selftest passed'; exit 0; }
  red 'selftest failed'
  exit 1
fi

for tool in gh jq base64 awk grep wc file git iconv; do
  command -v "$tool" >/dev/null || { red "$tool is not installed"; exit 2; }
done
worm_guard_runtime || exit 2
umask 077
WORK=$(mktemp -d) || exit 2
mkdir -p "$STATE_DIR" "$CACHE_DIR" "$WORK/verified" "$WORK/clean-results" "$WORK/shown" || exit 2
chmod 700 "$STATE_DIR" "$CACHE_DIR" 2>/dev/null || exit 2
for evidence_part in refs findings reviews advisories incomplete exclusions; do
  : > "$WORK/$evidence_part.jsonl" || exit 2
done
EVIDENCE_READY=1

api_list() { # endpoint destination
  local attempt error="$WORK/api.error"
  for attempt in 1 2 3; do
    [ "$API_STOP" = 0 ] || return 1
    if gh api "$1" --paginate 2> "$error" | jq -s > "$2.tmp" &&
       jq -e 'if type=="array" and length>0 and all(.[]; type=="array") then true else error("invalid pages") end' "$2.tmp" >/dev/null 2>&1; then
      jq 'add' "$2.tmp" > "$2" && rm -f "$2.tmp" && return 0
    fi
    if grep -Eiq 'rate.?limit|secondary rate' "$error"; then API_STOP=1; return 1; fi
    rm -f "$2.tmp"
    sleep $((attempt * 3))
  done
  return 1
}

api_get() { # endpoint destination
  local error="$WORK/api.error"
  [ "$API_STOP" = 0 ] || return 1
  if gh api "$1" > "$2" 2> "$error"; then
    return 0
  fi
  if grep -Eiq 'rate.?limit|secondary rate' "$error"; then API_STOP=1; fi
  return 1
}

fetch_tree() { # repo commit-sha destination
  local attempt error="$WORK/api.error"
  for attempt in 1 2 3; do
    [ "$API_STOP" = 0 ] || return 1
    if gh api "repos/$1/git/trees/$2?recursive=1" > "$3.tmp" 2> "$error" &&
       jq -e '(.tree|type)=="array" and (.truncated|type)=="boolean" and
         all(.tree[]; (.path|type)=="string" and (.sha|type)=="string" and (.mode|type)=="string" and
           (.type=="tree" or .type=="commit" or (.type=="blob" and (.size|type)=="number")))' "$3.tmp" >/dev/null 2>&1; then
      mv "$3.tmp" "$3"
      return 0
    fi
    if grep -Eiq 'rate.?limit|secondary rate' "$error"; then API_STOP=1; return 1; fi
    rm -f "$3.tmp"
    sleep $((attempt * 3))
  done
  return 1
}

verify_blob_file() { # file sha size
  local actual_size actual_sha
  actual_size=$(wc -c < "$1" | tr -d ' ') || return 1
  [ "$actual_size" = "$3" ] || return 1
  actual_sha=$(git hash-object --no-filters "$1" 2>/dev/null) || return 1
  [ "$actual_sha" = "$2" ]
}

BLOB_PATH=""
read_blob() { # repo sha expected-size
  local repo=$1 sha=$2 expected=$3 cache="$CACHE_DIR/$2" json="$WORK/blob.json" decoded="$WORK/blob.decoded" attempt error="$WORK/api.error"
  BLOB_PATH="$cache"
  blob_occurrences=$((blob_occurrences + 1))
  if [ -f "$WORK/verified/$sha" ]; then
    verify_blob_file "$cache" "$sha" "$expected" || return 1
    cache_hits=$((cache_hits + 1))
    return 0
  fi
  if [ -f "$cache" ]; then
    verify_blob_file "$cache" "$sha" "$expected" || return 1
    : > "$WORK/verified/$sha"
    cache_hits=$((cache_hits + 1))
    unique_blobs=$((unique_blobs + 1))
    return 0
  fi
  for attempt in 1 2 3; do
    [ "$API_STOP" = 0 ] || return 1
    rm -f "$json" "$decoded"
    if gh api "repos/$repo/git/blobs/$sha" > "$json" 2> "$error" &&
       jq -e --arg sha "$sha" --argjson size "$expected" \
         '.sha==$sha and .encoding=="base64" and (.content|type)=="string" and .size==$size' "$json" >/dev/null 2>&1 &&
       jq -r '.content' "$json" | base64 -d > "$decoded" 2>/dev/null &&
       verify_blob_file "$decoded" "$sha" "$expected"; then
      chmod 600 "$decoded" 2>/dev/null || :
      mv "$decoded" "$cache" || return 1
      : > "$WORK/verified/$sha"
      unique_blobs=$((unique_blobs + 1))
      BLOB_PATH="$cache"
      return 0
    fi
    if grep -Eiq 'rate.?limit|secondary rate' "$error"; then API_STOP=1; return 1; fi
    sleep $((attempt * 3))
  done
  rm -f "$json" "$decoded"
  return 1
}

is_font_path() {
  printf '%s\n' "$1" | grep -Eiq '\.(woff2?|ttf|otf|ttc|eot)$'
}

detect_blob() { # mode path inert-file
  local mode="$1" path="$2" body="$3" kind label reason
  if ! worm_guard_python "$WORM_GUARD_SCRIPT_DIR/worm_guard_patterns.py" "$mode" "$path" "$body" > "$WORK/detection.tsv"; then
    unknown "${DISPLAY_PATH:-path} — shared detector could not complete"
    return
  fi
  while IFS=$'\t' read -r kind label reason; do
    case "$kind" in
      finding) note "$label ${DISPLAY_PATH:-path} — $reason" ;;
      review) review "$label ${DISPLAY_PATH:-path} — $reason" ;;
      advisory) advisory "$label ${DISPLAY_PATH:-path} — $reason" ;;
      *) unknown "shared detector returned an invalid result" ;;
    esac
  done < "$WORK/detection.tsv"
}

scan_text() {
  text_blobs=$((text_blobs + 1))
  detect_blob text "$1" "$2"
}

scan_ref() { # repo display-ref optional-known-sha
  local repo=$1 display_ref=$2 requested=${3:-$2} commit="$WORK/commit.json" tree="$WORK/tree.json"
  local sha before_unknowns encoded entry path bsha bsize btype mode encoding ref_outcome display_path
  local memo memo_text memo_binary memo_font memo_extra detector_unknowns detector_findings detector_reviews detector_advisories
  local before_text before_binary before_font
  CURRENT_REPO=$repo CURRENT_REF=$display_ref CURRENT_SHA="" CURRENT_PATH="" CURRENT_BLOB_SHA=""
  before_unknowns=$unknowns
  refs_attempted=$((refs_attempted + 1))
  if ! encoded=$(jq -rn --arg ref "$requested" '$ref | @uri'); then
    unknown "$repo [$display_ref] ref encoding failed — ref not checked"
    record_json "$WORK/refs.jsonl" incomplete "ref encoding failed" "$repo" "$display_ref" "" ""
    return
  fi
  if ! api_get "repos/$repo/commits/$encoded" "$commit" ||
     ! jq -e '(.sha|test("^[a-f0-9]{40}$")) and (.commit.author|type)=="object" and (.commit.committer|type)=="object"' "$commit" >/dev/null 2>&1; then
    unknown "$repo [$display_ref] commit unreadable — ref not checked"
    record_json "$WORK/refs.jsonl" incomplete "commit unreadable" "$repo" "$display_ref" "" ""
    return
  fi
  sha=$(jq -r '.sha' "$commit")
  CURRENT_SHA=$sha
  if printf '%s' "$requested" | grep -Eq '^[a-f0-9]{40}$' && [ "$sha" != "$requested" ]; then
    unknown "$repo [$display_ref] resolved to $sha, expected immutable $requested"
    record_json "$WORK/refs.jsonl" incomplete "immutable SHA mismatch" "$repo" "$display_ref" "$sha" ""
    return
  fi
  printf '  checking %s [%s] commit %s\n' "$repo" "$display_ref" "$sha"
  if jq -e '.commit as $c | $c.author.name != $c.committer.name and $c.author.email == $c.committer.email' "$commit" >/dev/null 2>&1; then
    review "ghost-commit metadata: same email but different author/committer names"
  fi
  if ! fetch_tree "$repo" "$sha" "$tree"; then
    unknown "$repo [$display_ref] tree unreadable after 3 tries — ref not checked"
    record_json "$WORK/refs.jsonl" incomplete "tree unreadable" "$repo" "$display_ref" "$sha" ""
    return
  fi
  if [ "$(jq -r '.truncated' "$tree")" = true ]; then
    unknown "$repo [$display_ref] recursive tree is truncated — returned blobs will be scanned but coverage is incomplete"
  fi
  if ! jq -r '.tree[] | select(.type=="blob" or .type=="commit") |
      if (.path|type)=="string" and (.path|length)>0 and (.path|contains("\u0000")|not) and
         (.sha|test("^[a-f0-9]{40}$")) and (.mode|type)=="string" and
         (.type=="commit" or (.size|type=="number" and .>=0 and floor==.))
      then [(.path|@base64),.sha,.type,.mode,(.size//0)] | @tsv
      else error("invalid tree entry") end' "$tree" > "$WORK/entries"; then
    unknown "$repo [$display_ref] tree entries could not be enumerated"
    record_json "$WORK/refs.jsonl" incomplete "tree enumeration failed" "$repo" "$display_ref" "$sha" ""
    return
  fi
  while IFS=$'\t' read -r encoded bsha btype mode bsize; do
    [ -n "$encoded" ] || continue
    # The sentinel preserves trailing newlines in Git paths during substitution.
    path=$(printf '%s' "$encoded" | base64 -d 2>/dev/null && printf '.') || { unknown "$repo [$display_ref] tree path could not be decoded"; continue; }
    path=${path%.}
    CURRENT_PATH=$path
    CURRENT_BLOB_SHA=$bsha
    if [ "$btype" = commit ] || [ "$mode" = 160000 ]; then
      gitlinks=$((gitlinks + 1))
      record_json "$WORK/exclusions.jsonl" gitlink "submodule content not recursively scanned" "$repo" "$display_ref" "$bsha" "$path"
      continue
    fi
    if ! read_blob "$repo" "$bsha" "$bsize"; then
      display_path=$(printf '%s' "$path" | jq -Rs '.') || display_path='(path unavailable)'
      unknown "$repo [$display_ref] $display_path — blob read, size, or SHA validation failed"
      [ "$API_STOP" = 0 ] || break
      continue
    fi
    # Reuse only clean detector results within this run, after rehashing bytes.
    # Exact paths matter: identical bytes can be safe source but a fake font.
    memo=$(printf '%s\0%s' "$bsha" "$path" | git hash-object --stdin) || { unknown "$repo [$display_ref] detector cache key failed"; continue; }
    memo="$WORK/clean-results/$memo"
    if [ -f "$memo" ]; then
      IFS=' ' read -r memo_text memo_binary memo_font memo_extra < "$memo"
      case "$memo_text $memo_binary $memo_font $memo_extra" in
        '1 0 0 '|'0 1 0 '|'1 0 1 '|'0 1 1 ')
          text_blobs=$((text_blobs + memo_text))
          binary_blobs=$((binary_blobs + memo_binary))
          font_blobs=$((font_blobs + memo_font))
          detector_cache_hits=$((detector_cache_hits + 1))
          continue ;;
        *) unknown "$repo [$display_ref] invalid detector cache entry" ;;
      esac
    fi
    display_path=$(printf '%s' "$path" | jq -Rs '.') || { unknown "$repo [$display_ref] tree path could not be escaped for display"; continue; }
    DISPLAY_PATH=$display_path
    detector_unknowns=$unknowns detector_findings=$findings detector_reviews=$reviews detector_advisories=$advisories
    before_text=$text_blobs before_binary=$binary_blobs before_font=$font_blobs
    detect_blob metadata "$path" "$BLOB_PATH"
    if is_font_path "$path"; then font_blobs=$((font_blobs + 1)); fi
    encoding=$(file -b --mime-encoding "$BLOB_PATH" 2>/dev/null) || { unknown "$repo [$display_ref] $display_path — content classification failed"; continue; }
    if [ "$encoding" = binary ]; then
      binary_blobs=$((binary_blobs + 1))
      detect_blob binary "$path" "$BLOB_PATH"
    elif [ "$encoding" = us-ascii ] || [ "$encoding" = utf-8 ] || [ "$encoding" = unknown-8bit ]; then
      scan_text "$path" "$BLOB_PATH"
    else
      if iconv -f "$encoding" -t UTF-8 "$BLOB_PATH" > "$WORK/text.decoded" 2>/dev/null; then
        scan_text "$path" "$WORK/text.decoded"
      else
        unknown "$repo [$display_ref] $display_path — text encoding '$encoding' could not be decoded for signature scanning"
      fi
    fi
    if [ "$unknowns" = "$detector_unknowns" ] && [ "$findings" = "$detector_findings" ] &&
       [ "$reviews" = "$detector_reviews" ] && [ "$advisories" = "$detector_advisories" ]; then
      printf '%s %s %s\n' "$((text_blobs - before_text))" "$((binary_blobs - before_binary))" "$((font_blobs - before_font))" > "$memo" || unknown "$repo [$display_ref] detector cache write failed"
    fi
  done < "$WORK/entries"
  CURRENT_PATH=""
  CURRENT_BLOB_SHA=""
  if [ "$unknowns" = "$before_unknowns" ]; then
    refs_checked=$((refs_checked + 1))
    ref_outcome=checked
  else
    ref_outcome=incomplete
  fi
  record_json "$WORK/refs.jsonl" "$ref_outcome" "$ref_outcome" "$repo" "$display_ref" "$sha" ""
  printf '  %s [%s]: %s; %s blob occurrence(s) checked so far\n' "$repo" "$display_ref" "$ref_outcome" "$blob_occurrences"
}

all_refs() { # repo destination
  local branches="$WORK/branches.json" tags="$WORK/tags.json"
  api_list "repos/$1/branches?per_page=100" "$branches" || return 1
  api_list "repos/$1/tags?per_page=100" "$tags" || return 1
  jq -nr --slurpfile branches "$branches" --slurpfile tags "$tags" '
    def rows($items;$kind): $items[] | if (.name|type)=="string" and (.commit.sha|test("^[a-f0-9]{40}$"))
      then "refs/\($kind)/\(.name)\t\(.commit.sha)" else error("invalid ref") end;
    rows($branches[0];"heads"), rows($tags[0];"tags")' > "$2"
}

validate_inventory() {
  local line=0 account repo extra
  : > "$WORK/inventory.tsv"
  [ -e "$REPOS_FILE" ] || return 0
  [ -f "$REPOS_FILE" ] && [ -r "$REPOS_FILE" ] || { unknown "inventory $REPOS_FILE is not a readable regular file"; return 1; }
  while IFS=$'\t' read -r account repo extra || [ -n "${account}${repo}${extra}" ]; do
    line=$((line + 1))
    case "$account" in ""|'#'*) continue ;; esac
    if [ -n "$ONLY_ACCOUNT" ] && [ "$account" != "$ONLY_ACCOUNT" ]; then
      continue
    fi
    case "$account" in personal|work) ;; *) unknown "inventory line $line has unsupported account '$account'"; continue ;; esac
    if ! printf '%s' "$repo" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || [ -n "$extra" ]; then
      unknown "inventory line $line must be: account TAB owner/repo"
      continue
    fi
    printf '%s\t%s\n' "$account" "$repo" >> "$WORK/inventory.tsv"
  done < "$REPOS_FILE"
}

validate_inventory || :
if [ -z "$ONLY_REPO" ] && [ "$ALL_READABLE" = 0 ] && [ ! -s "$WORK/inventory.tsv" ]; then
  unknown "no repositories in the requested scope; populate $REPOS_FILE or pass --repo (broad enumeration requires --all-readable)"
  RUN_FINISHED=1
  exit 2
fi

ACCOUNTS=""
if [ "$ONLY_ACCOUNT" = ci ]; then
  ACCOUNTS=ci
elif [ -n "$ONLY_ACCOUNT" ]; then
  ACCOUNTS=$ONLY_ACCOUNT
else
  for acct_candidate in personal work; do
    if { { [ "$ALL_READABLE" = 1 ] || [ -n "$ONLY_REPO" ]; } && [ -f "$GH_CONFIG_ROOT/gh-$acct_candidate/hosts.yml" ]; } || awk -F '\t' -v a="$acct_candidate" '$1==a{found=1} END{exit !found}' "$WORK/inventory.tsv"; then
      ACCOUNTS="$ACCOUNTS $acct_candidate"
    fi
  done
fi
[ -n "$ACCOUNTS" ] || unknown "no configured gh accounts or inventory entries found"

for acct in $ACCOUNTS; do
  API_STOP=0
  CURRENT_REPO="" CURRENT_REF="" CURRENT_SHA="" CURRENT_PATH=""
  account_unknowns=$unknowns
  account_repo_start=$repos_checked
  if [ "$acct" = ci ]; then
    login=github-actions
  elif [ "$acct" = default ]; then
    # Let gh select its normal config or environment token without modifying it.
    # The API budget and repository-read checks below validate selected credentials.
    login=github-cli
  else
    if [ ! -f "$GH_CONFIG_ROOT/gh-$acct/hosts.yml" ]; then
      unknown "account '$acct' is in scope but $GH_CONFIG_ROOT/gh-$acct/hosts.yml is missing"
      continue
    fi
    export GH_CONFIG_DIR="$GH_CONFIG_ROOT/gh-$acct"
    unset GH_TOKEN GITHUB_TOKEN 2>/dev/null || :
    if ! login=$(gh api user --jq '.login' 2>/dev/null) || ! printf '%s' "$login" | grep -Eq '^[A-Za-z0-9-]{1,39}$'; then
      unknown "account '$acct' authentication/API check failed"
      continue
    fi
  fi
  if ! gh api rate_limit > "$WORK/rate.json" 2>/dev/null ||
     ! rl=$(jq -er '.resources.core.remaining | select(type=="number" and .>=0 and floor==.)' "$WORK/rate.json"); then
    unknown "account '$acct' API budget unreadable"
    continue
  fi
  if [ "$rl" -lt 200 ]; then
    unknown "account '$acct' ($login) has only $rl API calls left — not scanned"
    continue
  fi
  hdr "account: $acct ($login)"
  : > "$WORK/repos"
  if [ -n "$ONLY_REPO" ]; then
    printf '%s\n' "$ONLY_REPO" > "$WORK/repos"
  elif [ "$ALL_READABLE" = 1 ]; then
    if ! api_list 'user/repos?affiliation=owner,collaborator,organization_member&per_page=100' "$WORK/repo-list.json" ||
       ! jq -e 'all(.[]; (.full_name|type)=="string" and (.permissions.pull|type)=="boolean")' "$WORK/repo-list.json" >/dev/null 2>&1 ||
       ! jq -r '.[] | select(.permissions.pull==true) | .full_name' "$WORK/repo-list.json" > "$WORK/repos.auto"; then
      unknown "$login repository enumeration failed (including pagination)"
      continue
    fi
    if ! awk -F '\t' -v a="$acct" '$1==a{print $2}' "$WORK/inventory.tsv" > "$WORK/repos.inventory" ||
       ! sort -u "$WORK/repos.auto" "$WORK/repos.inventory" > "$WORK/repos"; then
      unknown "$login repository inventory merge failed"
      continue
    fi
  fi
  if [ -z "$ONLY_REPO" ] && [ "$ALL_READABLE" = 0 ]; then
    if ! awk -F '\t' -v a="$acct" '$1==a{print $2}' "$WORK/inventory.tsv" | sort -u > "$WORK/repos"; then
      unknown "$login repository inventory merge failed"
      continue
    fi
  fi
  if [ ! -s "$WORK/repos" ]; then
    unknown "$login has zero repositories in the requested scope; populate the inventory or pass --repo"
    continue
  fi
  while IFS= read -r full; do
    [ -n "$full" ] || continue
    [ "$API_STOP" = 0 ] || break
    CURRENT_REPO=$full CURRENT_REF="" CURRENT_SHA="" CURRENT_PATH=""
    repo_unknowns=$unknowns
    if ! api_get "repos/$full" "$WORK/repo.json" ||
       ! jq -e --arg full "$full" '.full_name==$full and .permissions.pull==true' "$WORK/repo.json" >/dev/null 2>&1; then
      unknown "$full read access could not be verified for $login"
      continue
    fi
    if [ -n "$ONLY_REF" ]; then
      scan_ref "$full" "$ONLY_REF"
    else
      if ! all_refs "$full" "$WORK/refs.tsv"; then
        unknown "$full branch/tag enumeration failed"
        continue
      fi
      while IFS=$'\t' read -r ref_name ref_sha; do
        [ "$API_STOP" = 0 ] || break
        [ -n "$ref_name" ] && scan_ref "$full" "$ref_name" "$ref_sha"
      done < "$WORK/refs.tsv"
      [ -s "$WORK/refs.tsv" ] || printf '  %s: verified no branch or tag tips\n' "$full"
    fi
    [ "$unknowns" != "$repo_unknowns" ] || repos_checked=$((repos_checked + 1))
  done < "$WORK/repos"
  if [ "$API_STOP" = 1 ]; then
    unknown "account '$acct' scan stopped after an API rate-limit response; verified cache progress is retained"
  fi
  if [ "$unknowns" = "$account_unknowns" ] && [ "$repos_checked" -gt "$account_repo_start" ]; then
    accounts_checked=$((accounts_checked + 1))
  fi
done

RUN_FINISHED=1
exit 0
