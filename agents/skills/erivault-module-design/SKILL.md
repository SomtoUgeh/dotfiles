---
name: erivault-module-design
description: >-
  Design a new product module's full screen set in the Erivault `erivault-web`
  Paper file, reusing the established design system (tokens, shell, components)
  and grounded in the module's ADR + implementation plan. Covers researching
  the existing system, extracting authoritative tokens, planning the
  state×role×platform matrix, building screens via duplicate-and-adapt, and
  tying into existing surfaces. Use when designing a new module or surface
  (tenancies, inspections, renewals, capture, packs...) in Paper, extending the
  erivault-web design file, building all states/roles for a feature on web and
  mobile, or when the user says "design the X module", "design a new flow",
  "design X in the Paper board", "add the screens for X", or "make it
  consistent with our design system".
---

# Erivault module design

Design a new module end to end in the `erivault-web` Paper file so it looks and
behaves like the rest of the product — same shell, tokens, and component
vocabulary — with full coverage of states, roles, web + mobile, and the
connections back into Dashboard and Properties.

**IS:** researching the existing Erivault design system, then designing a new
module's screens in Paper (detail/hub states, setup flow, modals, mobile,
cross-surface tie-ins) using the shipped tokens and components.

**IS NOT:** writing the implementation code (that's a separate build), inventing
a new visual language, or redesigning existing shipped pages. Reuse the system;
do not fork it.

## Core principle

Every screen is assembled from primitives that already exist. Before drawing a
single box, you should be able to point at the token, the component, and the
sibling screen each part comes from. The fastest path to consistency is to
**duplicate a real sibling artboard and adapt it**, not to rebuild from blank.

A module lives *under* its parent in the information architecture (a tenancy
lives under a property), so its shell keeps the parent's nav item active and the
topbar breadcrumbs back to the parent — a new module is rarely a new top-level
nav item.

## Reference files

| File | Read when |
|------|-----------|
| `references/design-system.md` | Default — the authoritative tokens, type law, component vocabulary, status-chip palette, shell values, and register-per-role gradient. Read before extracting or building. |
| `references/paper-workflow.md` | Driving the Paper MCP: load order, the duplicate-and-adapt build loop, cross-page reuse, mobile cloning, and the screenshot/render gotchas. Read before building. |
| `references/module-coverage.md` | Planning what to build: grounding in the ADR, the state×role×platform matrix, the screen-set checklist, and artboard naming. Read during planning. |

## Workflow

Copy this checklist and track progress:

```text
Module design progress:
- [ ] Step 1: Ground in the domain (ADR + implementation plan)
- [ ] Step 2: Research the existing design system + Paper file
- [ ] Step 3: Extract the authoritative shell + tokens
- [ ] Step 4: Plan the coverage matrix; confirm palette/scope with user
- [ ] Step 5: Build the hero screen at full fidelity; review
- [ ] Step 6: Fan out states + roles + mobile via duplicate-and-adapt
- [ ] Step 7: Build modals and the cross-surface tie-ins
- [ ] Step 8: Review every artboard; fit-content; finish working
```

### Step 1: Ground in the domain

Read the module's ADR (`docs/adr/`) and its section of
`docs/product/implementation-plan.md`. Extract the constraints the UI must
honor into a short table: lifecycle states, what creates the record, the role
permission model, and which actions are gated by state. The UI's job is to make
that model legible. Do not invent product rules the ADR doesn't state.

See `references/module-coverage.md` for what to pull out and how it maps to
screens.

### Step 2: Research the existing design system

Confirm the system before reusing it — the written design doc can lag the code.

- Read `docs/design/dashboard-design-system.md` for intent, then **cross-check
  against `packages/ui/css/base.css`** (the real source of truth). Treat
  mismatches as the doc being stale, not the code.
- Map the UI layer (`packages/ui/components`, `apps/web-app/src/features/<sibling>`,
  `apps/web-app/src/server/<sibling>`). Delegate this breadth to a subagent.
- Open the Paper file and study 1–2 sibling modules already designed (Dashboard,
  Properties) for the shell and the patterns you'll reuse.

`references/design-system.md` holds the extracted result so you usually don't
need to re-derive it.

### Step 3: Extract the authoritative shell + tokens

- Load the Paper guide once, then `get_basic_info`.
- `get_jsx` a sibling artboard's **sidebar** to capture the exact shell markup
  (logo SVG, workspace switcher, nav, user row). Cross-page `get_jsx` works.
- Confirm the font with `get_font_family_info` (pass `familyNames` as an array).
- Note the exact token hexes you'll inline (see `references/design-system.md`).

### Step 4: Plan the coverage matrix

Enumerate the full set before building: detail/hub states (empty / partial /
full + each lifecycle state), roles (agency, landlord, tenant, client landlord),
platforms (web + mobile — parity is a constraint), the setup/creation flow, one
modal per high-trust action, and the tie-ins back into the parent detail and the
Dashboard setup chain. Use the checklist in `references/module-coverage.md`.

This is the point to confirm with the user: the lifecycle **status-chip palette**
(a real decision that cascades to every screen) and the build order. Then build.

### Step 5: Build the hero screen

Pick the richest screen (usually the populated detail/hub for the primary staff
role). Duplicate a sibling artboard onto the module's page to inherit the shell,
strip its body, and build the screen at full fidelity. Screenshot-review against
the design checkpoints before treating it as the template. See
`references/paper-workflow.md`.

### Step 6: Fan out via duplicate-and-adapt

Duplicate the hero and adapt — change only what differs (chip, timeline,
actions, role identity) using `set_text_content` + `update_styles` +
`write_html` (replace). For mobile, `x-paper-clone` the web cards into a single
column. The exact loop, including how to use the returned `descendantIdMap`, is
in `references/paper-workflow.md`.

### Step 7: Modals and tie-ins

Build one modal per high-trust action (centered card on a dim scrim for web; a
bottom sheet for mobile). Then build the cross-surface tie-ins: the parent
detail's "on this record" row (no-record → set-up CTA; exists → summary) and the
Dashboard setup-chain step.

### Step 8: Review and finish

Screenshot every artboard. Fix chip wraps (`white-space: nowrap` +
`flex-shrink: 0`), switch each artboard to `height: fit-content` (never guess
pixel heights), then call `finish_working_on_nodes`.

## Gotchas

These are the failure points that cost time; check them first.

- **The design doc lags the code.** `dashboard-design-system.md` has described
  tokens as "not yet a CSS var" that already shipped in `base.css`. Always
  verify token values against `base.css`, not the doc.
- **Paper screenshots only render the foregrounded page.** After `open_page`,
  screenshots of that page's artboards may return empty. Freshly built artboards
  on the active page do render. When a screenshot returns nothing, fall back to
  `get_tree_summary` (text + node names) and `get_jsx` — both work regardless of
  active page.
- **Mobile artboards can render 0×0** in screenshots (auto-layout quirk). Read
  them with `get_tree_summary`/`get_jsx`, or screenshot a child frame.
- **Cross-page `duplicate_nodes` works; `x-paper-clone` does not.** To inherit a
  shell on a new page, `duplicate_nodes` the sibling artboard with
  `parentId: <new page root>`. Clone (`x-paper-clone`) only reuses nodes within
  the same page (great for mobile columns reusing web cards).
- **`duplicate_nodes` returns a `descendantIdMap`** (original→clone). Use it to
  target edits directly; don't re-query the tree.
- **Set `height: fit-content` last**, after all content is in — don't guess
  fixed heights.
- **Chips wrap on narrow rows.** On mobile and in side rails, set chip text
  `white-space: nowrap` and the chip frame `flex-shrink: 0`.
- **Load the Paper guide once per session** (`get_guide paper-mcp-instructions`)
  before other Paper tools; `get_font_family_info` needs `familyNames` as an
  array; call `finish_working_on_nodes` when done.
- **Never introduce a new dark surface, an unlabelled AI element, or a third
  brand accent.** Only two dark surfaces exist (record hero, invitation banner);
  AI is always labelled and never auto-applies.

## Storage location

This is a project skill (`.claude/skills/`) so the whole team gets it and it
ships with the repo. It encodes this repo's Paper file and design system, so it
is intentionally project-specific, not a personal or general skill.
