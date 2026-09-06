# Plan Template

Every requested plan should be executable without the audit conversation. Specify the proposed values and their rationale using the project's conventions and the canonical motion policy.

Rules for filling this in:

- Include exact proposed values or named existing tokens. Avoid references to values that appear only in the conversation.
- Quote the current code. The executor should be able to find the site by matching the excerpt, not by trusting a line number.
- Name an exemplar file in this repo that already does it right, so the executor copies the house style instead of inventing one.
- Bound the scope explicitly. Say what must not be touched.
- End with a feel-check, not just a build check. Code that compiles can still feel wrong.

---

````markdown
# NNN — <short imperative title>

- **Commit:** <git rev-parse --short HEAD>
- **Severity:** HIGH | MEDIUM | LOW
- **Category:** <one of the eight audit categories>
- **Estimated scope:** <n files, ~n lines>

## Problem

<State the observed behavior, affected interaction, and supporting code or
runtime evidence. Explain the consequence and the relevant project convention
or requirement. Identify what remains unverified.>

## Where

| File | Lines | What's there |
| --- | --- | --- |
| `src/components/dropdown.tsx` | 41–48 | Enter transition on the content |

### Current code

```tsx
// Paste the actual current component excerpt here.
```

## Target

<The exact end state. Every value spelled out.>

```css
/* Include the exact target styles or component code, using the installed
   primitive's documented lifecycle. Do not mix Radix variables with Base UI
   attributes or assume an unmounting element will finish a transition. */
```

**Why these values:** <Tie each proposed value to the interaction, project tokens, or observed problem. Defaults from a guide are not sufficient evidence.>

## Conventions to follow

- Easing tokens live in `<file>`. Use `<token>`; add a new one only if none fits, following the naming already there.
- `<path/to/exemplar.tsx>` already does this correctly — match its structure.
- <Anything else the repo does its own way.>

## Steps

1. <One concrete action per step, in order.>
2. <…>
3. <…>

## Out of scope

- <Files or behaviors the executor must not touch.>
- Do not introduce a new animation library.
- Do not change any other component's timing, even if it looks similar.

## Verification

**Build**
- [ ] Type-check and lint pass.
- [ ] <Any test or story that covers this component.>

**Behavior**
- [ ] <Observable check — e.g. the panel scales from the trigger, not the center.>
- [ ] Trigger it rapidly: the motion retargets from its current position instead of restarting.
- [ ] With `prefers-reduced-motion: reduce`, spatial/decorative motion is reduced or removed and state meaning remains clear; an instant change is valid.

**Feel**
- [ ] Observe or record the real interaction; check responsiveness, interruption, and continuity. Report unavailable device or browser checks as not assessed.
- [ ] <For gestures and drawers:> test on a real device, not just the desktop browser.
- [ ] Look at it again with fresh eyes before calling it done.

## Notes

<Anything the audit couldn't judge from code — whether the bounce fits the brand,
whether the crossfade reads as one object. Say so plainly rather than guessing;
these are decisions for a human.>
````
