---
name: resolve-todo-parallel
description: Resolve a set of repository todo files in dependency-aware waves, using parallel workers only for independent work.
---

# Resolve Todo Files

Finish the requested todo files completely while preserving dependency order and avoiding overlapping edits.

## Workflow

1. Find the todo directory from the user's path or repository convention. Read every candidate before changing code.
2. Build a dependency graph. For each todo, record prerequisites, owned files or modules, completion criteria, and verification.
3. Show a Mermaid graph only when it makes non-trivial dependencies easier to understand.
4. Execute ready items in waves. Run independent items concurrently only when the active runtime permits delegation. Cap a wave at the available worker slots and normally at three workers.
5. Give each worker exclusive file or module ownership and tell it that other workers share the checkout. Keep overlapping or dependent items in the main agent or in later waves.
6. After each wave, inspect the integrated diff, resolve interactions centrally, and run the focused checks required by those todos.
7. Update a todo's status or rename its file only after its acceptance criteria pass. Preserve the repository's existing status and naming convention.
8. Report completed, blocked, and skipped items with evidence.

## Git Boundary

Do not infer permission to commit or push from a request to resolve todos. Stage, commit, or push only when the user has already authorized that action. If authorized, stage centrally after worker changes are integrated; workers must not create competing commits.

Stop and ask only when a real dependency, conflict, or missing product decision cannot be resolved from the repository or the user's existing instructions.
