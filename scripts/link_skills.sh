#!/usr/bin/env bash
# Keep each tool's skill folder to the skills that stay on disk: the p3-stack
# skills (agents/skills/<name> links into p3-stack) and the slash-only skills
# (front matter `disable-model-invocation: true`), because a tool runs
# /<name> only from a skill on disk. Every other skill loads through Executor,
# from the app `skills` that services/skills-mcp serves.
# Real folders and links to other places stay, such as aside-browser and
# boat's own boat and synced folders. Idempotent; install.sh and
# scripts/boat/link-agent-config.sh run it.
# Usage: link_skills.sh <agents-dir> <tool skill folder>...
set -euo pipefail
skills=$(cd "$1/skills" && pwd)
shift

slash_only() { # <skill dir>: true when its front matter has disable-model-invocation: true
  [ -f "$1/SKILL.md" ] && awk 'NR == 1 { if ($0 != "---") exit; next }
    /^---[[:space:]]*$/ { exit }
    /^disable-model-invocation:[[:space:]]*true[[:space:]]*$/ { found = 1 }
    END { exit !found }' "$1/SKILL.md"
}

on_disk=
for s in "$skills"/*; do
  if { [ -L "$s" ] && [[ $(readlink "$s") == */p3-stack/skills/* ]]; } || slash_only "$s"; then
    on_disk+=$(basename "$s")$'\n'
  fi
done
count=$(grep -c . <<<"$on_disk" || true)

for folder in "$@"; do
  # An earlier setup linked the whole folder to the shared skills.
  if [ -L "$folder" ]; then
    if [ "$(readlink "$folder")" != "$skills" ]; then
      echo "link_skills: $folder links to $(readlink "$folder"); left as it is" >&2
      continue
    fi
    rm "$folder"
  fi
  mkdir -p "$folder"
  for t in "$folder"/*; do
    [ -L "$t" ] || continue
    # A broken link goes, and so does a link to a shared skill that is not on disk.
    if [ ! -e "$t" ]; then
      rm "$t"
    elif [ "$(readlink "$t")" = "$skills/$(basename "$t")" ] && ! grep -qxF -- "$(basename "$t")" <<<"$on_disk"; then
      rm "$t"
    fi
  done
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    t=$folder/$name
    if [ -e "$t" ] && [ ! -L "$t" ]; then continue; fi
    ln -sfn "$skills/$name" "$t"
  done <<<"$on_disk"
  echo "link_skills: $folder has $count skills on disk; the others load through Executor"
done
