#!/usr/bin/env bash
#
# worm-guard:allow-signatures
# watch_remotes.sh                    check every pushable remote since last run
# watch_remotes.sh --deep             scan every branch tip, not just the default
# watch_remotes.sh --account personal check one gh account only
# watch_remotes.sh --repo owner/name  check one repo only (skips enumeration)
# watch_remotes.sh --repo R --ref SHA scan one ref or sha and stop (no state)
# watch_remotes.sh --since 2026-08-20 ignore saved state, look back from a date
# watch_remotes.sh --reset            record "now" as seen, report nothing
# watch_remotes.sh --selftest         prove the indicator patterns can fail
#
# WHY THIS EXISTS
#   scan_repo.sh answers "is this clone infected". It cannot answer "did
#   someone force push to my remotes", because the attack never touches disk.
#   On 2026-09-04 six repositories in one org were rewritten server-side in
#   94 seconds with a stolen token. Nothing was cloned. Every local scanner
#   on this machine reported CLEAN and was telling the truth.
#   scan_repo.sh's own header says it: enumerate from the GitHub API, not disk.
#
# READ-ONLY BY CONSTRUCTION
#   Every call is a GET. There is no code path here that writes to GitHub,
#   moves a file, or kills a process. Restoring a rewritten branch is a
#   deliberate, separate act — this only tells you it happened.
#
# EXIT CODES
#   0 nothing new   1 indicators found   2 usage or auth error

set -u

DEEP=0
ONLY_ACCOUNT=""
ONLY_REPO=""
ONLY_REF=""
SINCE_OVERRIDE=""
RESET=0
QUIET=0
MAX_BRANCHES=40

while [ $# -gt 0 ]; do
  case "$1" in
    --deep)     DEEP=1; shift ;;
    --account)  ONLY_ACCOUNT="$2"; shift 2 ;;
    --repo)     ONLY_REPO="$2"; shift 2 ;;
    --ref)      ONLY_REF="$2"; shift 2 ;;
    --since)    SINCE_OVERRIDE="$2"; shift 2 ;;
    --reset)    RESET=1; shift ;;
    --quiet)    QUIET=1; shift ;;
    --selftest) SELFTEST=1; shift ;;
    -h|--help)  sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
grn() { printf '\033[0;32m%s\033[0m\n' "$1"; }
ylw() { printf '\033[1;33m%s\033[0m\n' "$1"; }
hdr() { printf '\n\033[1m%s\033[0m\n' "$1"; }

findings=0
note() { red "  !! $1"; findings=$((findings+1)); }
warn() { ylw "  ?  $1"; }

STATE_DIR="${WORMGUARD_STATE:-$HOME/.local/state/worm-guard}"

# ---------------------------------------------------------------- selftest ---
# The tab-padding bug in three other scanners in circulation was found by
# running them against a real sample, not by reading them. So the patterns get
# their own test. No network, no GitHub, no state.
if [ "${SELFTEST:-0}" = 1 ]; then
  t=$(mktemp -d); fail=0
  check() { # label file expect
    if grep -qE '[[:space:]]{50,}[^[:space:]]' "$2"; then got=HIT; else got=MISS; fi
    if [ "$got" = "$3" ]; then grn "  ok   $1 ($got)"; else red "  FAIL $1 (want $3, got $got)"; fail=1; fi
  }
  long() { # label file expect
    if awk 'length($0)>2000{exit 1}' "$2"; then got=MISS; else got=HIT; fi
    if [ "$got" = "$3" ]; then grn "  ok   $1 ($got)"; else red "  FAIL $1 (want $3, got $got)"; fail=1; fi
  }
  pad=$(printf '\t%.0s' $(seq 1 273))
  printf 'legit();%s payload()\n' "$(printf ' %.0s' $(seq 1 200))"      > "$t/spaces.js"
  printf 'legit();%s payload()\n' "$pad"                                > "$t/tabs.js"
  printf 'legit();%s%s\n' "$pad" "$(printf 'x%.0s' $(seq 1 7000))"      > "$t/real.js"
  printf 'legit();  payload()\n'                                        > "$t/normal.js"
  printf '%s\n' "$(printf 'x%.0s' $(seq 1 3000))"                       > "$t/nopad.js"

  hdr "padding pattern (whitespace class, so tabs count)"
  check "200 spaces"                "$t/spaces.js" HIT
  check "273 tabs, short payload"   "$t/tabs.js"   HIT
  check "real shape: tabs + 7000ch" "$t/real.js"   HIT
  check "3000ch, no padding"        "$t/nopad.js"  MISS
  check "ordinary line"             "$t/normal.js" MISS

  hdr "long-line pattern (awk, not grep: BSD grep caps intervals at 255)"
  long "real shape: tabs + 7000ch" "$t/real.js"   HIT
  long "3000ch, no padding"        "$t/nopad.js"  HIT
  long "273 tabs, short payload"   "$t/tabs.js"   MISS
  long "ordinary line"             "$t/normal.js" MISS
  echo "  the two MISS/HIT rows that disagree are the point: neither check"
  echo "  alone covers both shapes, which is why both exist."
  hdr "font magic bytes"
  printf '\x09\x09\x09\x09rest' > "$t/fake.woff2"
  printf 'wOF2rest'             > "$t/real.woff2"
  for f in fake real; do
    m=$(head -c 4 "$t/$f.woff2" | xxd -p)
    case "$m" in
      774f4632) [ "$f" = real ] && grn "  ok   real.woff2 recognised" || { red "  FAIL"; fail=1; } ;;
      *)        [ "$f" = fake ] && grn "  ok   fake.woff2 rejected (magic=$m)" || { red "  FAIL"; fail=1; } ;;
    esac
  done
  rm -rf "$t"
  echo
  [ "$fail" = 0 ] && { grn "selftest passed"; exit 0; } || { red "selftest FAILED"; exit 1; }
fi

# -------------------------------------------------------------------- setup ---
command -v gh >/dev/null || { red "gh is not installed (brew install gh)"; exit 2; }
command -v jq >/dev/null || { red "jq is not installed (brew install jq)"; exit 2; }
mkdir -p "$STATE_DIR"



# One gh config dir per account, the same split shell/.zshrc drives by
# directory. Listed explicitly rather than globbed so a stray dir cannot
# silently widen what this touches.
ACCOUNTS=()
for a in personal work; do
  [ -n "$ONLY_ACCOUNT" ] && [ "$a" != "$ONLY_ACCOUNT" ] && continue
  [ -f "$HOME/.config/gh-$a/hosts.yml" ] && ACCOUNTS+=("$a")
done
[ ${#ACCOUNTS[@]} -eq 0 ] && { red "no gh config dir found (looked for ~/.config/gh-{personal,work})"; exit 2; }

# --------------------------------------------------------------- indicators ---
# Fetch the tree ONCE per ref, with retries, and prove the response really is
# a tree before anyone reads it.
#
# Two bugs lived here. First, three separate functions each fetched this same
# tree, so every ref cost three identical calls — that is what exhausted a
# 5000/hour budget mid-scan. Second, each call ended in `2>/dev/null` and fed
# jq directly, so a rate-limit 403 or a timeout produced an empty result that
# was indistinguishable from "no indicators found". A scheduled run would
# print a clean bill of health having read nothing at all. Never again: a read
# that fails is a finding, not a pass.
fetch_tree() { # owner/repo ref -> tree json on stdout, nonzero if unreadable
  local j i
  for i in 1 2 3; do
    j=$(gh api "repos/$1/git/trees/$2?recursive=1" 2>/dev/null)
    if [ -n "$j" ] && [ "$(printf '%s' "$j" | jq -r 'if (.tree|type)=="array" then "ok" else "no" end' 2>/dev/null)" = "ok" ]; then
      printf '%s' "$j"; return 0
    fi
    sleep $((i * 3))
  done
  return 1
}

# Read a blob by its sha, and treat a failed read as a finding.
#
# This used the contents API by path, which refuses any blob over 1MB, and then
# did `[ -z "$body" ] && continue`. Between them, a config the API would not
# serve was skipped in silence and the ref still printed clean. The tree
# already carries the sha and the size, so reading the blob costs nothing extra
# and works up to 100MB.
read_blob() { # owner/repo blob-sha -> decoded bytes on stdout, nonzero if unreadable
  local j i
  for i in 1 2 3; do
    j=$(gh api "repos/$1/git/blobs/$2" 2>/dev/null)
    if [ "$(printf '%s' "$j" | jq -r 'if .content!=null then "ok" else "no" end' 2>/dev/null)" = "ok" ]; then
      printf '%s' "$j" | jq -r '.content' | base64 -d 2>/dev/null
      return 0
    fi
    sleep $((i * 3))
  done
  return 1
}

# Tree-level: reads the already-fetched tree, no network.
tree_indicators() { # tree-json -> prints findings, empty if clean
  printf '%s' "$1" | jq -r '
    [.tree[]? | select(.type=="blob")] as $t
    | [ ($t[] | select(.path|test("\\.vscode/tasks\\.json$"))       | "vscode-task  \(.path)"),
        ($t[] | select(.path|test("temp_auto_push|temp_interactive_push|branch_structure|truffleSecrets"))
                                                                     | "worm-artifact \(.path)"),
        # No size heuristic here. It was scoped to postcss/tailwind on the
        # theory that clean ones are 69-200 bytes, but Greenbaq/green-app has
        # a legitimate 3061-byte tailwind config — 125 lines, longest line 78
        # chars, no padding — and it fired on that. The check was redundant
        # anyway: content_indicators reads every *.config.{js,cjs,mjs,ts,mts}
        # and tests it for padding and long lines directly, which is what
        # actually distinguishes a payload from a big palette.
      ] | .[]' 2>/dev/null
}

# Content-level: only for the handful of paths worth reading. Padding uses a
# whitespace CLASS, so tab padding is caught; the live samples used 273 tabs
# and every space-only pattern in circulation missed them entirely.
content_indicators() { # owner/repo ref tree-json
  local csha csize cpath body
  while IFS=$'\t' read -r csha csize cpath; do
      [ -z "$cpath" ] && continue
      if ! body=$(read_blob "$1" "$csha"); then
        echo "api-error    $cpath — blob unreadable after 3 tries, this file was NOT checked"
        continue
      fi
      # An empty decode is only trustworthy when the blob is genuinely empty.
      if [ -z "$body" ] && [ "$csize" != "0" ]; then
        echo "api-error    $cpath — decoded empty but size is ${csize}B, this file was NOT checked"
        continue
      fi
      [ -z "$body" ] && continue
      printf '%s' "$body" | grep -qE '[[:space:]]{50,}[^[:space:]]' \
        && echo "padding      $cpath — code hidden after 50+ whitespace chars"
      printf '%s' "$body" | awk 'length($0)>2000{exit 1}' \
        || echo "long-line    $cpath — single line over 2000 chars"
      printf '%s' "$body" | grep -qE 'createRequire\(import\.meta\.url\)' \
        && case "$cpath" in *.mjs|*.mts) echo "createRequire $cpath — CJS shim prepended to an ESM config" ;; esac
      printf '%s' "$body" | grep -qE 'branch_structure\.json|temp_auto_push\.bat|temp_interactive_push\.bat' \
        && echo "worm-ignore  $cpath — hides the worm's own push scripts"
      case "$cpath" in
        *.vscode/settings.json)
          printf '%s' "$body" | grep -qE '"task\.allowAutomaticTasks"[[:space:]]*:[[:space:]]*true' \
            && echo "auto-task    $cpath — allowAutomaticTasks:true enables the folderOpen dropper" ;;
      esac
  done < <(printf '%s' "$3" \
    | jq -r '.tree[]? | select(.type=="blob")
            | select(.path|test("\\.config\\.(js|cjs|mjs|ts|mts)$|\\.gitignore$|\\.vscode/settings\\.json$"))
            | "\(.sha)\t\(.size)\t\(.path)"' 2>/dev/null)
}

# Font Awesome legitimately ships fa-solid-900.woff2, so matching the name
# alone fires on every healthy repo that uses the library — it did, on
# TalentQL/website, and cost a round of triage. The live payloads were named
# fa-solid-400.woff2 and fa-solid-500.woff2 in different batches, so the name
# is not the signal in either direction. Read the first four bytes instead.
# The payload began 09090909, four tab characters, which no font format uses.
#
# Scoped to the Font Awesome naming space, not every font in the tree. A repo
# can hold hundreds of fonts and this runs every 4 hours; verifying them all
# would cost hundreds of blob fetches per pass to re-prove the same thing.
font_indicators() { # owner/repo ref tree-json
  printf '%s' "$3" \
  | jq -r '.tree[]? | select(.type=="blob")
          | select(.path|test("fa-[a-z]+-[0-9]+\\.(woff2?|ttf|otf)$"))
          | "\(.sha) \(.size) \(.path)"' 2>/dev/null \
  | while read -r bsha bsize bpath; do
      magic=$(read_blob "$1" "$bsha" | head -c4 | od -An -tx1 | tr -d ' \n')
      case "$magic" in
        774f4632|774f4646|00010000|4f54544f|74727565|74746366) : ;;
        "") echo "font-unread  $bpath — blob unreadable, check this one by hand" ;;
        *)  echo "fake-font    $bpath (${bsize}B, magic=$magic) — not a font, this is the payload" ;;
      esac
    done
}

# A rewritten tip keeps the author date and loses the committer identity: the
# name shortens to the GitHub profile display name and the offset becomes the
# server's. Same email, different name, different offset.
tip_fingerprint() { # owner/repo ref
  gh api "repos/$1/commits/$2" --jq '
    .commit as $c
    | if $c.author.name != $c.committer.name and $c.author.email == $c.committer.email
      then "ghost-commit \(.sha[0:9]) author=\($c.author.name) committer=\($c.committer.name) (same email, different name)"
      else empty end' 2>/dev/null
}

# ------------------------------------------------------------------- per repo ---
# Every loop that calls note() must run in THIS shell, so process substitution
# rather than a pipe. A pipeline puts the loop in a subshell, findings++ is
# discarded, and the script exits 0 with findings on screen — which silently
# breaks the whole point of a scheduled run.
scan_ref() { # owner/repo ref
  local out l tj
  if ! tj=$(fetch_tree "$1" "$2"); then
    note "$1 [$2] api-error    tree unreadable after 3 tries — this ref was NOT scanned"
    warn "  a failed read is not a clean result. Check: gh api rate_limit --jq .resources.core"
    return
  fi
  if [ "$(printf '%s' "$tj" | jq -r '.truncated // false' 2>/dev/null)" = "true" ]; then
    note "$1 [$2] truncated    tree too large to list fully — this scan is PARTIAL"
  fi
  out=$(tree_indicators "$tj")
  if [ -n "$out" ]; then
    while IFS= read -r l; do note "$1 [$2] $l"; done < <(printf '%s\n' "$out")
  fi
  out=$(content_indicators "$1" "$2" "$tj")
  if [ -n "$out" ]; then
    while IFS= read -r l; do note "$1 [$2] $l"; done < <(printf '%s\n' "$out")
  fi
  out=$(font_indicators "$1" "$2" "$tj")
  if [ -n "$out" ]; then
    while IFS= read -r l; do note "$1 [$2] $l"; done < <(printf '%s\n' "$out")
  fi
}

ACCOUNTS_SCANNED=0
for acct in "${ACCOUNTS[@]}"; do
  export GH_CONFIG_DIR="$HOME/.config/gh-$acct"

  # `gh api user` failing used to be reported as "not authenticated" and
  # skipped. That is a misdiagnosis when the real cause is a 403 rate limit,
  # and it mattered: the account was skipped, nothing was read, and the run
  # still printed "no indicators" and exited 0. Read the error, name the
  # cause, and count it as a finding either way.
  # gh prints the error BODY to stdout, so a failed call still yields a
  # non-empty $login full of JSON. Testing for emptiness is not enough —
  # validate the shape. GitHub logins are 1-39 chars of alnum and hyphen.
  uerr=$(gh api user --jq '.login' 2>&1 >/dev/null)
  login=$(gh api user --jq '.login' 2>/dev/null | tr -d '\r' | head -1)
  case "$login" in
    *[!A-Za-z0-9-]*|"") login="" ;;
  esac
  if [ -z "$login" ]; then
    case "$uerr" in
      *"rate limit"*|*"403"*|*"secondary"*)
        note "account '$acct' is RATE LIMITED — not scanned, and not clean"
        warn "  check: gh api rate_limit --jq .resources.core ; re-run after reset" ;;
      *)
        note "account '$acct' unreadable: $(printf '%s' "$uerr" | head -1 | cut -c1-90)"
        warn "  if logged out: gh auth login. Either way this account was NOT scanned." ;;
    esac
    continue
  fi

  # Budget floor for THIS account. The old check ran once, before the loop,
  # against whichever account GH_CONFIG_DIR happened to point at — so a
  # healthy work token masked an exhausted personal token.
  rl=$(gh api rate_limit 2>/dev/null | jq -r '.resources.core.remaining // empty' 2>/dev/null)
  if [ -n "$rl" ] && [ "$rl" -lt 200 ]; then
    rs=$(gh api rate_limit 2>/dev/null | jq -r '.resources.core.reset // 0' 2>/dev/null)
    note "account '$acct' ($login) has only $rl API calls left — not scanned, and not clean"
    warn "  budget resets at $(date -r "$rs" -u +%H:%M:%SZ 2>/dev/null || echo "$rs"); re-run after that"
    continue
  fi

  ACCOUNTS_SCANNED=$((ACCOUNTS_SCANNED+1))
  STATE="$STATE_DIR/watch-$acct.tsv"
  touch "$STATE"

  hdr "account: $acct ($login)"

  # Everything this token can push to, including repos owned by orgs the user
  # is only an outside collaborator on. That is how the affected org was
  # reachable at all — `gh repo list <owner>` would never have listed it.
  if [ -n "$ONLY_REPO" ]; then
    # Not every account can see every repo. Skip quietly so --repo works
    # without the caller having to know which account owns the grant.
    gh api "repos/$ONLY_REPO" --jq '.permissions.push' 2>/dev/null | grep -q true || {
      warn "$ONLY_REPO not pushable by $login, skipping this account"; continue; }
    repos="$ONLY_REPO"
    echo "  1 repo (--repo)"
  else
    repos=$(for pg in 1 2 3; do
              gh api "user/repos?affiliation=owner,collaborator,organization_member&per_page=100&page=$pg" \
                --jq '.[] | select(.permissions.push==true) | select(.archived==false) | .full_name' 2>/dev/null
            done | sort -u)
    # Zero pushable repos is a BLIND SPOT, not a clean result. An org that
    # restricts third-party OAuth apps caps the gh token at public read, so
    # permissions.push is false everywhere and this loop sees nothing. That is
    # how a scan reports success while checking zero files — it happened three
    # times during the incident this script came out of. Say it out loud.
    if [ -z "$repos" ]; then
      warn "$login can push to NOTHING this token can see — that is a blind spot, not a pass."
      warn "  Two causes look identical here, and they need different fixes:"
      warn "    1. the account owns nothing and belongs to no org — check"
      warn "       'gh api user --jq .public_repos' and 'gh api user/orgs'"
      warn "    2. an org restricts OAuth apps or enforces SAML — that returns"
      warn "       403 with an X-GitHub-SSO header, so check for it explicitly:"
      warn "       gh api -i orgs/ORG/repos | grep -i x-github-sso"
      warn "  A plain 200 with no SSO header and an empty repo list means (1)."
      warn "  Fix:   have an org owner approve the GitHub CLI app, or watch that org"
      warn "         through its own audit log and branch protection instead."
      continue
    fi
    echo "  $(printf '%s\n' "$repos" | wc -l | tr -d ' ') pushable repos"
  fi

  # --ref scans one ref or raw sha and stops. No activity check, no state
  # written. This is how you verify a restore point BEFORE using it, and how
  # the indicator checks get tested against a known-bad commit.
  if [ -n "$ONLY_REF" ]; then
    for full in $repos; do
      echo "  scanning $full at $ONLY_REF"
      scan_ref "$full" "$ONLY_REF"
      fp=$(tip_fingerprint "$full" "$ONLY_REF")
      [ -n "$fp" ] && note "$full [$ONLY_REF] $fp"
    done
    continue
  fi

  for full in $repos; do
    seen=$(grep -F "$full	" "$STATE" 2>/dev/null | tail -1 | cut -f2)
    [ -n "$SINCE_OVERRIDE" ] && seen="$SINCE_OVERRIDE"

    events=$(gh api "repos/$full/activity?per_page=100" \
               --jq '.[] | "\(.timestamp)\t\(.activity_type)\t\(.ref)\t\(.actor.login)\t\(.before[0:9])\t\(.after[0:9])"' 2>/dev/null)
    newest=$(printf '%s\n' "$events" | head -1 | cut -f1)

    if [ "$RESET" = 1 ]; then
      [ -n "$newest" ] && { grep -vF "$full	" "$STATE" > "$STATE.new" 2>/dev/null || : ; \
        printf '%s\t%s\n' "$full" "$newest" >> "$STATE.new"; mv "$STATE.new" "$STATE"; }
      continue
    fi

    # First ever run for this repo: record the position, do not replay history.
    if [ -z "$seen" ]; then
      [ -n "$newest" ] && printf '%s\t%s\n' "$full" "$newest" >> "$STATE"
      continue
    fi

    fresh=$(printf '%s\n' "$events" | awk -F'\t' -v s="$seen" '$1 > s')
    [ -z "$fresh" ] && continue

    # A force push to any ref is the signal. It is how a rewrite lands, and it
    # is rare enough in normal work to be worth reading every time.
    rewrites=$(printf '%s\n' "$fresh" | awk -F'\t' '$2=="force_push"')
    if [ -n "$rewrites" ]; then
      while IFS=$'\t' read -r ts kind ref actor before after; do
        note "$full  FORCE PUSH  ${ref#refs/heads/}  $before -> $after  by $actor  at $ts"
      done < <(printf '%s\n' "$rewrites")
    fi

    others=$(printf '%s\n' "$fresh" | awk -F'\t' '$2!="force_push"' | cut -f4 | sort -u | grep -v "^$login$")
    if [ -n "$others" ]; then
      while IFS= read -r a; do warn "$full  pushes by another actor: $a"; done < <(printf '%s\n' "$others")
    fi

    # Scan every ref the fresh activity actually touched, plus the default
    # branch. Scanning only the default branch was a real hole. On
    # TalentQL/website the payload landed on dev, feature-update,
    # feature-updates and old-website while main stayed clean, so a
    # default-branch-only pass had nothing to find and said so. Two of those
    # four also arrived by plain fast-forward push, not force push, because a
    # stale feature branch is behind and does not need a rewrite — so reading
    # only force_push events would have hidden half of it as well.
    if [ "$DEEP" = 1 ]; then
      refs=$(gh api "repos/$full/branches?per_page=100" --jq '.[].name' 2>/dev/null | head -"$MAX_BRANCHES")
    else
      # Deletions carry after=000000000 and there is nothing left to read.
      moved=$(printf '%s\n' "$fresh" \
              | awk -F'\t' '$2!="branch_deletion" && $6!="000000000" {print $3}' \
              | grep '^refs/heads/' | sed 's|^refs/heads/||' | sort -u)
      refs=$(printf '%s\n%s\n' "$moved" "$(gh api "repos/$full" --jq '.default_branch' 2>/dev/null)" \
             | grep -v '^$' | sort -u | head -"$MAX_BRANCHES")
    fi
    for r in $refs; do
      scan_ref "$full" "$r"
      fp=$(tip_fingerprint "$full" "$r")
      [ -n "$fp" ] && note "$full [$r] $fp"
    done

    grep -vF "$full	" "$STATE" > "$STATE.new" 2>/dev/null || :
    printf '%s\t%s\n' "$full" "$newest" >> "$STATE.new"
    mv "$STATE.new" "$STATE"
  done
done

# ----------------------------------------------------------------- verdict ---
echo
if [ "$RESET" = 1 ]; then
  grn "state reset — current positions recorded, nothing reported"
  exit 0
fi
# Zero accounts scanned is not a pass. Every false-clean in this incident
# traced back to a verdict printed over an empty check.
if [ "$ACCOUNTS_SCANNED" -eq 0 ]; then
  red "NO account was scanned — that is 'unknown', not 'clean'."
  exit 2
fi
if [ "$findings" -eq 0 ]; then
  grn "no new force pushes and no indicators ($ACCOUNTS_SCANNED account(s) actually scanned)"
  exit 0
fi
red "$findings indicator(s) found"
cat <<'EOF'

A force push you did not make means a credential can still write. In that
order:
  1. Revoke every token on the account that made it. Do that BEFORE restoring
     anything, or the restore gets rewritten again.
  2. Find the last commit whose author and committer names AND timestamps
     match. That is the restore point. Verify it is clean before using it —
     a "revert" to the attacker's own commit is a real failure mode.
  3. Restore, then re-run this. Then tell anyone who cloned or built it.
EOF
if [ "$QUIET" = 0 ] && command -v osascript >/dev/null; then
  osascript -e "display notification \"$findings indicator(s) on your GitHub remotes\" with title \"worm-guard\"" 2>/dev/null || :
fi
exit 1
