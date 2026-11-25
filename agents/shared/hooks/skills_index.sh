#!/usr/bin/env bash
# SessionStart hook for Claude Code and Codex: the names of every skill in the
# library and how to load one that is not on disk. The names come from this
# repository's agents/skills, the source of the library at mcp.julds.com.
set -euo pipefail
here=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)
skills=$(cd "$here/../../skills" && pwd -P)

all=$(for d in "$skills"/*/; do [ -f "$d/SKILL.md" ] && basename "$d"; done)
# Folders that git ignores (boat's own boat and synced) are not in the library.
ignored=$(git -C "$skills" check-ignore --stdin <<<"$all" 2>/dev/null || true)
names=$(grep -vxF -f <(printf '%s\n' "$ignored") <<<"$all" || true)
count=$(grep -c . <<<"$names" || true)

cat <<EOF
Skills: Somto's skill library is the Executor app \`skills\`. Skills in your local skill list load as usual.
Before you start a task, check the names below. If a name fits the task and the skill is not in your local list, load it first and follow it:
  Executor tool \`skills\` with {"app": "skills", "name": "<skill>"}
When a skill names another file of its folder, read that file with the same tool and "file": "<path>" in the input.
When a skill tells you to run a script or needs its files on the disk, run the shell command \`skill-fetch <skill>\`. It prints the folder that holds the whole skill. Use that folder for <skill-dir> and in place of a skill folder path that the skill names, such as ~/.agents/skills/<name>.
If no name fits but a skill can exist for the task, search by task words:
  Executor tool \`call\` with {"calls": {"path": "tools.skills.search_skills", "input": {"query": "<words>"}}}
A skill that the user names, or types as /<name>, is in this library when it is not in your local list.
Skills ($count): $(paste -sd, - <<<"$names" | sed 's/,/, /g')
EOF
