---
name: file-todos
description: Create, triage, update, and complete the repository's markdown todo files. Use for the file-based `todos/` queue, its schema, dependencies, work logs, and lifecycle; do not use for application Todo models or temporary session progress.
---

# File Todos

This skill is the source of truth for the file-based todo system. A todo is a markdown file in `todos/`; it is distinct from an application's Todo model and from temporary progress tracked by an agent runtime.

## Authorization and scope

Do not create or modify todo files merely because the user asks a question, requests a review, or wants findings triaged. Persist a finding only when the user asks to track it, approves it during triage, or has already authorized a workflow whose requested output is a todo file.

Within that authorization:

- keep filename status and frontmatter status consistent;
- never reuse an issue ID;
- leave skipped or deferred items unchanged;
- do not implement a finding during triage; and
- do not stage, commit, push, or post external comments unless the user authorized that action. If staging is authorized, stage only the relevant todo and implementation paths.

## Choose the operation

- For file naming, fields, creation, dependencies, work logs, status transitions, or completion, read [references/schema-and-lifecycle.md](references/schema-and-lifecycle.md).
- For interactive review of pending todos or untracked findings, read both the schema/lifecycle reference and [references/triage.md](references/triage.md).
- When creating a file, start from [assets/todo-template.md](assets/todo-template.md) and remove unused optional sections.

Inspect repository instructions and existing `todos/` files before changing the queue. Follow a repository-specific schema when it intentionally differs from this skill; report the difference instead of silently mixing formats.

## Completion

After a mutation, verify that filenames, frontmatter, dependencies, acceptance criteria, and work-log entries agree. Report the exact files created, renamed, or updated and any items left pending. Continue into implementation only when the user's request includes it.
