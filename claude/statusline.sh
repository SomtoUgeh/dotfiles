#!/bin/bash
# Custom Claude Code statusline with worktree awareness
# Features: directory, git, worktree, model, version, context window

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

# ---- JSON extraction (bash only, no jq dependency) ----
# Extract current_dir from workspace object
current_dir=$(echo "$input" | grep -o '"workspace"[[:space:]]*:[[:space:]]*{[^}]*"current_dir"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"current_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | sed 's/\\\\/\//g')
if [ -z "$current_dir" ] || [ "$current_dir" = "null" ]; then
  current_dir=$(echo "$input" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | sed 's/\\\\/\//g')
fi
[ -z "$current_dir" ] && current_dir="unknown"

# Extract folder basename only
folder_name=$(basename "$current_dir")

# Extract model name
model_name=$(echo "$input" | grep -o '"model"[[:space:]]*:[[:space:]]*{[^}]*"display_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
[ -z "$model_name" ] && model_name="Claude"

# Extract CC version
cc_version=$(echo "$input" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

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

# ---- context window ----
ctx_used_pct=$(echo "$input" | grep -o '"used_percentage"[[:space:]]*:[[:space:]]*[0-9.]*' | sed 's/.*:[[:space:]]*//')
ctx_window_size=$(echo "$input" | grep -o '"context_window_size"[[:space:]]*:[[:space:]]*[0-9]*' | sed 's/.*:[[:space:]]*//')
# total_input_tokens is cumulative API calls, not context fill — derive from pct instead

# Build visual bar: 10 segments
ctx_bar=""
ctx_color_fn=""
if [ -n "$ctx_used_pct" ] && [ -n "$ctx_window_size" ]; then
  pct_int=${ctx_used_pct%.*}
  [ -z "$pct_int" ] && pct_int=0

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

  # Derive used tokens from percentage (total_input_tokens doesn't reflect context fill)
  used_k=$(( (pct_int * ctx_window_size / 100) / 1000 ))
  total_k=$((ctx_window_size / 1000))

  ctx_bar=$(printf '%s%s%s%s%s %s%s%%  %sk/%sk' \
    "$($ctx_color_fn)" "$bar_filled" "$(ctx_dim_color)" "$bar_empty" "$(rst)" \
    "$($ctx_color_fn)" "$pct_int" "$used_k" "$total_k")
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
