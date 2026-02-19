---
description: Resolve all PR comments using parallel processing
---

Resolve all PR comments using parallel processing.

opencode automatically detects and understands your git context:

- Current branch detection
- Associated PR context
- All PR comments and review threads
- Can work with any PR by specifying the PR number, or ask it.

## Workflow

### 1. Analyze

Get all unresolved comments for PR

```bash
gh pr status
gh pr view PR_NUMBER --json reviewRequests,reviews,comments
gh api repos/{owner}/{repo}/pulls/PR_NUMBER/comments
```

### 2. Plan

Create a todowrite list of all unresolved items grouped by type.

### 3. Implement (PARALLEL)

Spawn a general-purpose agent for each unresolved item in parallel.

So if there are 3 comments, spawn 3 agents in parallel:

1. Task general-purpose(comment1)
2. Task general-purpose(comment2)
3. Task general-purpose(comment3)

Always run all in parallel subagents/Tasks for each Todo item.

### 4. Commit & Resolve

- Commit changes
- Push to remote
- Reply to resolved threads with a brief summary of changes made

Last, check `gh pr view PR_NUMBER --json comments` again to see if all comments are resolved. They should be, if not, repeat the process from 1.
