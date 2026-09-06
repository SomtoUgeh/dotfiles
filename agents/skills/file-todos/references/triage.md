# Triage mode

Read this reference when the user asks to review pending todo files or decide which findings should enter the file-based queue. The canonical schema and every status transition remain in [schema-and-lifecycle.md](schema-and-lifecycle.md).

## Prepare

Use the inputs the user identified. When they ask to triage the repository queue, read every `todos/*-pending-*.md` file. When they provide findings in the conversation, do not create placeholder files before approval.

Merge obvious duplicates for presentation, but preserve the identity and evidence of existing todo files. Do not implement fixes during triage.

## Present a decision

Present one item at a time unless the user asks for a batch. Include only information supported by the finding:

```text
Issue <ID or session number>: <title>
Priority: P1 | P2 | P3
Category: <category>
Problem: <what fails and why it matters>
Evidence: <location, observation, or source>
Proposed action: <candidate resolution>
Effort or risk: <only when evidence supports an estimate>

Decision: approve | skip | defer (leave pending) | modify
```

Use the runtime's structured question tool when available and helpful. If the user already supplied a bulk decision, apply it without asking again.

## Apply the decision

### Approve

- Existing pending todo: apply the `pending` to `ready` transition in the schema/lifecycle reference.
- Untracked finding: create a `ready` todo from the canonical template because the approval supplies the lifecycle decision.
- Record the selected action and acceptance criteria; do not add speculative implementation detail.

Confirm the resulting filename and issue ID.

### Skip

Leave an existing todo unchanged. For an untracked finding, create no file. Record the item in the session summary so omission is explicit; skipping never authorizes deletion.

### Modify

Ask for or apply the requested changes to priority, wording, scope, dependencies, or proposed action. Present the revised decision before persisting it unless the user's instruction already authorized the revision.

### Defer / leave pending

Leave the existing file unchanged and record the explicit deferral in the
session summary. For an untracked finding, create no file unless the user also
asks to track it as pending. Deferral is a completed triage decision, distinct
from skipping the item or still needing an answer.

## Continue and summarize

Track `processed / total`, approved, skipped, deferred, and unresolved decisions.
Do not invent time-remaining estimates.

At the end, report:

- totals for processed, approved, skipped, deferred, and unresolved items;
- every todo created or moved to `ready`;
- skipped and deferred existing files as unchanged; and
- any decision still needed.

Offer implementation or commit as a next step only when relevant. Do not start either action without authorization.
