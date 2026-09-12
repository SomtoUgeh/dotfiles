---
name: motion-brief
description: "Create a motion brief or interview when explicitly requested to decide or stress-test an animation. Resolve material choices and use labelled defaults; routine implementation uses animate."
metadata:
  short-description: Settle material motion decisions and record a usable brief
---

# Motion Brief

Use this skill for an explicitly requested motion brief or interview. Establish the purpose and material behavior of one animation, then record a usable brief. Routine animation implementation can use `animate` and existing defaults without opening an interview.

Animations get rebuilt three times not because the code was wrong but because nobody decided what the motion was for. This skill front-loads that decision. **It does not write the animation.** The brief is the deliverable for interview-only requests. If implementation is already explicitly authorized, use the agreed decisions and continue without asking for the same approval again.

Follow the [canonical motion policy](../animate/references/canonical-policy.md). Values below are starting points, not universal requirements.

## The three rules

1. **Ask only unresolved, material questions.** Use one question at a time when later choices depend on the answer. Skip questions already answered by the request, code, or agreed defaults.
2. **Look up facts; recommend decisions.** Anything discoverable in the filesystem — the component, its trigger, the animation stack, the existing easing tokens — you find yourself. Asking the user something you could have read wastes the interview's credibility and their patience.
3. **Never ask for a number the user can't feel.** "What duration?" and "which cubic-bezier?" are unanswerable. Ask for the _sensation_ or a _reference product_, then propose the number yourself and let them react to it. People can't author 240ms; they can tell you 240ms feels slow.

Every question ships with **your recommended answer**, so the user can agree in one word and the interview stays cheap.

## Step 1 — Recon

Before the first question, read the code. Establish:

- The component and the **two states** the motion moves between.
- What **triggers** the change — click, hover, keyboard, route change, data arriving, drag.
- The **stack** available: `motion/react` in `package.json`, Tailwind, plain CSS, WAAPI.
- Existing **motion tokens** — custom `cubic-bezier` values, duration variables, `--ease-*` in the theme, and what sibling components already do.
- Whether **`prefers-reduced-motion`** is handled anywhere globally.

Done when you can state all five, or state plainly that one doesn't exist in this codebase. Report the recon in three or four lines, then ask the first material unresolved question, or write the brief when the available context is sufficient.

From here on, every question is grounded in what you found: _"The drawer currently uses `@keyframes` — what should happen if the user swipes it back down mid-open?"_ beats _"should it be interruptible?"_ every time.

## Step 2 — The two questions that can end the interview

Resolve these first from context; ask only where the answer is unclear. Either can support a **cut**, which is a valid outcome.

1. **Frequency.** "How many times a day does one user see this?" For a rapidly repeated action, recommend immediate feedback and cut any motion that delays or disconnects input. Keyboard input or a count alone is not an automatic ban; test the actual flow.
2. **Purpose.** "What does the motion tell the user that the static change doesn't?" Valid answers: feedback, spatial consistency, state indication, explanation, preventing a jarring change, or — for something seen rarely — delight. "It looks cool" on a frequently-seen element is not one.

If the agreed verdict is a cut, record the reasoning. Finish an interview-only request there; continue already authorized implementation with the static state.

## Step 3 — Choreograph the movement

3. **Which properties actually differ** between state A and state B. Identify both states from the interface and ask only if the intended change is unclear; animate only the properties that communicate it.
4. **Where it comes from and where it goes.** Is it anchored to a trigger, or centered? Does the exit mirror the entry? Which direction is "forward"? Motion that enters one way and leaves another breaks the sense of a single coherent space.
5. **What happens mid-flight.** "If they trigger it again — or reverse it — halfway through, what should it do?" This is the one question that decides `@keyframes` vs transitions vs springs, and skipping it is how toasts end up jumping.

## Step 4 — Set the feel

6. **Personality, by reference.** "Name a product whose version of this feels right to you." A reference is worth ten adjectives, and you can go study it frame by frame. Fall back to a two-way choice — crisp and serious, or playful with some bounce — rather than an open question.
7. **Easing and duration together.** These are one decision, not two: a steep curve can afford a longer duration, a weak one can't. Propose both as a pair, in that order — curve first, duration tuned to it.

## Step 5 — The edges

8. **Reduced motion.** "With movement removed, what should survive?" An instant change is valid; retain restrained opacity/color feedback only if it aids comprehension, and drop unnecessary travel. Purely decorative motion goes away entirely.
9. **Scale and load.** What this does with 200 items instead of 3, on a mid-range phone, while data is still loading. Ask only where the recon showed a list, a drag, a filter, or a blur — otherwise it's a question about nothing.

## Step 6 — The brief

The brief is ready when material decisions are resolved and remaining choices have reasonable, labelled defaults. Mark irrelevant fields as not applicable. Respect a request to stop interviewing or use your judgment; a blank template field alone is not a reason to ask another question.

```markdown
## Motion brief — <component>

**Verdict:** animate | cut
**Trigger:** <what starts it>
**Frequency:** <seen how often> → <why that permits motion>
**Purpose:** <one sentence — what the motion communicates>

**Enter:** <properties, from → to>
**Exit:** <properties, from → to, or "mirrors enter">
**Origin:** <transform-origin / direction>
**Easing:** <curve> · **Duration:** <ms>
**Interrupt:** <what happens when re-triggered or reversed>
**Reduced motion:** <what survives>
**Stack:** <CSS transition / @starting-style / spring / layout animation>

**Open risk:** <what we're least sure of, and how we'd check it>
```

For interview-only requests, present the brief and wait for the user's implementation choice. When the user already authorized implementation, continue with the settled brief; ask only about unresolved decisions that materially change the result.

## Defaults you bring to each question

Recommend these unless the interview gives you a reason to depart. Never present a question without one.

| Decision            | Recommend                                                                                                                                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Should it animate   | Prefer immediate feedback for repeated actions; reduce motion that delays input; standard for occasional (modals, drawers, toasts); delight only for rare or first-run                                                              |
| Which properties    | Prefer `transform` and `opacity` when geometry remains correct; verify rendering cost                                                                                                                                                   |
| Entrance            | `scale(0.95)` + `opacity: 0` for ordinary surface entrances; stronger scaling needs an intentional visual purpose and a reduced-motion alternative                                                                                                                                            |
| Press / hover       | `scale(0.97)` on press (felt, not seen); 1–2% on hover, gated behind `(hover: hover) and (pointer: fine)`                                                                                                                |
| Origin              | Trigger-anchored for popovers, dropdowns, menus (`var(--radix-popover-content-transform-origin)`); centered for modals                                                                                                   |
| Easing              | Start with `ease-out` for responsive entrances, `ease-in-out` for movement, `ease` for hover/color, and `linear` for constant speed. Tune named or custom curves to the interaction; an accelerating exit can be appropriate |
| Curve to start from | `cubic-bezier(0.19, 1, 0.22, 1)` reveals · `cubic-bezier(0.32, 0.72, 0, 1)` sheets · `cubic-bezier(0.645, 0.045, 0.355, 1)` on-screen moves                                                                              |
| Duration            | Under 300ms unless the element is large or travels far: press ~150ms, tooltip 125–200ms, dropdown 150–250ms, modal or drawer 200–500ms. Exits shorter than entries                                                       |
| Interrupt           | CSS transitions or springs, which retarget from the current state — keyframe timelines need explicit retargeting/playback control                                                                                                            |
| Spring              | `{ type: "spring", duration: 0.3, bounce: 0 }`. Bounce stays at 0 unless the user asked for personality; smaller elements need more bounce to read the same                                                              |
| Reduced motion      | Instant or restrained opacity/color feedback; reduce spatial and disable decorative motion                                                                                                                                                |
| Stagger             | 30–80ms, varied by importance — uniform stagger kills hierarchy. One entrance per container                                                                                                                              |

## When the user stalls

"Just make it nice" delegates judgment. Choose the default that fits the product, record the assumption, and proceed. Offer a concrete two-way choice only when the user wants to explore alternatives or the choice materially changes the result.

Record defaults as **assumed** so the user can revise them without another interview.

## Companion skills

If installed: `animate` implements the brief, `review-animations` audits what came out, `animation-vocabulary` names an effect the user is describing loosely.
