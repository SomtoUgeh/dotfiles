---
name: code-review
description: >
  Code review in three modes: closeout (ship/commit gate, default), axes
  (Standards + Spec in parallel), or hand-off to exhaustive workflows-review.
  Use when reviewing a branch, PR, uncommitted work, "is this ready",
  autoreview, second-model review, or "review since X". Also covers
  pre-commit structured review contracts from openclaw-style closeout.
---

# Code review

One skill, clear modes. Shared model policy lives in AGENTS.md (**Models →
Review routing**).

| Mode | When | Depth | Primary model |
|------|------|-------|---------------|
| **closeout** (default) | Before commit/ship; "ready?"; autoreview; second opinion | P0/P1 blockers first | fable-5 gate or `codex review` (Sol) |
| **axes** | User wants Standards vs Spec; "review since main"; issue/PRD fidelity | Two parallel reports | fable-5 × 2 axes |
| **full** | Large PR, multi-surface, security-critical, or `/workflows-review` | Multi-agent P1–P3 | Load `workflows-review` skill |

## How this differs from `workflows-review`

They are **different jobs**, not duplicates:

| | `code-review` | `workflows-review` |
|--|---------------|---------------------|
| **Job** | Focused gate or two-axis check | Exhaustive multi-agent audit |
| **Agents** | 0–2 reviewers | Discover and run *all* review agents |
| **Severity** | Closeout defaults to P0/P1 | Always P1/P2/P3 synthesis |
| **Outputs** | Summary + issues (or Standards/Spec) | Todos / prd.json findings / full report |
| **Cost** | Cheap enough to run often | Expensive; use when risk justifies |
| **Pipeline** | Standalone closeout | Part of workflows-* (after plan/work) |

**Rule of thumb:** ship-readiness → **closeout**. "Did we build the right thing
the right way?" → **axes**. "Throw the whole review bench at this PR" → **full**
(`workflows-review`).

## Models (all modes)

| Role | Model | Harness |
|------|-------|---------|
| Primary gate / axes | **fable-5** high | Claude `model` param |
| Independent opinion | **gpt-5.6-sol** high | `codex review` / `codex exec -s read-only` |
| Apply fixes | **grok-4.5** high | `grok -p` (default implementer) |
| Hard fix / Grok miss | **gpt-5.6-sol** | `codex exec` |
| UI polish fixes | fable-5 / opus-4.8 | Claude |

**Never** nest Fable under Fable. **Never** pass Sol/Grok ids as Claude model
strings. Standing permission to escalate if the cheaper path misses the bar.

## Mode selection

Parse the user request (and any args) in order:

1. Explicit `full` / `exhaustive` / `/workflows-review` → **full**
2. Explicit `axes` / `standards` / `spec` / `review since <ref>` → **axes**
3. Explicit `closeout` / `autoreview` / `ready to ship` / `before commit` → **closeout**
4. Empty or "review this" with a dirty tree or open PR → **closeout**
5. Ambiguous large multi-package PR → ask once: closeout, axes, or full

Optional flags (if present in the message):

- `--max-priority P0|P1|P2|P3` — closeout severity ceiling (default P1)
- `--base <ref>` — branch base (default `origin/main` or PR base)
- `--second-opinion` — also run Sol after the primary gate

## Mode: closeout

Load and follow [closeout.md](closeout.md) in full:

1. Freeze scope baseline
2. Collect the right diff (local / branch / PR base)
3. Run Fable and/or Sol gate
4. Verify → accept/reject → fix with implementer → re-test → re-gate
5. Scope governor + two-cycle pause
6. Final report (command, models, proof, clean/rejected)

Prose-only internal docs: skim, skip heavy gate.

## Mode: axes

Load and follow [axes.md](axes.md) in full (Standards + Spec parallel
sub-agents). After both return, present side by side without cross-axis
reranking. Optional Sol second opinion is separate from the two axes.

## Mode: full

Do **not** reimplement the multi-agent fan-out here. Load:

```
skill: workflows-review
```

Pass the same target/args. That skill owns agent discovery, skill slices,
stakeholder/scenario passes, and todo/prd output. It must still obey the
closeout **scope governor** and **one Fable gate** rules (see closeout.md and
AGENTS.md).

## Invocation examples

```text
/code-review                         → closeout on current changes
review before I ship                 → closeout
review since main                    → axes (fixed point = main)
code-review axes                     → axes
code-review full                     → workflows-review
codex review --uncommitted           → Sol-only closeout path
```

Natural language that should hit this skill: "autoreview", "second model
review", "is this ready to merge", "review my branch", "Standards and Spec".

## Final rules

- Reviewer is **read-only** on source until the accept/fix phase; then only
  **accepted in-scope** findings get implementer edits.
- Do not push to create a review target.
- Empty diff → report "nothing to review" and stop.
- After material fixes, re-run the **same** mode until clean or scope stops you.
