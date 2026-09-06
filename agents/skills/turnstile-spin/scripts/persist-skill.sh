#!/usr/bin/env bash
# Copy this locally maintained bundle into a confirmed project skill location.
set +x
set -euo pipefail

if [[ $# != 2 || "$1" != --path || -z "$2" || "$2" == --* ]]; then
  echo 'Usage: persist-skill.sh --path <bundle-directory>/SKILL.md' >&2
  exit 2
fi
command -v python3 >/dev/null || { echo 'persist-skill: python3 is required' >&2; exit 1; }

python3 -I - "${BASH_SOURCE[0]}" "$2" <<'PYTHON'
import json
import pathlib
import shutil
import sys
import tempfile

source = pathlib.Path(sys.argv[1]).resolve().parent.parent
requested = pathlib.Path(sys.argv[2])
project = pathlib.Path.cwd().resolve()
if requested.name != 'SKILL.md':
    print(json.dumps({'status': 'error', 'reason': 'file_target_not_supported'}))
    raise SystemExit(2)
target = requested.parent.resolve()
if target == project or not target.is_relative_to(project):
    print(json.dumps({'status': 'error', 'reason': 'target_outside_project'}))
    raise SystemExit(1)
if target == source or target.is_relative_to(source):
    print(json.dumps({'status': 'error', 'reason': 'target_inside_source'}))
    raise SystemExit(1)

try:
    if target.exists() and (not target.is_dir() or any(target.iterdir())):
        raise ValueError('target_not_empty')
    # Snapshot only this audited bundle. Never refresh from upstream implicitly.
    for member in source.rglob('*'):
        if member.is_symlink():
            raise ValueError('source_contains_symlink')
    if not (source / 'SKILL.md').is_file():
        raise ValueError('skill_missing')
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.turnstile-persist-', dir=target.parent) as staging:
        candidate = pathlib.Path(staging) / 'bundle'
        shutil.copytree(source, candidate, ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '.DS_Store'))
        for script in (candidate / 'scripts').glob('*.sh'):
            script.chmod(0o755)
        # Recheck after copying; never replace a directory populated meanwhile.
        if target.exists():
            target.rmdir()
        candidate.rename(target)
except (OSError, ValueError) as error:
    print(f'persist-skill: {error}', file=sys.stderr)
    print(json.dumps({'status': 'error', 'reason': 'copy_failed'}))
    raise SystemExit(1)
print(json.dumps({'status': 'ok', 'path': str(requested), 'bundle_root': str(target),
                  'scripts': sorted(p.name for p in (target / 'scripts').glob('*.sh'))}))
PYTHON
