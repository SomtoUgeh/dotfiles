#!/usr/bin/env bash
# Standalone setup and scan. Keep main last so a truncated download cannot start setup.

fail() { printf 'INCOMPLETE: %s\n' "$*" >&2; exit 2; }

usage() {
  cat <<'USAGE'
Usage: scan.sh local [DIRECTORY] [--include-generated] [--details] [--workstation] [--check-signing]
       scan.sh repo OWNER/REPO [--ref BRANCH_TAG_OR_SHA]

Downloads verified scanner files and installs missing dependencies.
Automatic setup: macOS (Homebrew), Debian/Ubuntu (apt), Fedora (dnf).
Other Linux systems work when Git, Python 3.9+, uv, and (for remote scans)
gh, jq, file and iconv are already installed in standard locations.
GitHub scans use your normal gh login or GH_TOKEN/GITHUB_TOKEN.
Local scans exclude untracked build caches by default and report their paths.
Use --include-generated to read them too; --details shows more review locations.
Use --workstation for local process/startup checks outside DIRECTORY.
Use --check-signing to review missing commit signature headers (no verification).
Exit: 0 no findings in scope; 1 matches/review signals; 2 incomplete/setup failed.
USAGE
}

download() {
  curl -q --proto '=https' --proto-redir '=https' --tlsv1.2 \
    --fail --silent --show-error --location --retry 2 \
    --connect-timeout 20 --max-time 180 "$1" -o "$2" || fail "download failed: $1"
}

verify() {
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$1") || fail 'SHA-256 calculation failed'
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$1") || fail 'SHA-256 calculation failed'
  else
    fail 'install sha256sum or shasum before running setup'
  fi
  [ "${actual%% *}" = "$2" ] || fail "download checksum mismatch: ${1##*/}"
}

fetch_scanners() {
  local name digest
  # Update these digests whenever a shipped scanner/helper changes. Tests enforce this.
  while read -r digest name; do
    download "https://raw.githubusercontent.com/SomtoUgeh/dotfiles/main/scripts/$name" "$SCAN_WORK/$name"
    verify "$SCAN_WORK/$name" "$digest"
  done <<'SCANNERS'
cdbac2a4a73dbe1f652ade2fd91130f05ccbee7d56f4c9bfa2160fe2a92c9646 scan_repo.sh
2dbf6b05c4c30c50dd65a317e7feb551f0651708b047a36598404e15c880f84a scan_remote.sh
6cc409bd2bd3e2e796c0b2f0309cd8054e5b9ba86907dfc926cdce92a063f4fa worm_guard_patterns.py
775a287e026ba33378368ac75a8dba31dbb857134d201965a697049cf9ef6871 worm_guard_runtime.sh
2626a586be7d149bb28570209720cc2ea96e6f18c17a3d4e50731eef2107519d worm_guard_host.py
91e732fe086cfa7a2697d437884519e966e3fdf7770ff917abad5b36eda82576 worm_guard_local.py
SCANNERS
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@" || fail 'dependency installation failed'
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@" || fail 'dependency installation failed (sudo access is required)'
  else
    fail 'missing dependencies require sudo or an administrator to install them'
  fi
}

install_packages() {
  local os=$1
  shift
  [ "$#" -gt 0 ] || return 0
  printf 'Installing missing dependencies: %s\n' "$*"
  if [ "$os" = Darwin ]; then
    if ! command -v brew >/dev/null 2>&1; then
      printf '%s\n' 'Installing Homebrew and its command-line prerequisites.'
      download 'https://raw.githubusercontent.com/Homebrew/install/7a133dcc74051ee4efc79467ed215dfedf45aea2/install.sh' "$SCAN_WORK/brew-install.sh"
      verify "$SCAN_WORK/brew-install.sh" 12479a24be3f5307eecac7cde670fad7118640f031229e964f544b1367b52a41
      # Preserve Homebrew's own explanation and interactive confirmation on first install.
      [ -r /dev/tty ] && ( : </dev/tty ) 2>/dev/null || fail 'first Homebrew setup requires an interactive terminal'
      env -i HOME="$HOME" PATH="$PATH" USER="$(id -un)" TERM="${TERM:-dumb}" \
        /bin/bash "$SCAN_WORK/brew-install.sh" </dev/tty || fail 'Homebrew setup failed'
    fi
    HOMEBREW_NO_AUTO_UPDATE=1 brew install "$@" || fail 'Homebrew dependency installation failed'
  elif command -v apt-get >/dev/null 2>&1; then
    as_root apt-get update
    as_root apt-get install -y "$@"
  elif command -v dnf >/dev/null 2>&1; then
    as_root dnf install -y "$@"
  else
    fail "automatic setup requires apt or dnf; install these dependencies and retry: $*"
  fi
}

setup_dependencies() {
  local os=$1 mode=$2 candidate python_ok=0 uv_ok=0
  local packages=()
  # Do not run project-local executables or load a project's Python configuration.
  for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3 /bin/python3; do
    if [ -x "$candidate" ] && env -i PATH="$PATH" "$candidate" -I -B -c \
      'import sys; raise SystemExit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
      python_ok=1; break
    fi
  done
  if [ "$python_ok" = 0 ]; then
    if [ "$os" = Darwin ]; then packages+=(python); else packages+=(python3); fi
  fi
  git --version >/dev/null 2>&1 || packages+=(git)
  if [ "$mode" = repo ]; then
    command -v gh >/dev/null 2>&1 || packages+=(gh)
    command -v jq >/dev/null 2>&1 || packages+=(jq)
    command -v file >/dev/null 2>&1 || packages+=(file)
    if ! command -v iconv >/dev/null 2>&1; then
      if [ "$os" = Darwin ]; then
        packages+=(libiconv)
      elif command -v dnf >/dev/null 2>&1; then
        packages+=(glibc-common)
      else
        packages+=(libc-bin)
      fi
    fi
  fi
  for candidate in "$HOME/.local/bin/uv" /opt/homebrew/bin/uv /usr/local/bin/uv /usr/bin/uv /bin/uv; do
    if [ -x "$candidate" ]; then uv_ok=1; break; fi
  done
  if [ "$uv_ok" = 0 ] && [ "$os" = Darwin ]; then packages+=(uv); fi
  if [ "${#packages[@]}" -gt 0 ]; then install_packages "$os" "${packages[@]}"; fi
  if [ "$uv_ok" = 0 ] && [ "$os" = Linux ]; then
    printf '%s\n' 'Installing uv in ~/.local/bin (shell profiles are not changed).'
    download 'https://astral.sh/uv/0.12.7/install.sh' "$SCAN_WORK/uv-install.sh"
    verify "$SCAN_WORK/uv-install.sh" 92e8554321e2bde08c9b1445dae47a65360f885274f31df51cdc2f9faa84e001
    env -i HOME="$HOME" PATH="$PATH" UV_UNMANAGED_INSTALL="$HOME/.local/bin" \
      /bin/sh "$SCAN_WORK/uv-install.sh" || fail 'uv installation failed'
  fi
  # Reject an old/unusable runtime even when a package manager reported success.
  WORM_GUARD_SCRIPT_DIR=$SCAN_WORK
  . "$SCAN_WORK/worm_guard_runtime.sh" || fail 'runtime helper could not load'
  worm_guard_runtime || fail 'Python/uv setup did not produce a usable runtime'
}

github_login() {
  # Probe the selected credential: aggregate auth status can fail for an inactive account.
  GH_HOST=github.com gh api rate_limit >/dev/null 2>&1 && return 0
  if [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
    fail 'the supplied GitHub token could not authenticate; check it and retry'
  fi
  [ -r /dev/tty ] && ( : </dev/tty ) 2>/dev/null || \
    fail 'GitHub login required: run gh auth login, or provide GH_TOKEN, then retry'
  printf '%s\n' 'Sign in to GitHub to read the requested repository.'
  gh auth login --hostname github.com --web --git-protocol https </dev/tty || fail 'GitHub login failed'
}

main() {
  set -u
  set -o pipefail
  local mode=${1:---help} target ref='' os rc
  local local_args=()
  case "$mode" in
    --help|-h) usage; return 0 ;;
    local)
      shift
      target=.
      if [ "$#" -gt 0 ] && [[ "$1" != --* ]]; then target=$1; shift; fi
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --include-generated|--details|--workstation|--check-signing) local_args+=("$1") ;;
          *) fail 'usage: scan.sh local [DIRECTORY] [--include-generated] [--details] [--workstation] [--check-signing]' ;;
        esac
        shift
      done
      [ -d "$target" ] || fail 'local target is not a directory'
      target=$(CDPATH= cd -- "$target" && pwd -P) || fail 'cannot resolve local target'
      ;;
    repo)
      [ "$#" -eq 2 ] || [ "$#" -eq 4 ] || fail 'usage: scan.sh repo OWNER/REPO [--ref REF]'
      target=$2
      [[ "$target" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail 'repository must be OWNER/REPO'
      if [ "$#" -eq 4 ]; then
        [ "$3" = --ref ] && [ -n "$4" ] || fail 'expected --ref with a nonempty branch, tag or SHA'
        ref=$4
      fi
      ;;
    *) usage >&2; fail 'choose local or repo' ;;
  esac
  export PATH='/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'
  [ -n "${HOME:-}" ] && [ -d "$HOME" ] || fail 'HOME must name an existing directory'
  os=$(uname -s) || fail 'cannot identify operating system'
  case "$os" in Darwin|Linux) ;; *) fail 'supported operating systems are macOS and Linux' ;; esac
  umask 077
  SCAN_WORK=$(mktemp -d /tmp/worm-scan.XXXXXXXX) || fail 'cannot create temporary directory'
  trap 'rm -rf -- "$SCAN_WORK"' EXIT
  trap 'exit 2' HUP INT TERM
  # Resolve the target first, then keep every setup/API command outside that repository.
  cd -- "$SCAN_WORK" || fail 'cannot enter temporary directory'
  printf 'Preparing scanner...\n' >&2
  fetch_scanners
  setup_dependencies "$os" "$mode"
  if [ "$mode" = local ]; then
    /bin/bash "$SCAN_WORK/scan_repo.sh" "$target" ${local_args[@]+"${local_args[@]}"}
    rc=$?
  else
    github_login
    local args=(--account default --repo "$target")
    [ -z "$ref" ] || args+=(--ref "$ref")
    /bin/bash "$SCAN_WORK/scan_remote.sh" "${args[@]}"
    rc=$?
  fi
  case "$rc" in 0|1|2) return "$rc" ;; *) fail "scanner stopped unexpectedly (exit $rc)" ;; esac
}

main "$@"
