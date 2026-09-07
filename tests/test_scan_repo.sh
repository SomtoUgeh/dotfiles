#!/usr/bin/env bash

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../scripts" && pwd -P) || exit 2
SCANNER="$SCRIPT_DIR/scan_repo.sh"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/test-scan-repo.XXXXXX") || exit 2
failures=0
tests=0

cleanup() {
  chmod -R u+rwX "$TEST_ROOT" 2>/dev/null || true
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# Fixture setup never inherits user Git configuration or invokes target helpers.
fixture_git() {
  local root="$1"
  shift
  env -i HOME="$TEST_ROOT" PATH='/usr/bin:/bin' TZ=UTC \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    GIT_TERMINAL_PROMPT=0 GIT_ALLOW_PROTOCOL=file \
    GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.test \
    GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.test \
    GIT_AUTHOR_DATE='2000-01-01T00:00:00+0000' GIT_COMMITTER_DATE='2000-01-01T00:00:00+0000' \
    git -c init.templateDir= -c init.defaultBranch=main -c core.hooksPath=/dev/null \
      -c core.fsmonitor=false -c commit.gpgSign=false -c tag.gpgSign=false \
      -C "$root" "$@" || exit 2
}

fixture_empty_repo() {
  fixture_git "$1" init -q
}

fixture_committed_repo() {
  local root="$1"
  fixture_empty_repo "$root"
  printf 'ordinary committed text\n' > "$root/README.txt"
  fixture_git "$root" add README.txt
  fixture_git "$root" commit -qm 'clean fixture'
}

run_case() {
  local name="$1" expected="$2" fixture output rc
  fixture="$TEST_ROOT/$name"
  output="$TEST_ROOT/$name.out"
  shift 2
  mkdir -p "$fixture" || exit 2
  "$@" "$fixture" || exit 2
  /bin/bash "$SCANNER" "$fixture" --details > "$output" 2>&1
  rc=$?
  tests=$((tests + 1))
  if [ "$rc" -ne "$expected" ]; then
    fail "$name exited $rc, expected $expected"
    sed -n '1,240p' "$output" >&2
  fi
}

run_relative_case() {
  local fixture="$TEST_ROOT/relative-path" output="$TEST_ROOT/relative-path.out" rc
  mkdir -p "$fixture"
  fixture_untracked_extensionless "$fixture"
  (
    cd "$TEST_ROOT" || exit 2
    /bin/bash "$SCANNER" relative-path
  ) > "$output" 2>&1
  rc=$?
  tests=$((tests + 1))
  if [ "$rc" -ne 1 ]; then
    fail "relative-path exited $rc, expected 1"
    sed -n '1,240p' "$output" >&2
  fi
}

run_quick_case() {
  local started=$SECONDS name="$1"
  run_case "$@"
  [ "$((SECONDS - started))" -lt 10 ] \
    || fail "$name took at least 10 seconds to reject a FIFO"
}

fixture_clean() {
  local root="$1" odd
  mkdir -p "$root/fonts"
  printf 'import { createRequire } from "node:module";\nconst require = createRequire(import.meta.url);\n' > "$root/tool.mjs"
  printf 'wOF2rest' > "$root/fonts/arbitrary-name.woff2"
  printf 'wOFFrest' > "$root/fonts/another-name.woff"
  printf '\000\001\000\000rest' > "$root/fonts/typeface.ttf"
  printf 'OTTOrest' > "$root/fonts/typeface.otf"
  printf '%034sLPrest' '' > "$root/fonts/typeface.eot"
  odd="$root/ordinary
name:with spaces"
  printf 'plain extensionless text\n' > "$odd"
}

fixture_tracked_extensionless() {
  local root="$1"
  fixture_empty_repo "$root"
  mkdir -p "$root/node_modules"
  printf 'global.%s = "A8-%s-1";\n' 'i' '3997' > "$root/node_modules/runner"
  fixture_git "$root" add -f node_modules/runner
}

fixture_untracked_extensionless() {
  local root="$1"
  printf 'global.%s = "A8-%s-1";\n' 'i' '5657' > "$root/runner"
}

fixture_marker_bypass() {
  local root="$1"
  printf '# worm-guard:%s-signatures\nglobal.%s = "A8-%s-1";\n' 'allow' 'i' '3997' > "$root/payload.js"
}

fixture_bad_fonts() {
  local root="$1" extension
  mkdir -p "$root/assets"
  for extension in woff2 woff ttf otf eot; do
    printf 'const source = true;\n' > "$root/assets/tiny-source-renamed.$extension"
  done
}

fixture_padding() {
  local root="$1"
  printf 'const value = 1;%60sSENSITIVE_PADDING_PAYLOAD\n' '' > "$root/extensionless"
}

fixture_font_command() {
  local root="$1"
  mkdir -p "$root/.vscode"
  printf '{"tasks":[{"command":"node ./assets/payload.ttf"}]}\n' > "$root/.vscode/tasks.json"
}

fixture_broken_read() {
  local root="$1"
  printf 'global.%s = "A8-%s-1";\n' 'i' '3997' > "$root/detected-first"
  ln -s "$root/does-not-exist" "$root/unreadable.js"
}

fixture_secret() {
  local root="$1"
  printf 'token=%s%s\nfetch("https://%s%s/x")\n' \
    'gho_' 'AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII' 'trongrid' '.io' > "$root/secrets.env"
}

fixture_odd_malicious_name() {
  local root="$1" odd
  odd="$root/odd
:name"
  printf 'global.%s = "A8-%s-1";\n' 'i' '3997' > "$odd"
}

fixture_no_target_execution() {
  local root="$1" sentinel hook tree commit
  sentinel="$root/was-executed"
  hook="$root/host-command"
  fixture_empty_repo "$root"
  printf '*.txt filter=fixture\n' > "$root/.gitattributes"
  printf 'ordinary text\n' > "$root/file.txt"
  fixture_git "$root" add .gitattributes file.txt
  tree=$(fixture_git "$root" write-tree)
  commit=$(printf 'tree %s\nauthor Fixture <fixture@example.test> 0 +0000\ncommitter Fixture <fixture@example.test> 0 +0000\ngpgsig -----BEGIN PGP SIGNATURE-----\n fake\n -----END PGP SIGNATURE-----\n\nfixture\n' "$tree" \
    | fixture_git "$root" hash-object -t commit -w --stdin)
  fixture_git "$root" update-ref refs/heads/main "$commit"
  printf '#!/bin/sh\nprintf executed > "%s"\n' "$sentinel" > "$hook"
  chmod +x "$hook"
  fixture_git "$root" config core.fsmonitor "$hook"
  fixture_git "$root" config filter.fixture.smudge "$hook"
  fixture_git "$root" config log.showSignature true
  fixture_git "$root" config gpg.program "$hook"
  fixture_git "$root" config core.sshCommand "$hook"
  fixture_git "$root" config core.pager "$hook"
  fixture_git "$root" config protocol.ext.allow always
  fixture_git "$root" config remote.origin.url "ext::$hook"
  fixture_git "$root" config fsck.missingEmail ignore
  fixture_git "$root" config fsck.skipList "$root/.git/missing-skip-list"
  mkdir -p "$root/.git/hooks"
  cp "$hook" "$root/.git/hooks/reference-transaction"
}

fixture_history_mismatch() {
  local root="$1" tree commit
  fixture_empty_repo "$root"
  tree=$(fixture_git "$root" mktree </dev/null)
  commit=$(printf 'tree %s\nauthor Fixture <fixture@example.test> 0 +0100\ncommitter Fixture <fixture@example.test> 0 +0000\n\nfixture\n' "$tree" \
    | fixture_git "$root" hash-object -t commit -w --stdin)
  fixture_git "$root" update-ref refs/heads/main "$commit"
}

fixture_packed_deleted_history() {
  local root="$1" object
  fixture_committed_repo "$root"
  fixture_untracked_extensionless "$root"
  fixture_git "$root" add runner
  fixture_git "$root" commit -qm 'historical inert signature'
  object=$(fixture_git "$root" rev-parse HEAD:runner)
  fixture_git "$root" rm -q runner
  fixture_git "$root" commit -qm 'remove signature from checkout'
  fixture_git "$root" gc --prune=now --quiet
  [ ! -e "$root/.git/objects/${object:0:2}/${object:2}" ] \
    || { fail 'historical fixture was not packed'; return 2; }
  fixture_git "$root" cat-file -e "$object"
}

fixture_unreachable_blob() {
  local root="$1"
  fixture_committed_repo "$root"
  printf 'global.%s = "A8-%s-1";\n' 'i' '3997' \
    | fixture_git "$root" hash-object -w --stdin >/dev/null
}

fixture_historical_filenames() {
  local root="$1"
  fixture_committed_repo "$root"
  mkdir -p "$root/removed/assets"
  printf 'ordinary text disguised as font\n' > "$root/removed/assets/old.woff2"
  printf '{"dependencies":{"tailwindcss-%s":"1.0.0"}}\n' 'style-animate' > "$root/removed/package.json"
  fixture_git "$root" add removed
  fixture_git "$root" commit -qm 'historical filenames'
  fixture_git "$root" rm -qr removed
  fixture_git "$root" commit -qm 'remove historical filenames'
  fixture_git "$root" gc --prune=now --quiet
}

fixture_nested_dependency() {
  local root="$1" nested="$1/node_modules/fixture-package"
  fixture_committed_repo "$root"
  mkdir -p "$nested"
  fixture_committed_repo "$nested"
  fixture_untracked_extensionless "$nested"
  fixture_git "$nested" add runner
  fixture_git "$nested" commit -qm 'tracked nested dependency signature'
}

fixture_nested_bare() {
  local root="$1" nested="$1/vendor/objects.git"
  mkdir -p "$nested"
  fixture_git "$nested" init --bare -q
  printf 'global.%s = "A8-%s-1";\n' 'i' '5657' \
    | fixture_git "$nested" hash-object -w --stdin >/dev/null
}

fixture_clean_bare() {
  fixture_git "$1" init --bare -q
}

fixture_hook_marker() {
  local root="$1"
  fixture_committed_repo "$root"
  mkdir -p "$root/.git/hooks"
  printf '#!/bin/sh\n# global.%s = "A8-%s-1";\n' 'i' '3997' > "$root/.git/hooks/pre-commit"
  chmod +x "$root/.git/hooks/pre-commit"
}

fixture_config_marker() {
  local root="$1"
  fixture_committed_repo "$root"
  printf '\n# global.%s = "A8-%s-1";\n' 'i' '3997' >> "$root/.git/config"
}

fixture_active_hook() {
  local root="$1"
  fixture_committed_repo "$root"
  mkdir -p "$root/.git/hooks"
  printf '#!/bin/sh\nexit 0\n' > "$root/.git/hooks/pre-commit"
  chmod +x "$root/.git/hooks/pre-commit"
}

fixture_command_config() {
  fixture_committed_repo "$1"
  fixture_git "$1" config core.fsmonitor 'printf harmless'
}

fixture_gitfile_shared_store() {
  local root="$1" source="$TEST_ROOT/shared-store-source"
  mkdir -p "$source"
  fixture_committed_repo "$source"
  fixture_unreachable_blob_in_store "$source"
  fixture_git "$source" worktree add -qb fixture-worktree "$root"
}

fixture_unreachable_blob_in_store() {
  printf 'global.%s = "A8-%s-1";\n' 'i' '3997' \
    | fixture_git "$1" hash-object -w --stdin >/dev/null
}

fixture_clean_worktree() {
  local root="$1" source="$TEST_ROOT/clean-worktree-source"
  mkdir -p "$source"
  fixture_committed_repo "$source"
  fixture_git "$source" worktree add -qb fixture-worktree "$root"
}

fixture_missing_object() {
  local root="$1" object
  fixture_committed_repo "$root"
  object=$(fixture_git "$root" rev-parse HEAD:README.txt)
  rm "$root/.git/objects/${object:0:2}/${object:2}"
}

fixture_corrupt_object() {
  local root="$1" object
  fixture_committed_repo "$root"
  object=$(fixture_git "$root" rev-parse HEAD:README.txt)
  chmod u+w "$root/.git/objects/${object:0:2}/${object:2}"
  printf 'not a compressed Git object\n' > "$root/.git/objects/${object:0:2}/${object:2}"
}

fixture_shallow() {
  local root="$1" source="$TEST_ROOT/shallow-source"
  mkdir -p "$source"
  fixture_committed_repo "$source"
  fixture_git "$source" commit --allow-empty -qm 'second commit'
  fixture_git "$TEST_ROOT" clone -q --no-local --depth=1 "$source" "$root"
  [ -s "$root/.git/shallow" ] || return 2
}

fixture_partial() {
  fixture_committed_repo "$1"
  fixture_git "$1" config remote.origin.promisor true
  fixture_git "$1" config remote.origin.partialclonefilter blob:none
}

fixture_include() {
  local root="$1"
  fixture_committed_repo "$root"
  fixture_git "$root" config include.path "$TEST_ROOT/not-present-include"
}

fixture_missing_promisor_no_execution() {
  local root="$1" hook="$1/host-command"
  fixture_committed_repo "$root"
  printf '#!/bin/sh\nprintf executed > "%s"\n' "$root/was-executed" > "$hook"
  chmod +x "$hook"
  fixture_git "$root" config protocol.ext.allow always
  fixture_git "$root" config remote.origin.url "ext::$hook"
  fixture_git "$root" config remote.origin.promisor true
  fixture_git "$root" config remote.origin.partialclonefilter blob:none
  # Resolve before declaring the object missing; scanner plumbing must not fetch it.
  local object
  object=$(fixture_git "$root" rev-parse HEAD:README.txt)
  rm "$root/.git/objects/${object:0:2}/${object:2}"
}

fixture_historical_secret() {
  local root="$1"
  fixture_committed_repo "$root"
  fixture_secret "$root"
  fixture_git "$root" add secrets.env
  fixture_git "$root" commit -qm 'historical redaction fixture'
  fixture_git "$root" rm -q secrets.env
  fixture_git "$root" commit -qm 'remove secrets from checkout'
  fixture_git "$root" gc --prune=now --quiet
}

fixture_staged_package() {
  local root="$1"
  fixture_committed_repo "$root"
  printf '{"dependencies":{"tailwindcss-%s":"1.0.0"}}\n' 'style-animate' > "$root/package.json"
  fixture_git "$root" add package.json
  printf '{"dependencies":{}}\n' > "$root/package.json"
}

fixture_staged_font() {
  local root="$1"
  fixture_committed_repo "$root"
  printf 'ordinary staged text disguised as a font\n' > "$root/staged.woff2"
  fixture_git "$root" add staged.woff2
  printf 'wOF2ordinary valid header\n' > "$root/staged.woff2"
}

fixture_initialized_submodule() {
  local root="$1" source="$TEST_ROOT/${1##*/}-source"
  mkdir -p "$source"
  fixture_committed_repo "$source"
  fixture_committed_repo "$root"
  fixture_git "$root" -c protocol.file.allow=always submodule add -q "$source" modules/child
  fixture_git "$root" commit -qm 'initialized submodule'
  [ -f "$root/modules/child/.git" ] || return 2
}

fixture_uninitialized_submodule() {
  fixture_initialized_submodule "$1"
  fixture_git "$1" submodule deinit -q --force --all
  [ ! -e "$1/modules/child/.git" ] || return 2
}

fixture_main_worktree_hooks() {
  local root="$1" source="$TEST_ROOT/main-worktree-source" hooks="$TEST_ROOT/external-main-hooks"
  mkdir -p "$source" "$hooks"
  fixture_committed_repo "$source"
  fixture_git "$source" config extensions.worktreeConfig true
  fixture_git "$source" worktree add -qb fixture-worktree "$root"
  fixture_git "$source" config --worktree core.hooksPath "$hooks"
  printf '#!/bin/sh\n# global.%s = "A8-%s-1";\n' 'i' '3997' > "$hooks/pre-commit"
  chmod +x "$hooks/pre-commit"
  [ -f "$source/.git/config.worktree" ] || return 2
}

fixture_object_fifo() {
  local root="$1"
  fixture_committed_repo "$root"
  mkdir -p "$root/.git/objects/aa"
  mkfifo "$root/.git/objects/aa/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
}

fixture_refs_fifo() {
  local root="$1"
  fixture_committed_repo "$root"
  mkfifo "$root/.git/refs/heads/fifo-ref"
}

fixture_relative_alternate() {
  local root="$1" source="$TEST_ROOT/relative-alternate-source"
  mkdir -p "$source"
  fixture_committed_repo "$source"
  fixture_unreachable_blob_in_store "$source"
  fixture_committed_repo "$root"
  mkdir -p "$root/.git/objects/info"
  printf '../../../relative-alternate-source/.git/objects\n' > "$root/.git/objects/info/alternates"
}

fixture_quoted_alternate() {
  local root="$1" source
  source="$TEST_ROOT/quoted	alternate-source"
  mkdir -p "$source"
  fixture_committed_repo "$source"
  fixture_unreachable_blob_in_store "$source"
  fixture_committed_repo "$root"
  mkdir -p "$root/.git/objects/info"
  printf '"%s/quoted\\talternate-source/.git/objects"\n' "$TEST_ROOT" > "$root/.git/objects/info/alternates"
}

fixture_missing_alternate() {
  fixture_committed_repo "$1"
  mkdir -p "$1/.git/objects/info"
  printf '%s/missing-object-store\n' "$TEST_ROOT" > "$1/.git/objects/info/alternates"
}

fixture_alternates_fifo() {
  fixture_committed_repo "$1"
  mkdir -p "$1/.git/objects/info"
  mkfifo "$1/.git/objects/info/alternates"
}

fixture_alternates_symlink() {
  local root="$1" target="$TEST_ROOT/symlink-alternates-input"
  fixture_committed_repo "$root"
  mkdir -p "$root/.git/objects/info"
  : > "$target"
  ln -s "$target" "$root/.git/objects/info/alternates"
}

fixture_sha256() {
  fixture_git "$1" init -q --object-format=sha256
  fixture_committed_repo "$1"
}

fixture_sha256_packed_font() {
  fixture_git "$1" init -q --object-format=sha256
  fixture_historical_filenames "$1"
}

fixture_split_index() {
  fixture_committed_repo "$1"
  fixture_git "$1" update-index --split-index
  [ -n "$(fixture_git "$1" rev-parse --shared-index-path)" ] || return 2
}

run_case clean 0 fixture_clean
run_case tracked-extensionless 1 fixture_tracked_extensionless
run_case untracked-extensionless 1 fixture_untracked_extensionless
run_case marker-bypass 1 fixture_marker_bypass
run_case bad-fonts 1 fixture_bad_fonts
run_case padding 1 fixture_padding
run_case font-command 1 fixture_font_command
run_case broken-read 2 fixture_broken_read
run_case redacted-secret 1 fixture_secret
run_case odd-malicious-name 1 fixture_odd_malicious_name
run_case no-target-execution 1 fixture_no_target_execution
run_case history-mismatch 1 fixture_history_mismatch
run_case empty-repo 0 fixture_empty_repo
run_case committed-repo 0 fixture_committed_repo
run_case clean-bare 0 fixture_clean_bare
run_case clean-worktree 0 fixture_clean_worktree
run_case packed-deleted-history 1 fixture_packed_deleted_history
run_case unreachable-blob 1 fixture_unreachable_blob
run_case historical-filenames 1 fixture_historical_filenames
run_case nested-dependency 1 fixture_nested_dependency
run_case nested-bare 1 fixture_nested_bare
run_case hook-marker 1 fixture_hook_marker
run_case config-marker 1 fixture_config_marker
run_case active-hook 1 fixture_active_hook
run_case command-config 1 fixture_command_config
run_case gitfile-shared-store 1 fixture_gitfile_shared_store
run_case missing-object 2 fixture_missing_object
run_case corrupt-object 2 fixture_corrupt_object
run_case shallow 2 fixture_shallow
run_case partial 2 fixture_partial
run_case include 2 fixture_include
run_case missing-promisor-no-execution 2 fixture_missing_promisor_no_execution
run_case historical-secret 1 fixture_historical_secret
run_case staged-package 1 fixture_staged_package
run_case staged-font 1 fixture_staged_font
run_case initialized-submodule 0 fixture_initialized_submodule
run_case uninitialized-submodule 2 fixture_uninitialized_submodule
run_case main-worktree-hooks 1 fixture_main_worktree_hooks
run_quick_case object-fifo 2 fixture_object_fifo
run_quick_case refs-fifo 2 fixture_refs_fifo
run_case relative-alternate 1 fixture_relative_alternate
run_case quoted-alternate 1 fixture_quoted_alternate
run_case missing-alternate 2 fixture_missing_alternate
run_quick_case alternates-fifo 2 fixture_alternates_fifo
run_case alternates-symlink 2 fixture_alternates_symlink
run_case split-index 0 fixture_split_index
mkdir -p "$TEST_ROOT/sha256-probe"
if (fixture_git "$TEST_ROOT/sha256-probe" init -q --object-format=sha256) >/dev/null 2>&1; then
  run_case sha256 0 fixture_sha256
  run_case sha256-packed-font 1 fixture_sha256_packed_font
  grep -q 'content does not match the font extension' "$TEST_ROOT/sha256-packed-font.out" \
    || fail 'SHA-256 packed historical font filename was missed'
else
  printf 'SKIP: installed Git does not support SHA-256 repositories\n'
fi
run_relative_case

grep -q 'createRequire in ESM is legitimate' "$TEST_ROOT/clean.out" \
  || fail 'benign createRequire was not classified as advisory-only'
grep -q 'known bootstrap signature' "$TEST_ROOT/tracked-extensionless.out" \
  || fail 'tracked extensionless file under an excluded untracked directory was missed'
grep -q 'known bootstrap signature' "$TEST_ROOT/untracked-extensionless.out" \
  || fail 'untracked extensionless file was missed'
grep -q 'known bootstrap signature' "$TEST_ROOT/marker-bypass.out" \
  || fail 'in-file allow marker bypassed scanning'
for extension in woff2 woff ttf otf eot; do
  grep -q "tiny-source-renamed.$extension" "$TEST_ROOT/bad-fonts.out" \
    || fail "invalid .$extension file was missed"
done
grep -q 'node command text and a font extension occur on the same line' "$TEST_ROOT/font-command.out" \
  || fail 'task executing a non-WOFF font was missed'
grep -q '50 or more whitespace characters before content' "$TEST_ROOT/padding.out" \
  || fail 'known whitespace-padding shape was missed'
grep -q 'SENSITIVE_PADDING_PAYLOAD' "$TEST_ROOT/padding.out" \
  && fail 'padding finding leaked matched source'
grep -q 'Inspection incomplete' "$TEST_ROOT/broken-read.out" \
  || fail 'read failure did not produce an incomplete result'
grep -q 'Campaign matches: [1-9]' "$TEST_ROOT/broken-read.out" \
  || fail 'read failure did not retain the independently detected finding'
if grep -q 'AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII\|trongrid[.]io\|fetch(' "$TEST_ROOT/redacted-secret.out"; then
  fail 'scanner output leaked matched source or token material'
fi
grep -Fq '\n' "$TEST_ROOT/odd-malicious-name.out" \
  || fail 'odd filename was not escaped onto one output line'
for name in no-target-execution missing-promisor-no-execution; do
  [ ! -e "$TEST_ROOT/$name/was-executed" ] \
    || fail "$name executed a target hook, helper, or external protocol command"
done
grep -q 'last 500 commits' "$TEST_ROOT/no-target-execution.out" \
  || fail 'limited commit metadata scope was not stated accurately'
grep -q 'all locally stored objects' "$TEST_ROOT/no-target-execution.out" \
  || fail 'complete local Git object scope was not stated accurately'
grep -q 'same-name author/committer offsets differ at commit' "$TEST_ROOT/history-mismatch.out" \
  || fail 'limited local-history timezone check was missed'
for name in packed-deleted-history unreachable-blob nested-dependency nested-bare hook-marker config-marker gitfile-shared-store main-worktree-hooks relative-alternate quoted-alternate; do
  grep -q 'known bootstrap signature' "$TEST_ROOT/$name.out" \
    || fail "$name omitted the inert bootstrap signature"
done
grep -q 'content does not match the font extension' "$TEST_ROOT/historical-filenames.out" \
  || fail 'historical tree filenames did not drive font validation'
grep -q 'known malicious package name' "$TEST_ROOT/historical-filenames.out" \
  || fail 'historical tree filenames did not drive package validation'
grep -q 'known malicious package name' "$TEST_ROOT/staged-package.out" \
  || fail 'staged package filename was missed after its working copy became clean'
grep -q 'content does not match the font extension' "$TEST_ROOT/staged-font.out" \
  || fail 'staged fake font was missed after its working copy became clean'
for name in missing-object corrupt-object shallow partial include missing-promisor-no-execution uninitialized-submodule object-fifo refs-fifo missing-alternate alternates-fifo alternates-symlink; do
  grep -q 'Inspection incomplete' "$TEST_ROOT/$name.out" \
    || fail "$name did not report its incomplete boundary"
done
if grep -q 'AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII\|trongrid[.]io\|fetch(' "$TEST_ROOT/historical-secret.out"; then
  fail 'historical object findings leaked matched source or token material'
fi
for verdict in clean tracked-extensionless broken-read; do
  grep -q '^Coverage: files=.* text=.* binary=.* fonts=.* skipped-dependency-dirs=.* skipped-git-metadata-dirs=.* trusted-scanner-files-omitted=' "$TEST_ROOT/$verdict.out" \
    || fail "$verdict verdict omitted scan coverage counts"
done
for name in committed-repo packed-deleted-history unreachable-blob gitfile-shared-store; do
  grep -Eq 'Git coverage:.*objects=[1-9][0-9]*.*blobs=[1-9][0-9]*' "$TEST_ROOT/$name.out" \
    || fail "$name omitted positive Git object and blob coverage counts"
done

/bin/bash "$SCANNER" --selftest > "$TEST_ROOT/selftest.out" 2>&1
selftest_rc=$?
tests=$((tests + 1))
if [ "$selftest_rc" -ne 0 ] || ! grep -q 'SELFTEST PASS' "$TEST_ROOT/selftest.out"; then
  fail "built-in selftest failed with exit $selftest_rc"
  sed -n '1,240p' "$TEST_ROOT/selftest.out" >&2
fi

# Installed entrypoints retain adjacent helpers; repository PATH cannot supply
# a Python/uv runtime. Exercise the supported user-local uv installation too.
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/.local/bin" "$TEST_ROOT/hostile"
ln -s "$SCANNER" "$TEST_ROOT/bin/scan-repo.sh"
(
  . "$SCRIPT_DIR/worm_guard_runtime.sh"
  WORM_GUARD_SCRIPT_DIR=$SCRIPT_DIR
  worm_guard_runtime || exit 2
  printf '#!/bin/sh\nprintf selected > "%s"\nexec "%s" "$@"\n' \
    "$TEST_ROOT/home-uv-selected" "$WORM_GUARD_UV" > "$TEST_ROOT/home/.local/bin/uv"
) || exit 2
printf '#!/bin/sh\nprintf unsafe > "%s"\nexit 90\n' "$TEST_ROOT/path-runtime-executed" > "$TEST_ROOT/hostile/uv"
cp "$TEST_ROOT/hostile/uv" "$TEST_ROOT/hostile/python3"
chmod +x "$TEST_ROOT/home/.local/bin/uv" "$TEST_ROOT/hostile/uv" "$TEST_ROOT/hostile/python3"
HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/hostile:$PATH" /bin/bash "$TEST_ROOT/bin/scan-repo.sh" "$TEST_ROOT/clean" > "$TEST_ROOT/symlink.out" 2>&1 \
  || fail 'installed scanner symlink or user-local uv failed'
[ -f "$TEST_ROOT/home-uv-selected" ] || fail 'user-local uv was not selected'
[ ! -e "$TEST_ROOT/path-runtime-executed" ] || fail 'repository PATH supplied a runtime'
tests=$((tests + 1))

# Both transports must retain their formerly unique signatures.
mkdir -p "$TEST_ROOT/union"
printf '"TMfKQEd7TJJa5xNZ%s"\n' 'JZ2Lep838vrzrs7mAP' > "$TEST_ROOT/union/wallet.txt"
printf '%s%s\n' '\u0068\u0074\u0074\u0070' '\u0063\u0068\u0069\u006c\u0064' > "$TEST_ROOT/union/escaped.txt"
printf '\000binary' > "$TEST_ROOT/union/temp_auto_push.sh"
rc=0
/bin/bash "$SCANNER" "$TEST_ROOT/union" > "$TEST_ROOT/union.out" 2>&1 || rc=$?
[ "$rc" = 1 ] || fail 'shared union fixture was not detected'
for reason in 'known campaign indicator' 'escaped http and child-process' 'known propagation artifact filename'; do
  grep -q "$reason" "$TEST_ROOT/union.out" || fail "shared detector lost $reason"
done
tests=$((tests + 1))

if [ "$failures" -ne 0 ]; then
  printf '%s failure(s) across %s scanner cases\n' "$failures" "$tests" >&2
  exit 1
fi

printf 'PASS: %s isolated scanner cases\n' "$tests"
