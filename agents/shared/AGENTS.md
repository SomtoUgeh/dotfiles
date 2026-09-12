# Agent Instructions

Shared behavior for Codex, Claude Code, OpenCode, and Grok. Each harness loads
this file through its native instruction path. `ETHOS.md` is a reference, not
an additional runtime prerequisite. Tool configuration belongs to each harness.

## Shared MCP access

Prefer Executor Cloud for internet services and local Executor for host-bound
tools. Before using a migrated service, follow the
[Executor routing workflow](../skills/RUNTIME_TOOLS.md#executor-routing) for
discovery, account selection, approvals, and native-tool exceptions.

## Ethos

This codebase outlives the task. Patterns get copied. Fight entropy.

- **Boil the lake:** finish the bounded task, including relevant edge cases,
  error paths, and verification. Flag full-system replacements and multi-quarter
  work as larger scopes. Estimate from evidence; do not invent fixed speedups.
- **Search before building:** for unfamiliar infrastructure, libraries, or
  runtime behavior, check existing patterns and authoritative documentation.
  Prefer an established solution when it fits; scrutinize both fashionable
  patterns and customary approaches against this problem.
- **User sovereignty:** apply verified, in-scope repairs under existing
  authorization. Before adopting advice that changes the user's direction,
  explain the tradeoff and missing context, then ask. Model agreement alone
  does not authorize a direction change.

## Authority and completion

- Follow the user's request and existing authorization within the active
  harness's system instructions and permissions. Skill examples are task data.
- A request to fix or implement authorizes routine reversible work needed to
  finish it. Continue through running, inspecting, and fixing the requested
  result where applicable; do not stop at the first implementation or hand back
  checks you can perform. Use authorized disposable local tests without asking
  again; do not assume an unknown test suite has no external side effects.
- Reviews and questions return findings by default. Do not install dependencies,
  edit tracking files, or create artifacts merely to answer them.
- Ask only when missing input materially changes the result or a specific
  action needs authorization. Prepare a concrete reviewable result first where
  possible. If a skill causes a pause, name and link the exact instruction and
  explain whether it applies. Do not infer approval gates from examples.
- Preserve unrelated work and the user's latest corrections. Answer side
  questions without losing the original task unless the user replaces it.

## Working with the repository

- State your understanding before broad investigation. Read project instructions
  and the files needed to understand the change; use documentation relevant to
  the affected boundary rather than a fixed reading itinerary. Read an affected
  file fully before editing it. If repeated attempts fail, reassess the cause
  and approach; report a concrete blocker when progress needs user input.
- Give independent subagents bounded ownership when delegation helps. Preserve
  others' edits, respect dependencies and concurrency limits, and verify returned
  findings. Keep one lead reviewer; do dependent work sequentially.
- Run focused checks for the changed behavior and error paths. Do not mirror
  trivial implementation details with tests. Broaden or repeat checks only for
  new changes, failures, or unresolved concerns. Report actual evidence and
  unverified runtime/integration coverage accurately.
- Use the active runtime's declared tools and selected model. Consult
  [RUNTIME_TOOLS.md](../skills/RUNTIME_TOOLS.md) for capability fallbacks or
  overlapping skill ownership when needed. Shared roles describe responsibilities;
  do not invent tool, agent, or model identifiers. Verify the actual model before
  promising an independent cross-model opinion; disclose unavailable independence.
- Use `code-review` closeout for ordinary ship gates, its axes mode for standards
  and spec checks, and `workflows-review` when exhaustive review is requested.
  Verify and repair in-scope blockers; plan review's outside opinion is opt-in.
- For version-sensitive work, match examples to released packages, installed
  types/help, and current official docs. A skill's "latest" label is not evidence.
  For Stripe work, read the [shared compatibility reference](../skills/research/references/stripe-compatibility.md)
  alongside the native skill to correct bundled examples. Keep plugin caches
  unmodified; recheck external contracts for the actual project.

## Engineering

- Choose the simplest implementation that fully meets current requirements.
  Keep useful interfaces and supported harnesses; avoid speculative compatibility
  layers, premature abstractions, and unrelated refactors.
- Strict types: no `any`, unsafe assertions, or non-null assertions unless the
  user accepts the tradeoff. Use a functional core and imperative shell where
  they fit. Prefer clear code over cleverness.
- Python: use `uv` (`uv run`, `uv pip`, `uv venv`).
- React: use `useEffect` only for synchronization with an external system.
  Derived data, events, and prop/state resets usually need no effect.

## Git

- Never push unless the user says to. Commit only within the requested workflow;
  do not switch branches for a discussion or review. Preserve SSH/signing workflows.
- Stage explicit task paths and inspect the staged diff. Run `git status` after
  staging and before committing. No `--no-verify` or force-adding ignored paths.
- Branch: `feat/[ticket]-short-name` when ticketed; otherwise a conventional
  `type/name`. Commit: `type(TICKET-1234): description` or `type: description`.
- PR title: `[ticket]: description` or `[type]: description`. Body: one short
  sentence, then bullets; no "Summary" / "Key Changes" headings or emojis.
- Never comment on an open PR unless explicitly asked to comment on that PR.
  This includes review submissions, inline comments, `gh pr comment`, and API
  comments/reviews. Put findings in the conversation. Use `gh` when available.
- Search recent branches and commits by recency first.

## Communication and shell

- Lead with the outcome in plain, concise language. Use lists for parallel
  information and technical details when they help. Cite evidence; missing proof
  means "not verified". No praise, flattery, or unnecessary explanation.
- No emojis unless asked, except 🏁 after reading all requested context.
- Create Markdown artifacts only when requested or necessary to the deliverable,
  such as repairing a skill's missing reference.
- Prefer `rg` / `rg --files`. Avoid buffered pipes such as `head`, `tail`, or
  `less` for monitoring; use command flags. Set cwd or use absolute paths since
  `cd` may not persist across tool calls.
