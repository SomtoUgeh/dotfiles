---
name: gwt
description: Manage git worktrees using a centralized worktrees folder
argument-hint: "[action] [branch]"
allowed-tools: Bash, Read
user-invocable: true
arguments:
  - name: action
    description: "Command: new, ls, go, switch, rm, here"
    required: false
  - name: branch
    description: Branch name for new/go/switch/rm commands
    required: false
---

# Git Worktree Manager

Manage git worktrees using a centralized `worktrees/` folder to keep the main code directory clean.

## Available Actions

- `new <branch> [from]` - Create a new worktree (copies .env files)
- `ls` - List all worktrees for the current repository
- `go <branch>` - Output the path to switch to a worktree
- `switch <branch>` - Copy "cd <path> && claude" to clipboard
- `rm <branch>` - Remove a worktree and its branch
- `here` - Show info about the current worktree

## Instructions

1. If no action specified, show `gwt ls` output and explain available commands

2. For `new`:
   - Run `gwt new <branch>`
   - Report the created path
   - Remind user to run `bun install` after switching

3. For `ls`:
   - Run `gwt ls --json` for parsing
   - Format output nicely for user

4. For `go`:
   - Run `gwt go <branch>` to get path
   - Output a `cd` command the user can copy

5. For `switch`:
   - Run `gwt switch <branch>`
   - Inform user the command is in their clipboard

6. For `rm`:
   - Confirm with user before removing
   - Run `gwt rm <branch>`
   - Report success

7. For `here`:
   - Run `gwt here`
   - Show current worktree information

## Flags

- `--json` - Machine-readable output (for ls, here)
- `--no-env` - Skip .env file copying (for new)
- `--keep-branch` - Don't delete branch on rm

## Notes

- Worktrees are created in a centralized `worktrees/` folder (sibling to code projects)
- This avoids Turbopack/IDE conflicts with multiple lockfiles
- .env files are automatically copied from main repo
- `GWT_WORKTREE_DIR` env var overrides the worktrees directory

## Success Criteria

- [ ] Worktree created/listed/removed successfully
- [ ] User informed of next steps (e.g., `bun install`, `cd` command)
- [ ] Confirmation obtained before destructive operations
