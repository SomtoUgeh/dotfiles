---
name: breadboard-reflection
description: Find design smells in a breadboard and fix them. Use after breadboarding to validate affordance boundaries, naming, and wiring correctness.
---

# Breadboard Analysis

Find design smells in a breadboard and fix them. Use the canonical schema and
validation rules in [../breadboarding/SKILL.md](../breadboarding/SKILL.md); the
extended guide is background material, not a competing format.

Correct the requested breadboard within its existing scope. Reflection does not authorize refactoring the implementation: for an existing system, report a code/design mismatch and distinguish a faithful map correction from a proposed implementation change. For a proposed system, validate the intended wiring without claiming it already exists in code.

---

## Finding Smells

### Entry Point: Trace User Stories Through the Wiring

Take a user story from the requirements or frame. Trace it through the breadboard wiring. Ask: does the path tell a coherent story that produces the expected effect?

Example: "User says 'add Tokyo after Detroit' → Tokyo appears after Detroit in the table, and persists across restarts."

Trace: U4 (input) → N1 → N2 (LLM) → N3 (dispatch) → N4 (handle) → ... → S1 (locales updated) → N12 (persist) → S4 (config written).

At each link, ask: does this step logically lead to the next? Does the wiring make sense as a story about how the effect happens?

### What Smells Look Like

| Smell | What you notice |
|-------|-----------------|
| **Incoherent wiring** | A node writes to S1 AND triggers the thing that writes to S1 — redundant or contradictory |
| **Missing path** | The user story requires an effect, but no wiring path produces it |
| **Diagram-only nodes** | Nodes in the diagram that aren't in the affordance tables — decoration, not real affordances |
| **Naming resistance** | You can't name an affordance with one idiomatic verb (see Naming Test below) |
| **Stale affordances** | The breadboard shows something that no longer exists in the code |
| **Wrong causality** | The wiring shows A calls B, but the code shows C calls B |
| **Implementation mismatch** | The code has logic paths, functions, or call chains that aren't represented in the breadboard |

The first three are visible from the breadboard and requirements alone. The last four require comparing to the implementation — read the actual code and check each affordance: does it exist? Does the wiring match what the code actually calls and returns? Is anything missing?

---

## Fixing Smells

### The Naming Test

The primary tool for finding and fixing affordance boundary problems.

For each affordance:

1. **Who is the caller?** Identify the user of this affordance.
2. **What is the step-level effect?** What does THIS affordance do — not the downstream chain, just its own direct effect?
3. **Name it with one verb.** Describe the step-level effect with a single, idiomatic English verb.

| Signal | Meaning |
|--------|---------|
| One verb covers all code paths | Boundary is correct |
| Need "or" to connect two verbs | Likely two affordances bundled together |
| Name doesn't feel idiomatic | Investigate naming and responsibility; wording alone does not prove a bad boundary |
| Name matches a downstream effect, not this step | You're naming the chain, not the step |

#### Step-Level vs Chain-Level Effects

Name what THIS step does, not the downstream cascade.

An orchestrator may validly be named `add_locale` when that is its public contract. If the breadboard separately exposes internal dispatch, validation, and insertion steps, name those rows for their own effects; do not rename a coherent public operation merely because it delegates.

**Step-level** (right): The orchestrator's own effect is handling/dispatching → `handle_place_locale`. The adding happens downstream.

How to check:
1. List everything the affordance calls downstream
2. Remove all of that — what's left?
3. Name what's left

If what's left is just sequencing and branching, it's a handler. Name it as such.

#### Caller-Perspective Naming

Names should reflect what the affordance affords from the caller's perspective — the effect the caller achieves by using it.

| Perspective | Question | Example |
|-------------|----------|---------|
| **Caller** | "What can I achieve by calling this?" | N3 calls N4 → "handle place_locale tool call" |
| **Step** | "What does this function do, not its callees?" | N4 itself → "dispatch to validate, resolve, insert" |
| **Effect** | "What changes in the system after this runs?" | N15 → "locale is extracted from its position" |

#### External Tools vs Internal Handlers

A tool exposed to an external caller (like an LLM) should be named for the effect the caller wants: `place_locale` — the caller wants to place a locale.

The internal handler that processes that tool call should be named for its own role: `handle_place_locale` — it handles the dispatch, delegating work to sub-steps.

#### Example: Naming Resistance as a Signal

A function `resolve_locale` either pops an existing locale from a list OR creates a new dict:

- "Take" fits the pop path but "take into existence" isn't idiomatic English
- "Create" fits the new path but not the pop
- Need "or" → split into two affordances: `extract_locale` (pop) and `create_locale` (new)

The inability to find one idiomatic verb was the signal that this was two distinct operations forced into one function.

### Splitting Affordances

When the naming test reveals a bundled affordance:

1. **Determine the authorized mode.** For an existing-system map, preserve actual code boundaries and report a proposed split separately. For design work, label distinct planned operations as proposed. Change code only if implementation was requested and the split improves the actual contract.
2. **Then update the tables.** Add rows for new affordances with proper IDs, Wires Out, and Returns To.
3. **Then update the diagram.** The diagram renders the tables.

Never invent unlabelled implementation in the diagram. Existing affordances need code evidence; proposed affordances need explicit proposal status and table rows.

### Fixing Wiring

When the causality is wrong (A → B in the breadboard but C → B in the code):

1. Read the code to understand the actual call chain.
2. Update the table first — move the wire to the correct source.
3. Update the diagram to match.
4. Re-trace the user story to confirm the wiring now tells a coherent story.

---

## Verification

After any changes:

1. **Re-trace user stories.** Does the wiring now tell a coherent story for each requirement?
2. **Describe the wiring in prose.** Trace every claim against the tables and diagram. If the prose says "N4 calls N13" but the diagram doesn't show that wire, something was missed.
3. **Check wiring consistency:**
   - Every Wires Out target must exist in the tables
   - Function return edges match a caller; store reads and subscription outputs have the appropriate reader/event source and need not be synchronous function calls
   - Solid lines for writes/calls (Wires Out), dashed for returns/reads (Returns To)
   - Every node in the diagram has a row in the affordance tables
