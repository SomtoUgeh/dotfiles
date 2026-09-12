---
name: deslop
description: "Audit or remove AI slop in code or prose: redundant comments, type hacks, over-engineering, or formulaic writing. Preserve behavior and voice; audit-only requests return findings."
---

# Deslop

Two domains, one skill. Pick the mode from the request; do not mix them unless
the user asks for both.

| Mode | When | Output |
|------|------|--------|
| **Code** (default for branches/diffs) | Branch cleanup, file path, "deslop this PR" | Minimal code edits + 1–3 sentence summary |
| **Write** | Pasted draft, "edit this", "humanize", "less AI" | Full edited draft + short **What changed** |
| **Detect** | "Is this AI?", audit/scan/flag without rewrite | Pattern list with quoted lines; no rewrite |

If the request is ambiguous and no draft or path is present, ask once whether
they mean code on the branch or a prose draft.

---

## Mode: Code

Check the requested change scope and remove code slop introduced there. Discover the repository's default branch instead of assuming `main`. Use its merge-base for branch changes and include staged, unstaged, and relevant untracked work when those are part of the request.

### Step 1: Get changed files

```bash
# Set review_base to the verified merge-base commit for the requested branch review.
git diff --name-only "$review_base" --
git ls-files --others --exclude-standard
```

If an argument was provided, focus only on that file.

Read the new and modified code with fresh eyes.

### Step 2: For each file, compare with original

For each changed file:

1. Read the current version
2. Read the original from the verified base: `git show "$review_base:<filepath>"`. A newly added file has no base version; compare with neighboring code instead.
3. Compare style, patterns, and conventions. Look for bugs, confusion, and
   drift from the file's existing voice.

### Step 3: Remove slop

Edit to remove:

**Unnecessary comments**

- Comments explaining obvious code (`// increment counter`)
- Comments that were not in the original and add no value
- Comments inconsistent with the file's existing style
- Redundant JSDoc/docstrings on simple functions

**Defensive over-engineering**

- Try/catch around code that cannot throw
- Null checks on values already validated upstream
- Defensive checks in internal/trusted paths
- Unnecessary `|| []` or `?? {}` defaults not present in similar code

**Type hacks**

- `as any` or `as unknown` casts
- `@ts-ignore` / `@ts-expect-error` without a clear reason
- `!` non-null assertions that hide real issues

**Style inconsistencies**

- Verbose patterns when the file is terse
- Naming that does not match the rest of the file
- Extra blank lines or formatting drift from original

**Over-abstraction**

- Helpers used only once
- Unnecessary intermediate variables
- Overly generic code for a specific use case

**General**

- Fix real bugs or confusion you uncover while cleaning

### Step 4: Report

Output ONLY a 1–3 sentence summary. No bullet points, no file lists, no long
explanations.

Example: "Removed 4 redundant comments and 2 unnecessary null checks. Simplified
error handling in auth.ts."

---

## Mode: Write

You are a sharp human editor. Preserve the user's point and personal voice.
Remove AI patterns without turning distinctive writing into generic polished
prose.

### Before editing

- If there is no draft, ask them to paste it.
- If audience/format is unclear, ask once: who is this for and where is it
  published?
- If the goal is unclear, ask what the reader should think, feel, or do.

### Editing principles

- **Preserve the writer's real voice.** Notice vocabulary, cadence, bluntness,
  humor, uncertainty, digressions, polish. Keep what feels personal. Do not make
  every paragraph equally tidy.
- **Minimum effective edit.** Fix AI patterns, errors, repetition, unclear
  passages. Leave strong human sentences alone.
- **Lead with the point** when setup adds nothing. Keep personal asides when
  they add context, tension, or character.
- **Keep the user's meaning.** Do not invent claims, examples, stats, or
  opinions. Ask if something is unclear.
- **Open it up; do not dumb it down.** Keep substance and precision. Strip
  jargon, tangled structure, and empty abstraction.
- **Active voice.** Prefer human subjects and direct verbs.
- **Every sentence earns its place.** Cut empty qualifiers. Keep "I think,"
  "maybe," "to be honest" when they express real uncertainty or spoken rhythm.
- **Be concrete.** Names, numbers, dates, mechanisms beat abstractions.
- **Preserve useful edge.** Strong opinions, humor, blunt language stay when
  they belong to the writer.
- **Keep structure** unless it is hurting the piece. If you reorganize, say why
  in **What changed**.

Load the full pattern catalog from [writing.md](writing.md). After editing,
check the draft against [eval.md](eval.md). If any check fails, fix and recheck.

### Write workflow

1. Read the full draft.
2. Identify the core point and 3–5 voice signals to preserve (internal only).
3. Make the minimum effective changes using [writing.md](writing.md).
4. Self-check with [eval.md](eval.md); fix failures.
5. Output the full edited draft and a short **What changed** section.

---

## Mode: Detect

Name each pattern from [writing.md](writing.md) that appears. For each:

- Pattern name
- Quoted line
- Fix in a few words

Do not rewrite, score the draft, or claim AI authorship. Detectors guess; named
patterns are evidence. Offer to edit after.

For detect self-checks, use the detect section of [eval.md](eval.md).

---

## Routing summary

```
/deslop                  → Code (branch vs main)
/deslop path/to/file     → Code (that file)
/deslop                  → Write (when draft is in the message)
  [draft here]
/deslop is this AI slop? → Detect
  [text]
```

Also accept natural language: "deslop this branch", "clean AI slop from this
post", "does this read as AI?".
