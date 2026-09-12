---
name: code-review
description: "Review a PR, branch, uncommitted change, or work since a revision. Use closeout for ship/commit gates, axes for standards versus spec, and workflows-review for exhaustive review."
---

# Code review

One skill, clear modes. Model and orchestration policy lives in the shared
`AGENTS.md`; runtime capability names live in `../RUNTIME_TOOLS.md`.

| Mode | When | Depth | Primary model |
|------|------|-------|---------------|
| **closeout** (default) | Before commit/ship; "ready?"; autoreview; second opinion | P0/P1 blockers first | One reviewer selected by shared policy |
| **axes** | User wants Standards vs Spec; "review since main"; issue/PRD fidelity | Two independent reports | Runtime-native agents; distinct model only when requested and available |
| **full** | Large PR, multi-surface, security-critical, or `/workflows-review` | Multi-agent P1–P3 | Load `workflows-review` skill |

## How this differs from `workflows-review`

They are **different jobs**, not duplicates:

| | `code-review` | `workflows-review` |
|--|---------------|---------------------|
| **Job** | Focused gate or two-axis check | Exhaustive multi-agent audit |
| **Agents** | 0–2 reviewers | Bounded relevant specialist checks |
| **Severity** | Closeout defaults to P0/P1 | Always P1/P2/P3 synthesis |
| **Outputs** | Summary + issues (or Standards/Spec) | Full report; tracking files only when requested |
| **Cost** | Cheap enough to run often | Expensive; use when risk justifies |
| **Pipeline** | Standalone closeout | Part of workflows-* (after plan/work) |

**Rule of thumb:** ship-readiness → **closeout**. "Did we build the right thing
the right way?" → **axes**. "Throw the whole review bench at this PR" → **full**
(`workflows-review`).

## Models (all modes)

Follow the model roles and one lead reviewer in shared `AGENTS.md`. Use the active
runtime's native reviewer by default. Select a different model only when the user
requests a second opinion or shared policy calls for one **and** that model is
available through its proper harness. Never describe a review as independent or
model-specific unless that model was selected explicitly and the command proves
it.

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
- `--second-opinion` — also run an available independent reviewer after the primary gate

## Mode: closeout

Load and follow [closeout.md](closeout.md) in full:

1. Freeze scope baseline
2. Collect the right diff (local / branch / PR base)
3. Run the reviewer selected by shared policy
4. Verify → accept/reject → fix with implementer → re-test → re-gate
5. Scope governor + two-cycle pause
6. Final report (command, models, proof, clean/rejected)

Prose-only internal docs: skim, skip heavy gate.

## Mode: axes

Load and follow [axes.md](axes.md) in full. Standards and Spec may run as
independent runtime-native subagents when available. After both return, present
them side by side without cross-axis reranking.

## Mode: full

Do **not** reimplement the multi-agent fan-out here. Load:

```
skill: workflows-review
```

Pass the same target/args. That skill owns agent discovery, skill slices,
stakeholder/scenario passes, and todo/prd output. It must still obey the
closeout **scope governor** and **one lead reviewer** rules (see closeout.md and
AGENTS.md).

## Invocation examples

```text
/code-review                         → closeout on current changes
review before I ship                 → closeout
review since main                    → axes (fixed point = main)
code-review axes                     → axes
code-review full                     → workflows-review
codex review --uncommitted           → Codex closeout using configured model
```

Natural language that should hit this skill: "autoreview", "second model
review", "is this ready to merge", "review my branch", "Standards and Spec".

## Final rules

- A review-only request stays read-only. When fixes are also authorized, only
  verified in-scope findings get implementer edits.
- Do not push to create a review target.
- Empty diff → report "nothing to review" and stop.
- After material fixes, re-run the **same** mode until clean or scope stops you.
