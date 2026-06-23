# Module coverage and grounding

What to build for a new module, and how to derive it from the domain so the UI
makes the real model legible. Covers everything before the brush touches the
canvas.

## Contents
- [Ground in the domain first](#ground-in-the-domain-first)
- [The coverage matrix](#the-coverage-matrix)
- [Screen-set checklist](#screen-set-checklist)
- [Roles and their verbs](#roles-and-their-verbs)
- [State definitions](#state-definitions)
- [Artboard naming](#artboard-naming)
- [Confirm before building](#confirm-before-building)

## Ground in the domain first

Read the module's ADR (`docs/adr/`) and its phase in
`docs/product/implementation-plan.md`. Pull out the facts the UI must honor —
don't invent product rules. Capture them as a short table, e.g.:

| Domain fact | UI consequence |
|-------------|----------------|
| Lifecycle is date-derived (`scheduled\|active\|ended\|cancelled`) | Status chip + timeline read from dates; no manual status toggle |
| Record is a shell first (created from parent + dates; people added later) | "Exists" ≠ "fully set up"; empty/partial states are first-class |
| Permissions differ by role and by lifecycle | Actions are gated; cancelled = staff-history-only; ended = read + late docs |
| Owned vs linked data (e.g. tenancy docs vs property EPC) | Show owned data inline; show linked data as read-only context |

This table is the spec for which states, chips, and gated actions you design.

## The coverage matrix

For a module, design the cross-product (skip cells the domain rules out):

- **Hub/detail states** × **roles** × **platforms (web + mobile)**
- **Setup/creation flow** (the stepper) for the staff role(s)
- **Modals** — one per high-trust action
- **Tie-ins** — parent-detail entry row + Dashboard setup step

Don't railroad every cell at full fidelity — build all *distinct* screens, and
derive near-identical role/state variants by duplicate-and-adapt. Landlord is
usually agency at smaller scale.

## Screen-set checklist

Copy and adapt per module:

```text
<Module> screens:
Detail / hub (primary staff role, web):
- [ ] Full / populated (the hero template)
- [ ] Each lifecycle state (e.g. scheduled, ended, cancelled)
- [ ] Empty / partial (record exists, sub-data not added — first-run affordances)
Setup / creation flow (web):
- [ ] One artboard per step, stepper advancing (done / active / locked)
Modals:
- [ ] One per high-trust action (create-adjacent, destructive, invite, upload)
Role variants (web):
- [ ] Each non-staff role (read-only, role nav, limited verbs)
- [ ] Self-managing landlord if it differs from agency
Mobile:
- [ ] Detail/hub, setup, and modals-as-sheets (parity is a constraint)
Tie-ins:
- [ ] Parent detail "on this record" row (no-record → set up; exists → summary)
- [ ] Dashboard setup-chain step
```

## Roles and their verbs

| Role | Verbs | Shell |
|------|-------|-------|
| Agency (staff) | full create/edit/end/cancel/invite/link/upload | agency nav |
| Landlord (staff) | same as agency, no client-landlord party | agency-style nav |
| Tenant | view, download, report/sign — read-mostly | tenant nav, "Your agent" |
| Client landlord | view, download, request — read-only | client nav, "Managing agent" |

Strip staff affordances (edit/end/cancel/invite/link) for non-staff roles;
replace the actions rail with role-appropriate quiet actions.

## State definitions

- **Full / populated** — the hero; everything present. Build this first.
- **Partial / awaiting setup** — record exists but sub-data (people, documents)
  empty; show dashed first-run affordances and zeroed counts.
- **Lifecycle states** — driven by the domain (date-derived where applicable);
  each gets its chip color, a state-specific timeline, and a gated action set.
- **Terminal/void states** (e.g. cancelled) — strip mutating affordances, add a
  status/history note and a banner explaining the state.

## Artboard naming

`Role: Module Screen — State`, e.g.:
- `Agency: Tenancy Detail — Active (Populated)`
- `Tenant: Tenancy Detail — Active (Read-only)`
- `Agency: Tenancy Setup — Step 2 Parties`
- `Agency: Modal — End tenancy`
- `Agency: Tenancy Detail — Mobile (Active)`

Consistent names make the board scannable and make duplicate-and-adapt obvious.

## Confirm before building

Two things are genuinely the user's call and cascade widely — confirm them after
planning, before fanning out:

1. The **lifecycle status-chip palette** (which token each state gets).
2. The **build order / scope** (which roles and platforms this pass covers).

Everything else (layout, copy, component choice) follows from the design system
and the domain table — make those calls and proceed.
