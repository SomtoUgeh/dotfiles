---
name: shaping
description: Collaboratively define a problem, compare materially different solution shapes, and select a solution before implementation planning. Use when requirements or approach are genuinely unsettled.
---

# Shaping

Shaping negotiates what to build. It keeps requirements separate from mechanisms, compares real alternatives, and leaves the user in control of scope and tradeoffs.

Do not force a shaping ceremony onto a clear specification. If the request already defines the behavior and constraints, proceed to planning or implementation as requested.

## Core notation

- **R0, R1, ...** are requirements: outcomes, constraints, or business rules.
- **A, B, C, ...** are mutually exclusive solution shapes.
- **A1, A2, ...** are parts that combine within a shape.
- **A2-A, A2-B, ...** are alternatives for one part.
- **CURRENT** describes the existing system when a baseline helps.
- **Detail A** expands a selected shape; it is not a new alternative.

Requirements state what must be true. Shape parts state the concrete mechanism that makes it true. If a part merely repeats a requirement, it is not yet a mechanism.

Keep at most nine top-level requirements. Group related detail under sub-requirements such as R3.1 when needed.

## Frame the problem

The user may begin with a problem or with a proposed solution. Start with the information already available, including focused repository research when the shape depends on existing code or conventions.

Keep the frame short:

- **Source** preserves the user's or stakeholder's wording only when they ask for a durable source record.
- **Problem** states the pain or failure without assuming a solution.
- **Outcome** states what success looks like at a stakeholder level.

Do not copy secrets or sensitive messages into an artifact. Ask only questions whose answers change scope, behavior, or the selected mechanism; combine independent questions when the runtime supports it.

## Requirements

Capture confirmed requirements, reasonable assumptions, and material open questions separately. Requirements must be testable and must not hide implementation choices. Add a type such as functional, business rule, or non-functional only when it improves clarity. Useful statuses include Core goal, Must-have, Nice-to-have, Undecided, and Out.

Before comparing shapes, check for vague outcomes, missing permissions or ownership rules, failure cases, contradictions, and absent acceptance criteria. Resolve blocking questions before selecting a shape; carry non-blocking assumptions explicitly.

If a shaping document already names a selected shape, first show the selected shape's fit against requirements and the unresolved failures or unknowns. Do not replay discarded options unless the user asks.

## Shapes

Propose alternatives only when they are materially different. Two shapes that differ only in naming or minor implementation detail should be one shape with a part-level choice.

Each shape has a short descriptive title and a parts table:

| Part | Mechanism | Flag |
| --- | --- | :---: |
| A1 | Concrete component, data flow, or behavior change | |
| A2 | High-level idea whose implementation is not understood yet | ⚠️ |

Use `⚠️` only for a real unknown in the mechanism. Resolve it through focused repository research, authoritative documentation, a prototype, or a spike before claiming that the shape satisfies affected requirements.

Prefer vertical parts that combine user-visible behavior with the data and handlers they need. Extract shared mechanisms once and reference them from dependent parts.

Use a small data-flow or wiring diagram when it exposes relationships that the parts table does not. Do not require a diagram for a shape that the table already explains.

## Fit check

Compare requirements and shapes in one table. Every shape cell is binary:

| Req | Requirement | Status | A | B |
| --- | --- | --- | :---: | :---: |
| R0 | Full requirement text | Core goal | ✅ | ✅ |
| R1 | Full requirement text | Must-have | ❌ | ✅ |

Rules:

- Use only `✅` or `❌` in shape columns.
- A flagged mechanism is `❌` until the mechanism is understood.
- Put short explanations below the table, not in shape cells.
- Show full requirement text.
- If every shape passes but still feels wrong, identify the missing requirement and rerun the check.

Use a macro fit check only when the user explicitly wants an early high-level comparison. In that view, `Addressed?` may use ✅/⚠️/❌ and `Answered?` remains ✅/❌.

## Breadboarding and slicing

Once a shape is selected, use the available `breadboarding` skill when concrete UI and code affordances or wiring are needed. The affordance tables are the source of truth; diagrams render those tables.

Slice a breadboard into vertical increments only when implementation planning is requested. Each slice should demonstrate observable behavior. Pure data, backend, migration, or operational work can still be a valid slice when the requested outcome has no UI; state the observable verification instead of inventing a screen.

## Spikes

A spike answers a focused mechanics question, such as where logic lives or whether an API supports the proposed mechanism. Investigate before proposing. A spike's acceptance condition describes the knowledge gained, not the eventual product decision.

Create a separate spike document only when the user requested a durable artifact or the explicitly requested planning workflow needs one. Otherwise report the answer in the active conversation or existing shaping document.

## Documents and consistency

Do not create a document merely because shaping was requested. When the user authorizes a durable shaping artifact, keep these levels consistent:

1. Shaping document: requirements, shapes, parts, fit check, selected shape.
2. Slices document: slice definitions and breadboards.
3. Slice plans: implementation detail.

A change at one level must update affected summaries above and details below. Add `shaping: true` frontmatter to shaping artifacts used by repository hooks.

Capture source material verbatim only when the user asks for a frame or durable source record. Avoid copying secrets or sensitive messages into project documents.

When re-rendering a table during an interactive shaping session, mark changed rows clearly if that helps the user compare revisions. Do not let presentation markers become persisted data unless the project expects them.

## Completion

Shaping is complete when:

- the problem and outcome are clear;
- confirmed requirements and assumptions are distinguishable;
- the selected shape passes the fit check;
- remaining unknowns are explicit and assigned a way to resolve them; and
- the user has selected the shape or explicitly delegated that decision.

Do not start implementation merely because shaping completed. Continue into planning or implementation only when the user's request includes it.
