# Todo schema and lifecycle

Read this reference when creating or changing a file-based todo.

## Filename and identity

Use:

```text
{issue_id}-{status}-{priority}-{description}.md
```

- `issue_id`: zero-padded sequence such as `001`; never reuse an ID.
- `status`: `pending`, `ready`, or `complete`.
- `priority`: `p1` critical, `p2` important, or `p3` nice-to-have.
- `description`: concise kebab-case text.

Examples:

```text
001-pending-p1-mailer-test.md
002-ready-p1-fix-n-plus-1.md
005-complete-p2-refactor-csv.md
```

The filename and YAML fields must agree.

## Frontmatter and sections

Required frontmatter:

```yaml
---
status: pending
priority: p2
issue_id: "001"
tags: []
dependencies: []
---
```

Dependencies contain issue IDs that must be complete before work begins:

```yaml
dependencies: ["002", "005"]
```

Required sections:

- **Problem Statement**: the observed problem and why it matters.
- **Findings**: evidence, root cause, locations, and relevant context.
- **Proposed Solutions**: realistic options and their tradeoffs; one option is enough when no material alternative exists.
- **Recommended Action**: the approved approach, filled when the todo becomes ready.
- **Acceptance Criteria**: testable conditions for completion.
- **Work Log**: dated actions, verification, and relevant learning.

Add **Technical Details**, **Resources**, or **Notes** only when useful. Use [../assets/todo-template.md](../assets/todo-template.md) to create a new file.

## Create

1. Confirm that persisting the item is authorized and that an existing todo does not already cover it.
2. Determine the next ID from every status, starting at `001` when the directory is empty:

   ```bash
   find todos -maxdepth 1 -type f -print \
     | sed 's#.*/##' \
     | awk -F- '/^[0-9]+-/{if (($1 + 0) > max) max = $1 + 0} END {printf "%03d\n", max + 1}'
   ```

3. Resolve the directory containing `file-todos/SKILL.md`, copy its `assets/todo-template.md`, and name the destination with the new ID, status, priority, and description. Do not assume the project has a top-level `assets/` directory.
4. Replace placeholders, add the evidence available, and record the initial work-log entry.
5. Use `pending` when a decision is still needed. Use `ready` only when the user or governing workflow has approved the recommended action.

Small, obvious work that the user asked to implement usually does not need a todo unless they also asked to track it.

## Triage: pending to ready

Approval changes a todo from `pending` to `ready`:

1. Record the chosen solution in **Recommended Action**.
2. Adjust priority, tags, dependencies, description, and acceptance criteria only as approved.
3. Rename the file so its status and priority match the updated frontmatter.
4. Add a dated approval entry to **Work Log**.
5. Verify the issue ID did not change.

Deferral or a skipped finding leaves the existing file unchanged. It never authorizes deletion.

## Work and completion

Before starting, verify dependencies. Keep the file `ready` while implementation is in progress; the canonical persisted lifecycle has no `in-progress` filename state.

**To verify blockers are complete before starting:**

```bash
for dep in 001 002 003; do
  find todos -maxdepth 1 -type f -name "${dep}-complete-*.md" -print -quit \
    | RIPGREP_CONFIG_PATH= rg -q . || echo "Issue $dep not complete"
done
```

To find todos blocked by issue `002`:

```bash
RIPGREP_CONFIG_PATH= rg -l 'dependencies:.*"002"' todos --glob '*.md'
```

During authorized implementation, append work-log entries that capture meaningful actions, evidence, tests, and lessons. Do not turn the log into a transcript of routine commands.

Mark a todo complete only after every acceptance criterion is satisfied or any explicit exception is recorded:

1. Check the completed acceptance criteria.
2. Add a final work-log entry with verification results.
3. Change frontmatter status from `ready` to `complete`.
4. Rename the file from `ready` to `complete`, preserving its ID, priority, and description.
5. Identify dependent ready items that may now be unblocked.

If a commit was explicitly requested, include the todo and its implementation using the repository's commit convention. Otherwise leave the verified changes uncommitted.

## Work-log entry

```markdown
### YYYY-MM-DD - <session title>

**By:** <agent or developer>

**Actions:**
- <material change or investigation, with file references where useful>
- <verification and result>

**Learnings:**
- <information that will help later work, or "None">
```

## Useful queries

List pending items:

```bash
find todos -maxdepth 1 -type f -name '*-pending-*.md' -print
```

List unblocked P1 work:

```bash
RIPGREP_CONFIG_PATH= rg -l '^dependencies: \[\]$' todos --glob '*-ready-p1-*.md'
```

Search by tag or text:

```bash
RIPGREP_CONFIG_PATH= rg 'rails|payment' todos --glob '*.md'
```
