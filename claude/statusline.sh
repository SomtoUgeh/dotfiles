#!/bin/bash
# Custom Claude Code statusline with worktree awareness
# Features: directory, git, worktree, model, version

input=$(cat)

# ---- color helpers (force colors for Claude Code) ----
use_color=1
[ -n "$NO_COLOR" ] && use_color=0

# ---- modern sleek colors ----
dir_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;117m'; fi; }      # sky blue
model_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;147m'; fi; }    # light purple
cc_version_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;249m'; fi; } # light gray
worktree_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;214m'; fi; } # amber/orange
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

# ---- worktree detection (run from current_dir context) ----
in_worktree=0
worktree_name=""
main_repo_name=""
worktree_count=0

if [ -d "$current_dir" ] && git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
  # Get the toplevel of current repo
  toplevel=$(git -C "$current_dir" rev-parse --show-toplevel 2>/dev/null)

  # Check if we're in a worktree (not the main repo)
  git_common_dir=$(git -C "$current_dir" rev-parse --git-common-dir 2>/dev/null)
  git_dir=$(git -C "$current_dir" rev-parse --git-dir 2>/dev/null)

  if [ "$git_common_dir" != "$git_dir" ] && [ "$git_common_dir" != ".git" ]; then
    # We're in a worktree
    in_worktree=1
    main_repo_dir=$(dirname "$git_common_dir")
    main_repo_name=$(basename "$main_repo_dir")
    worktree_name=$(basename "$toplevel")  # current worktree folder
  fi

  # Count total worktrees (excluding main)
  worktree_count=$(git -C "$current_dir" worktree list 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
fi

# ---- render statusline ----
# Format: 📁 repo  🌿 branch  🪵 worktree  🤖 model  📟 version

# Show main repo name when in worktree, otherwise current folder
if [ "$in_worktree" -eq 1 ] && [ -n "$main_repo_name" ]; then
  printf '📁 %s%s%s' "$(dir_color)" "$main_repo_name" "$(rst)"
else
  printf '📁 %s%s%s' "$(dir_color)" "$folder_name" "$(rst)"
fi

if [ -n "$git_branch" ]; then
  printf '  🌿 %s%s%s' "$(git_color)" "$git_branch" "$(rst)"
fi

# Worktree indicator
if [ "$in_worktree" -eq 1 ]; then
  # Inside a worktree: show worktree name
  printf '  🪵 %s%s%s' "$(worktree_color)" "$worktree_name" "$(rst)"
elif [ "$worktree_count" -gt 0 ]; then
  # In main repo with active worktrees: show count
  printf '  🪵 %s+%s%s' "$(worktree_color)" "$worktree_count" "$(rst)"
fi

printf '  🤖 %s%s%s' "$(model_color)" "$model_name" "$(rst)"

if [ -n "$cc_version" ] && [ "$cc_version" != "null" ]; then
  printf '  📟 %sv%s%s' "$(cc_version_color)" "$cc_version" "$(rst)"
fi

printf '\n'
