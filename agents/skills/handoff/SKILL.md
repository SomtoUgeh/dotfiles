---
name: handoff
description: Creates compact handoff documents for fresh agents to continue a conversation or task. Use when the user asks for a handoff, session summary, continuation note, or compacted context for the next agent.
---

# Handoff

## Quick Start

Create a temporary markdown file, read it before writing, then write a concise handoff document:

```bash
handoff_file="$(mktemp -t handoff-XXXXXX.md)"
sed -n '1,40p' "$handoff_file"
```

After writing the document, report the absolute path and the skills suggested for the next session.

## Instructions

1. Identify the next session focus from the user's arguments or most recent request.
2. Create the destination with `mktemp -t handoff-XXXXXX.md`.
3. Read the newly created file before writing to it, even though it should be empty.
4. Summarize only the current conversation details a fresh agent needs.
5. Reference existing artifacts by path or URL instead of copying their contents.
6. Suggest any skills the next session should use, including why each skill is relevant.
7. Save the handoff document to the temporary file.
8. Return the file path and a short note about what it covers.

## Handoff Content

Include sections only when they add useful continuation context:

```markdown
# Handoff

## Next Session Focus
[What the next agent should work on.]

## Current State
[Decisions, progress, blockers, and important facts from this conversation.]

## Relevant Artifacts
- [Path or URL] - [why it matters]

## Suggested Skills
- [skill-name] - [why the next agent should use it]

## Open Questions
- [Question or decision still needed]

## Recommended Next Steps
1. [First concrete action]
2. [Second concrete action]
```

## Guidelines

- Keep the handoff compact and operational.
- Do not duplicate content already captured in PRDs, plans, ADRs, issues, commits, diffs, or other artifacts.
- Prefer concrete paths, URLs, command results, and file references over narrative.
- Preserve user constraints, explicit preferences, and unresolved decisions.
- If no skills are needed for the next session, say so in the document.
- Do not include hidden chain-of-thought, private reasoning, or unrelated conversation history.

## Success Criteria

- A markdown handoff exists at a path created by `mktemp -t handoff-XXXXXX.md`.
- The file was read before writing.
- The document is tailored to the next session focus when arguments were provided.
- Existing artifacts are referenced instead of duplicated.
- Suggested skills are listed with short reasons, or the document says none are needed.
