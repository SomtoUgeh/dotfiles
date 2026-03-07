#!/bin/bash
# Custom Claude Code statusline with worktree awareness
# Features: directory, git, worktree, model, version, context window
# Requires: jq, git

input=$(cat)

# ---- color helpers (force colors for Claude Code) ----
use_color=1
[ -n "$NO_COLOR" ] && use_color=0

# ---- modern sleek colors ----
dir_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;117m'; fi; }      # sky blue
model_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;147m'; fi; }    # light purple
cc_version_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;249m'; fi; } # light gray
worktree_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;214m'; fi; } # amber/orange
ctx_low_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;150m'; fi; }   # green (<50%)
ctx_mid_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;214m'; fi; }   # amber (50-79%)
ctx_high_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;203m'; fi; }  # red (80%+)
ctx_dim_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;240m'; fi; }   # dim gray (unfilled bar)
rst() { if [ "$use_color" -eq 1 ]; then printf '\033[0m'; fi; }

# ---- JSON extraction (single jq call for speed) ----
eval "$(echo "$input" | jq -r '
  @sh "current_dir=\(.workspace.current_dir // .cwd // "unknown")",
  @sh "model_name=\(.model.display_name // "Claude")",
  @sh "cc_version=\(.version // "")",
  @sh "ctx_window_size=\(.context_window.context_window_size // "")",
  @sh "transcript_path=\(.transcript_path // "")",
  @sh "fallback_pct=\(.context_window.used_percentage // 0)"
')"
folder_name=$(basename "$current_dir")

# ---- git colors ----
git_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;150m'; fi; }  # soft green

# ---- git branch (run from current_dir context) ----
git_branch=""
if [ -d "$current_dir" ] && git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
  git_branch=$(git -C "$current_dir" branch --show-current 2>/dev/null || git -C "$current_dir" rev-parse --short HEAD 2>/dev/null)
fi

# ---- worktree detection (gwt-managed only: ~/code/worktrees/) ----
in_worktree=0
worktree_name=""
main_repo_name=""
worktree_count=0
gwt_dir="$HOME/code/worktrees"

if [ -d "$current_dir" ] && git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
  toplevel=$(git -C "$current_dir" rev-parse --show-toplevel 2>/dev/null)

  # Only detect as worktree if under gwt-managed directory
  case "$toplevel" in
    "$gwt_dir"/*)
      in_worktree=1
      wt_basename=$(basename "$toplevel")
      # gwt naming: {repo}--{branch}, extract repo name (before --)
      main_repo_name="${wt_basename%%--*}"
      # Extract branch part (after --), convert dashes back for display
      worktree_name="${wt_basename#*--}"
      ;;
  esac

  # Count gwt-managed worktrees for this repo only
  repo_name=$(basename "$toplevel")
  [ "$in_worktree" -eq 1 ] && repo_name="$main_repo_name"
  if [ -d "$gwt_dir" ]; then
    worktree_count=0
    for d in "$gwt_dir"/"${repo_name}"--*; do
      [ -d "$d" ] && worktree_count=$((worktree_count + 1))
    done
  fi
fi

# ---- context window (via transcript parsing for accuracy) ----
# used_percentage from JSON undercounts (excludes tool results).
# Parsing the transcript JSONL gives accurate numbers matching /context.
ctx_used_tokens=0
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  # Usage lives at .message.usage (assistant entries) or .toolUseResult.usage (subagent results)
  # Use tail -r (macOS) or tac (Linux) to read file in reverse
  reverse_cmd="tail -r"
  command -v tac >/dev/null 2>&1 && reverse_cmd="tac"
  last_usage=$($reverse_cmd "$transcript_path" 2>/dev/null | grep -m1 '"input_tokens"' | jq -r '(.message.usage // .toolUseResult.usage // empty)' 2>/dev/null)
  if [ -n "$last_usage" ] && [ "$last_usage" != "null" ]; then
    eval "$(echo "$last_usage" | jq -r '
      @sh "input_tok=\(.input_tokens // 0)",
      @sh "cache_read=\(.cache_read_input_tokens // 0)",
      @sh "cache_create=\(.cache_creation_input_tokens // 0)"
    ')"
    ctx_used_tokens=$((input_tok + cache_read + cache_create))
  fi
fi

# Fallback to used_percentage if transcript parsing fails
if [ "$ctx_used_tokens" -eq 0 ] && [ -n "$ctx_window_size" ]; then
  ctx_used_tokens=$((fallback_pct * ctx_window_size / 100))
fi

# Build visual bar: 10 segments, scaled to usable window (minus auto-compact buffer)
autocompact_buffer=33000
usable_window=$((ctx_window_size - autocompact_buffer))

ctx_bar=""
ctx_color_fn=""
if [ -n "$ctx_window_size" ] && [ "$usable_window" -gt 0 ]; then
  pct_int=$((ctx_used_tokens * 100 / usable_window))
  [ "$pct_int" -gt 100 ] && pct_int=100

  # Pick color based on usage
  if [ "$pct_int" -ge 80 ]; then
    ctx_color_fn="ctx_high_color"
  elif [ "$pct_int" -ge 50 ]; then
    ctx_color_fn="ctx_mid_color"
  else
    ctx_color_fn="ctx_low_color"
  fi

  # Bar: 10 chars, each = 10%
  filled=$((pct_int / 10))
  empty=$((10 - filled))
  bar_filled=""
  bar_empty=""
  i=0; while [ "$i" -lt "$filled" ]; do bar_filled="${bar_filled}━"; i=$((i + 1)); done
  i=0; while [ "$i" -lt "$empty" ]; do bar_empty="${bar_empty}─"; i=$((i + 1)); done

  ctx_bar=$(printf '%s%s%s%s%s %s%s%%' \
    "$($ctx_color_fn)" "$bar_filled" "$(ctx_dim_color)" "$bar_empty" "$(rst)" \
    "$($ctx_color_fn)" "$pct_int")
fi

# ---- render statusline ----
# Format: 📁 repo  🌿 branch  🪵 worktree  🤖 model  📟 version  📊 context

# Show main repo name when in worktree, otherwise current folder
if [ "$in_worktree" -eq 1 ] && [ -n "$main_repo_name" ]; then
  printf '📁 %s%s%s' "$(dir_color)" "$main_repo_name" "$(rst)"
else
  printf '📁 %s%s%s' "$(dir_color)" "$folder_name" "$(rst)"
fi

if [ -n "$git_branch" ]; then
  printf '\n🌿 %s%s%s' "$(git_color)" "$git_branch" "$(rst)"
fi

# Worktree indicator
if [ "$in_worktree" -eq 1 ]; then
  printf '  🪵 %s%s%s' "$(worktree_color)" "$worktree_name" "$(rst)"
elif [ "$worktree_count" -gt 0 ]; then
  printf '  🪵 %s+%s%s' "$(worktree_color)" "$worktree_count" "$(rst)"
fi

printf '\n🤖 %s%s%s' "$(model_color)" "$model_name" "$(rst)"

if [ -n "$cc_version" ] && [ "$cc_version" != "null" ]; then
  printf '  📟 %sv%s%s' "$(cc_version_color)" "$cc_version" "$(rst)"
fi

if [ -n "$ctx_bar" ]; then
  printf '  %s' "$ctx_bar"
fi

printf '\n'
