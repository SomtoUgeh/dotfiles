#!/usr/bin/env bash
# sync-sessions-to-qmd.sh - Convert Claude Code sessions to full-content markdown for qmd indexing
#
# Unlike the toolkit summary version, this preserves the COMPLETE conversation:
#   - Full user messages (system-reminder tags stripped)
#   - Full assistant text blocks
#   - Full thinking blocks (as blockquotes)
#   - Tool uses: name + key input (file_path, command, pattern, query)
#
# Usage:
#   ./sync-sessions-to-qmd.sh           # Incremental (skip if md newer than jsonl)
#   ./sync-sessions-to-qmd.sh --full    # Rebuild all

set -euo pipefail

OUTPUT_DIR="$HOME/qmd-agent-sessions"
PROJECTS_DIR="$HOME/.claude/projects"

MODE="incremental"
[[ "${1:-}" == "--full" ]] && MODE="full"

mkdir -p "$OUTPUT_DIR"

# Cross-platform numeric mtime (GNU stat vs BSD stat)
get_mtime() {
  local file="$1" mtime="0"
  if mtime=$(stat -c %Y "$file" 2>/dev/null); then
    :
  elif mtime=$(stat -f %m "$file" 2>/dev/null); then
    :
  else
    mtime=0
  fi
  [[ "$mtime" =~ ^[0-9]+$ ]] || mtime=0
  printf '%s' "$mtime"
}

# Extract project name from path
get_project_name() {
  local path="$1"
  [[ -z "$path" || "$path" == "." ]] && { echo "unknown-project"; return; }
  basename -- "$path"
}

# Escape value for YAML frontmatter
yaml_escape() {
  local val="$1"
  case "$val" in
    *:*|*\#*|*\[*|*\]*|*\{*|*\}*|*,*|*\&*|*\**|*\!*|*\|*|*\'*|*\"*|*%*|*@*|-*|\>*)
      local escaped="$val"
      escaped=${escaped//\\/\\\\}
      escaped=${escaped//\"/\\\"}
      escaped=${escaped//$'\n'/\\n}
      escaped=${escaped//$'\r'/\\r}
      printf '"%s"' "$escaped"
      ;;
    *)
      printf '%s' "$val"
      ;;
  esac
}

# Convert a single JSONL session to full-content markdown
# Expects a JSON metadata object on stdin
convert_session() {
  local jsonl_file="$1"
  local session_id="$2"
  local meta="$3"

  local project_path first_prompt message_count created modified git_branch project_name
  project_path=$(echo "$meta" | jq -r '.projectPath // ""')
  first_prompt=$(echo "$meta" | jq -r '.firstPrompt // "Untitled session"')
  message_count=$(echo "$meta" | jq -r '.messageCount // 0')
  created=$(echo "$meta" | jq -r '.created // ""')
  modified=$(echo "$meta" | jq -r '.modified // ""')
  git_branch=$(echo "$meta" | jq -r '.gitBranch // "unknown"')

  [[ -z "$project_path" ]] && project_path="unknown"
  project_name=$(get_project_name "$project_path")

  local project_output_dir="$OUTPUT_DIR/$project_name"
  mkdir -p "$project_output_dir"
  local output_file="$project_output_dir/${session_id}.md"

  # Incremental: skip if markdown is newer than source
  if [[ "$MODE" == "incremental" && -f "$output_file" ]]; then
    local md_mtime jsonl_mtime
    md_mtime=$(get_mtime "$output_file")
    jsonl_mtime=$(get_mtime "$jsonl_file")
    if [[ "$md_mtime" -gt "$jsonl_mtime" ]]; then
      return 1  # skipped (not an error)
    fi
  fi

  # Write frontmatter
  local yaml_project_path yaml_project_name yaml_branch
  yaml_project_path=$(yaml_escape "$project_path")
  yaml_project_name=$(yaml_escape "$project_name")
  yaml_branch=$(yaml_escape "$git_branch")

  {
    cat <<EOF
---
session_id: $session_id
project_path: $yaml_project_path
project_name: $yaml_project_name
branch: $yaml_branch
created: $created
modified: $modified
messages: $message_count
---

# $first_prompt

**Project:** $project_name | **Branch:** $git_branch | **Messages:** $message_count

---

EOF

    # Extract full conversation in reading order using jq
    # jq outputs tagged lines; awk formats them into markdown
    # State machine: USER/ASSISTANT lines pass through, THINKING lines get > prefix,
    # TOOL lines get formatted as `tool: input`
    jq -r '
      select(.type == "user" or .type == "assistant") |
      if .type == "user" and .message.role == "user" then
        if (.message.content | type) == "string" then
          "@@USER@@", .message.content
        elif (.message.content | type) == "array" then
          .message.content[] |
          if .type == "text" then
            "@@USER@@", .text
          else empty end
        else empty end
      elif .type == "assistant" and .message.role == "assistant" then
        (.message.content // [])[] |
        if .type == "text" then
          "@@ASSISTANT@@", .text
        elif .type == "thinking" then
          "@@THINKING@@", .thinking, "@@END_THINKING@@"
        elif .type == "tool_use" then
          "@@TOOL@@" + .name + "@@" + (
            if .name == "Read" or .name == "Edit" or .name == "Write" then
              (.input.file_path // "")
            elif .name == "Bash" then
              (.input.command // "")[0:200]
            elif .name == "Grep" then
              (.input.pattern // "") + " " + (.input.path // "")
            elif .name == "Glob" then
              (.input.pattern // "") + " " + (.input.path // "")
            elif .name == "WebSearch" then (.input.query // "")
            elif .name == "WebFetch" then (.input.url // "")
            elif .name == "Task" then (.input.prompt // "")[0:200]
            elif .name == "Skill" then (.input.skill // "")
            else (.input | keys[0:3] | join(", "))
            end
          )
        else empty end
      else empty end
    ' "$jsonl_file" 2>/dev/null | awk '
      # Strip <system-reminder>...</system-reminder> blocks
      /<system-reminder>/,/<\/system-reminder>/ { next }
      /^\[Request interrupted\]/ { next }

      /^@@USER@@$/ {
        printf "\n## User\n\n"
        state = "user"
        next
      }
      /^@@ASSISTANT@@$/ {
        printf "\n## Assistant\n\n"
        state = "assistant"
        next
      }
      /^@@THINKING@@$/ {
        printf "\n<details><summary>Thinking</summary>\n\n"
        state = "thinking"
        next
      }
      /^@@END_THINKING@@$/ {
        printf "\n</details>\n"
        state = ""
        next
      }
      /^@@TOOL@@/ {
        # Parse @@TOOL@@name@@input
        s = substr($0, 9)  # after @@TOOL@@ (8 chars)
        idx = index(s, "@@")
        if (idx > 0) {
          name = substr(s, 1, idx - 1)
          input = substr(s, idx + 2)
          printf "- `%s`: %s\n", name, input
        }
        next
      }

      state == "thinking" {
        print "> " $0
        next
      }

      { print }
    '

  } > "$output_file"

  echo "  + $project_name/$session_id"
  return 0
}

# Extract all metadata from JSONL in one jq pass
extract_metadata() {
  local jsonl_file="$1"
  jq -rs '
    def first_user_prompt:
      map(select(.type == "user" and .message.role == "user" and (.message.content | type == "string")))
      | .[0].message.content // ""
      | gsub("<system-reminder>[\\s\\S]*?</system-reminder>"; "")
      | gsub("^\\s+"; "")
      | .[0:200];

    def message_count:
      map(select(.type == "user" or .type == "assistant")) | length;

    def first_timestamp:
      map(select(.timestamp)) | .[0].timestamp // "";

    def last_timestamp:
      map(select(.timestamp)) | .[-1].timestamp // "";

    def git_branch:
      map(select(.gitBranch)) | .[0].gitBranch // "unknown";

    def project_path:
      map(select(.cwd)) | .[0].cwd // "";

    {
      firstPrompt: first_user_prompt,
      messageCount: message_count,
      created: first_timestamp,
      modified: last_timestamp,
      gitBranch: git_branch,
      projectPath: project_path
    }
  ' "$jsonl_file" 2>/dev/null || echo '{"firstPrompt":"","messageCount":0,"created":"","modified":"","gitBranch":"unknown","projectPath":""}'
}

# Lookup session in index file (faster than parsing full JSONL)
lookup_session_in_index() {
  local jsonl_path="$1"
  local project_dir index_file
  project_dir=$(dirname "$jsonl_path")
  index_file="$project_dir/sessions-index.json"
  [[ -f "$index_file" ]] || return 0
  jq -c --arg path "$jsonl_path" '.entries[] | select(.fullPath == $path)' "$index_file" 2>/dev/null || true
}

# Convert index entry to metadata JSON matching extract_metadata format
index_entry_to_meta() {
  local entry="$1"
  echo "$entry" | jq -c '{
    firstPrompt: (.firstPrompt // "No prompt"),
    messageCount: (.messageCount // 0),
    created: (.created // ""),
    modified: (.modified // ""),
    gitBranch: (.gitBranch // "unknown"),
    projectPath: (.projectPath // "")
  }'
}

# Main: process all sessions
main() {
  local total=0 processed=0

  echo "Syncing Claude Code sessions to qmd (full content)..."
  echo "Mode: $MODE"
  echo ""

  for project_dir in "$PROJECTS_DIR"/*/; do
    [[ -d "$project_dir" ]] || continue

    for jsonl_file in "$project_dir"*.jsonl; do
      [[ -f "$jsonl_file" ]] || continue

      local session_id meta
      session_id=$(basename "$jsonl_file" .jsonl)
      ((total++)) || true

      # Try index first (fast), fall back to full JSONL parse
      local entry
      entry=$(lookup_session_in_index "$jsonl_file")

      if [[ -n "$entry" ]]; then
        meta=$(index_entry_to_meta "$entry")
      else
        meta=$(extract_metadata "$jsonl_file")
      fi

      if convert_session "$jsonl_file" "$session_id" "$meta"; then
        ((processed++)) || true
      fi  # returns 1 when skipped (incremental)
    done
  done

  echo ""
  echo "Done: $total sessions found, $processed synced"
  echo "Output: $OUTPUT_DIR"
}

main
