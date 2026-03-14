---
name: gwt
description: |
  Manage git worktrees using a centralized worktrees folder. Use for parallel development,
  PR reviews, or isolated work. Triggers on "worktree", "gwt", "parallel branch",
  "isolated review", "new worktree", "switch worktree", "work on multiple branches",
  "review PR in isolation", "parallel development".
---

# Git Worktree Manager (gwt)

Use a **centralized `worktrees/` folder** to keep all worktrees organized and your main code directory clean.

Naming: `{repo-name}--{branch-name}` (double dash separator, slashes become dashes)

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

- This avoids Turbopack/IDE conflicts with multiple lockfiles
- `.env*` and `.dev.vars` are automatically copied from main repo
- Set `GWT_EXTRA_FILES` for additional file patterns (space-separated)
- `GWT_WORKTREE_DIR` env var overrides the worktrees directory

### Cleanup

```bash
# Remove worktree and branch
gwt rm my-feature

# Keep the branch, just remove worktree
gwt rm my-feature --keep-branch
```

## Agent Rules

- Always use absolute paths -- `cd` does not persist between Bash calls
- Display worktree name as directory basename for statusline
- Prefer `gwt` commands over raw `git worktree`
- **CRITICAL: `gwt new <branch>` without `[from]` creates from HEAD** — this is almost always wrong for remote branches. Always specify the starting point for remote work.
- **Never use `git reset --hard` or `git checkout .` to fix a wrongly-created worktree** — user hooks may block destructive commands. Instead: `gwt rm` + recreate.

### Creating worktrees for remote branches

Any time you create a worktree for a branch that exists on a remote (PR review, checking out someone's branch, etc.), you MUST:

1. **Fetch first**: `git fetch origin <branch>` — the ref may not exist locally
2. **Specify `[from]`**: `gwt new <branch> origin/<branch>`
3. **Verify**: `cd "$WT" && git log --oneline -1` — confirm HEAD matches expected commit

```bash
# CORRECT — remote branch worktree
git fetch origin feat/auth
gwt new feat/auth origin/feat/auth

# WRONG — creates from current HEAD, not the remote branch
gwt new feat/auth
```

### PR review workflow

When the user asks to review a PR or create a worktree for one, **always infer the branch automatically**. The user may provide:
- A PR URL: `https://github.com/org/repo/pull/728`
- A PR number: `728`
- A conversational reference with a URL/number in the message

In all cases, extract the branch name via `gh pr view` — never ask the user for the branch name if you have a PR URL or number.

```bash
# 1. Extract branch name (works with URL or number)
BRANCH=$(gh pr view <url-or-number> --json headRefName --jq '.headRefName')

# 2. Fetch + create from remote ref
git fetch origin "$BRANCH"
gwt new "$BRANCH" "origin/$BRANCH"

# 3. Verify and get path
WT=$(gwt go "$BRANCH")
cd "$WT" && git log --oneline -1
```

If the user says "review this PR" without a number, check the conversation for a URL. If none found, ask for the PR number/URL.

### Error recovery

If a worktree was created from the wrong starting point:
- Do NOT attempt `git reset --hard` or `git checkout` — hooks may block these
- Instead, remove and recreate:

```bash
gwt rm <branch>
git fetch origin <branch>
gwt new <branch> origin/<branch>
```

This is idempotent and hook-safe.

## When to Use

- **Reviewing PRs** in isolation without switching branches
- **Parallel development** on multiple features
- **Testing changes** without affecting main branch state
- **Overnight/long-running** work that shouldn't block other work
