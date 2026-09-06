---
name: breadboarding
description: Turn a workflow or shaped feature into canonical affordance tables that map places, visible UI, executable code, stores, control flow, and data flow. Use to understand an existing system, design a concrete interaction from shaped parts, translate a whiteboard breadboard, or prepare vertical implementation slices.
---

# Breadboarding

Breadboarding maps what a user can do and how the system produces the result.
The canonical output is the four tables below. Mermaid is optional and must be
derived from the tables; it never overrides them.

Read [references/extended-guide.md](references/extended-guide.md) for whiteboard
translation, subplaces, chunking, Mermaid styling, slicing diagrams, and full
worked examples. The schema and validation rules in this entrypoint are
authoritative.

## Choose the mode

- **Map an existing system:** start from a user or caller workflow, then inspect
  the repository. Every code affordance and wire must have evidence in code.
- **Design from shaped parts:** start from the required outcome and mechanisms.
  Add only affordances needed to make those mechanisms concrete.
- **Mixed:** preserve evidenced existing behavior and label proposed affordances
  in Notes, while showing both in one end-to-end breadboard.

If the flow spans frontend, backend, workers, or third-party systems, use one
breadboard and identify each boundary in Place and Component fields.

## Canonical model

### Places

A Place is a bounded context of interaction: a route, modal, mode, screen, CLI
context, API boundary, or backend execution context. Give places IDs `P1`, `P2`,
and so on. Use `P2.1` for a true subplace. Every affordance belongs to exactly one
Place.

Use the blocking test: if the user must act to enter or leave the context, or the
available controls change as a set, model a Place. Local state within an otherwise
unchanged interaction is usually a store or affordance rather than a Place.

### Affordances and stores

- `U1`, `U2`, ...: visible or interactive UI affordances such as inputs,
  buttons, lists, messages, and rendered values.
- `N1`, `N2`, ...: executable code affordances that a caller can invoke or
  observe, such as handlers, methods, subscriptions, jobs, and API operations.
- `S1`, `S2`, ...: state read or written across steps, such as persisted records,
  observable state, URL state, or component state that enables behavior.

Name an affordance for its direct step-level effect. Do not promote wrappers,
internal transformations, libraries, or mechanisms into affordances unless a
caller can act on or observe them at the workflow level.

### Relationships

- **Place column:** containment. It says where an affordance exists.
- **Wires Out:** calls, triggers, or state writes. `-> N2` calls N2; `-> S1` writes S1.
- **Returns To:** data flow. `-> U3` means the row's output or stored value feeds
  U3.
- Navigation targets a Place (`-> P2`), not an arbitrary affordance inside it.

Do not mix control and data flow in one column. If intermediate details are out
of scope, label the abbreviation rather than inventing nodes.

## Canonical output schema

Always emit the applicable tables in this order. Use an em dash for an empty
cell. Add a Notes column only when evidence, proposal status, a condition, or an
open question must be recorded.

### Places

| # | Place | Contains | Entry / Exit |
| --- | --- | --- | --- |
| P1 | Search page | Search UI and orchestration | Route load / result selection |
| P2 | Result detail | Destination boundary; detail internals omitted | Result selection / return to search |

### UI affordances

| # | Place | Component | Affordance | Control | Wires Out | Returns To |
| --- | --- | --- | --- | --- | --- | --- |
| U1 | P1 | search-form | query input | type | -> N1 | — |
| U2 | P1 | results | result count | render | — | — |
| U3 | P1 | results | result rows | render | — | — |
| U4 | P1 | results | result row | click | -> P2 | — |

### Code affordances

| # | Place | Component | Affordance | Control | Wires Out | Returns To |
| --- | --- | --- | --- | --- | --- | --- |
| N1 | P1 | search-form | `handleQuery()` | call | -> N2 | — |
| N2 | P1 | search-service | `search()` | call | -> S1 | -> N1 |

### Data stores

| # | Place | Store | Description | Wires Out | Returns To |
| --- | --- | --- | --- | --- | --- |
| S1 | P1 | `results` | Current search response | — | -> U2, -> U3 |

This example describes control as `U1 -> N1 -> N2 -> S1` and data as
`N2 -> N1` plus `S1 -> U2, U3`. U4 navigates to P2, which must appear in the
Places table when the destination is in scope.

## Procedure

1. State the workflow from the user's or caller's perspective, including the
   expected final effect.
2. Identify Places and system boundaries.
3. Inventory visible UI affordances in workflow order.
4. Trace the real or intended call path and add code affordances.
5. Add stores only where state persists or feeds later behavior.
6. Fill Wires Out for control and Returns To for data.
7. Trace each user story end to end through the tables.
8. For existing systems, verify names and wires against code and cite file paths
   or symbols in Notes when useful.
9. Add Mermaid only if it makes the verified tables easier to read.
10. Slice only after the breadboard is complete.

When mapping code, search broadly enough to find alternate callers and readers.
Do not follow remembered paths or stop at the first match.

## Validation

Before returning a breadboard, check:

- Every referenced ID exists and each ID is unique.
- Every affordance belongs to exactly one declared Place.
- Every displayed value has an incoming data source.
- Every `N` has Wires Out, Returns To, or an explicit terminal-effect note.
- Every `S` has a writer or source and at least one reader.
- Navigation wires target Places.
- Control flow and data flow remain in their respective columns.
- Each required outcome has a complete trace from trigger to effect.
- Proposed behavior is distinguished from code-backed behavior.
- Optional diagrams contain no node or wire absent from the tables.

If a validation check fails, fix the table or record a concrete open question;
do not hide uncertainty in a diagram.

## Vertical slices

After validation, group affordances into demoable end-to-end slices. Each
affordance belongs to one slice. Prefer a thin working path before enhancements,
and list dependencies on later slices as explicit stubs. A slice table uses:

| Slice | Mechanism | Affordances | Demo |
| --- | --- | --- | --- |
| V1 | Search with real results | U1-U4, N1-N2, S1 | Query returns selectable rows |

Keep slicing separate from the canonical affordance tables so implementation
order does not change the system model.
