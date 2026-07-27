# Standards + Spec axes

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards** — does the code conform to this repo's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / PRD / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's
context, then the skill aggregates findings. Do **not** merge or rerank across
axes.

The issue tracker should have been provided — run `/setup-matt-pocock-skills`
if `docs/agents/issue-tracker.md` is missing.

## Models

| Role | Model | Effort |
|------|-------|--------|
| Orchestrator | fable-5 or sonnet-5 | high / med |
| Standards sub-agent | **fable-5** | high |
| Spec sub-agent | **fable-5** | high |

Two parallel Fable axes max. No nested Fable under either axis. Optional Sol
second opinion after the report via `codex review`.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — commit SHA, branch, tag, `main`,
`HEAD~5`, etc. If they didn't specify one, ask.

Capture once:

```bash
git rev-parse <fixed-point>
git diff <fixed-point>...HEAD
git log <fixed-point>..HEAD --oneline
```

Fail here on bad ref or empty diff — not inside sub-agents.

### 2. Identify the spec source

In order:

1. Issue references in commits (`#123`, `Closes #45`, etc.) — fetch via
   `docs/agents/issue-tracker.md`.
2. Path the user passed as an argument.
3. PRD/spec under `docs/`, `specs/`, or `.scratch/` matching branch/feature.
4. If nothing found, ask. If they say there is no spec, Spec axis reports
   "no spec available" and may be skipped.

### 3. Identify the standards sources

Repo docs such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`, plus the **smell
baseline** below. Rules:

- **Repo overrides** the baseline when they conflict.
- Baseline smells are always judgement calls, never hard violations.
- Skip anything tooling already enforces.

Smell baseline (_Refactoring_, ch.3) — *what it is* → *how to fix*:

- **Mysterious Name** — name doesn't reveal role → rename; if no honest name, design is murky.
- **Duplicated Code** — same logic shape in more than one hunk → extract shared shape.
- **Feature Envy** — method reaches into another object's data more than its own → move it.
- **Data Clumps** — same few fields travel together → bundle into a type.
- **Primitive Obsession** — primitive standing in for a domain concept → small type.
- **Repeated Switches** — same switch/if cascade on the same type → polymorphism or shared map.
- **Shotgun Surgery** — one logical change scatters across many files → gather into one module.
- **Divergent Change** — one module edited for unrelated reasons → split by reason.
- **Speculative Generality** — abstraction for needs the spec doesn't have → delete/inline.
- **Message Chains** — long `a.b().c().d()` → hide behind one method on the first object.
- **Middle Man** — mostly delegates → cut and call the real target.
- **Refused Bequest** — subclass ignores most of what it inherits → composition instead.

### 4. Spawn both sub-agents in parallel

Use `general-purpose` twice. When supported, set **`model: fable-5`**, high
effort. Instruction: findings only; do not spawn children.

**Standards brief:** Report per file/hunk (a) documented standard violations
(cite file + rule) and (b) baseline smells (name + quoted hunk). Distinguish
hard vs judgement. Under 400 words.

**Spec brief:** Report (a) missing/partial requirements, (b) scope creep, (c)
wrong-looking implementations. Quote the spec line. Under 400 words.

Paste the full smell baseline into the Standards prompt — the sub-agent has no
other access to it.

### 5. Aggregate

Present under `## Standards` and `## Spec` headings, verbatim or lightly
cleaned. One-line summary: counts per axis and worst issue **within** each axis
— never a single winner across axes.

## Why two axes

- Standards pass + Spec fail → pretty code that does the wrong thing.
- Spec pass + Standards fail → right behavior, wrong conventions.

Separation stops one axis from masking the other.
