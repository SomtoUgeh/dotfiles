#!/usr/bin/env bash
# Shared trusted runtime selection. Source from an adjacent scanner only.
# Never discover executables from the repository's PATH or download a runtime.
worm_guard_runtime() {
  local candidate
  WORM_GUARD_UV=""
  WORM_GUARD_PYTHON=""
  for candidate in "${HOME:-/}/.local/bin/uv" /opt/homebrew/bin/uv /usr/local/bin/uv /usr/bin/uv /bin/uv; do
    if [ -x "$candidate" ]; then WORM_GUARD_UV=$candidate; break; fi
  done
  [ -n "$WORM_GUARD_UV" ] || { echo 'inspection incomplete: trusted uv executable not found' >&2; return 2; }
  for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3 /bin/python3; do
    [ -x "$candidate" ] || continue
    WORM_GUARD_PYTHON=$candidate
    if worm_guard_python -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; then
      return 0
    fi
  done
  WORM_GUARD_PYTHON=""
  echo 'inspection incomplete: installed Python 3.9 or newer is required in a trusted system location' >&2
  return 2
}

worm_guard_python() {
  env -i HOME="${HOME:-/}" PATH='/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin' \
    "$WORM_GUARD_UV" run --offline --no-project --no-config --no-env-file \
      --no-python-downloads --directory "$WORM_GUARD_SCRIPT_DIR" --python "$WORM_GUARD_PYTHON" \
      python -I -B "$@"
}
