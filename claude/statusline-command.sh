#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON
model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')

# Get directory info
dir_name=$(basename "$current_dir")
relative_path=""

# Show relative path if we're in a subdirectory of the project
if [[ "$current_dir" != "$project_dir" && "$current_dir" =~ ^"$project_dir" ]]; then
    relative_path="${current_dir#$project_dir/}"
    dir_name="$relative_path"
fi

# Enhanced git status check
git_info=""
if cd "$current_dir" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
        # Get detailed git status
        staged=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        modified=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
        
        # Build git status indicators
        status_indicators=""
        if [[ "$staged" -gt 0 ]]; then
            status_indicators="${status_indicators}\033[32m+${staged}\033[0m"
        fi
        if [[ "$modified" -gt 0 ]]; then
            status_indicators="${status_indicators}\033[33m~${modified}\033[0m"
        fi
        if [[ "$untracked" -gt 0 ]]; then
            status_indicators="${status_indicators}\033[31m?${untracked}\033[0m"
        fi
        
        # Get ahead/behind status
        ahead_behind=""
        if upstream=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null); then
            ahead=$(git rev-list --count HEAD..@{upstream} 2>/dev/null || echo "0")
            behind=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
            if [[ "$ahead" -gt 0 ]]; then
                ahead_behind="${ahead_behind}\033[36m↓${ahead}\033[0m"
            fi
            if [[ "$behind" -gt 0 ]]; then
                ahead_behind="${ahead_behind}\033[35m↑${behind}\033[0m"
            fi
        fi
        
        # Combine git info
        git_info=" \033[94m$branch\033[0m"
        if [[ -n "$status_indicators" ]]; then
            git_info="${git_info} $status_indicators"
        fi
        if [[ -n "$ahead_behind" ]]; then
            git_info="${git_info} $ahead_behind"
        fi
        
        # Add clean indicator if no changes
        if [[ "$staged" -eq 0 && "$modified" -eq 0 && "$untracked" -eq 0 ]]; then
            git_info="${git_info} \033[32m✓\033[0m"
        fi
    fi
fi

# Get full current working directory (abbreviated home path)
full_path=$(pwd | sed "s|$HOME|~|")

# Build the status line with enhanced git and path info
printf "\033[36m%s\033[0m \033[34m%s\033[0m\033[37m%s\033[0m \033[90m%s\033[0m" \
    "$model_name" \
    "$dir_name" \
    "$git_info" \
    "$full_path"