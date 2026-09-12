---
name: animate
description: "Decide whether and how a web interaction should animate: purpose, timing, physicality, interruption, and spatial continuity. Coordinate motion direction across a component or flow."
metadata:
  short-description: Design and build web animations that feel right (animations.dev course)
---

# Building Animations

The complete builder's guide to motion that feels right, distilled from Emil Kowalski's *Animations on the Web* course ([animations.dev](https://animations.dev/)). Use it to make decisions first, then implement.

Follow [references/canonical-policy.md](references/canonical-policy.md) for the
shared accessibility, performance, tool-choice, and verification rules. It wins
if a stronger statement in this guide conflicts with it.

## Start from the request

Use the requested component, interaction, and product context immediately. Ask
one concise question only when no animation target or goal can be inferred.

## Core Philosophy

An animation feels right when it satisfies three things at once:

1. **It feels natural.** It mirrors the physics of the real world. Nothing around us moves at a constant speed or appears out of nowhere — so `linear` easing feels lifeless and `scale(0)` entrances feel wrong.
2. **It has a purpose.** You can answer "why does this animate?" in one sentence, and neither you nor the user is surprised or annoyed by it.
3. **It's made with taste.** Taste is trained, not innate — the ability to tell good motion from bad and justify why. In a world where everyone's software works, taste is the differentiator.

Two consequences run through everything below:

- **Unseen details compound.** Most motion details users never consciously notice — that's the point. The aggregate of invisible correctness is what makes an interface feel expensive.
- **If everything animates, nothing stands out.** Motion is a spice, not the meal. Pace it through the experience; the more you add, the less each one is worth.

## Load These When Implementing

This file is the decision layer. When you move to code, load the companion reference for the exact recipe:

- **[references/css-techniques.md](references/css-techniques.md)** — transitions vs keyframes, transforms, `clip-path`, `@starting-style`, stagger, hover patterns, 3D.
- **[references/framer-motion.md](references/framer-motion.md)** — `motion/react`: `initial`/`animate`/`exit`, spring configs, `AnimatePresence` modes, `layout`/`layoutId`, motion values and hooks, animating height, and component recipes.
- **[references/svg-animation.md](references/svg-animation.md)** — `viewBox`, line drawing (`stroke-dashoffset`), `transform-box` and transform origins, path morphing, shakes, and ambient motion.
- **[references/interaction-patterns.md](references/interaction-patterns.md)** — implementation examples for sequential tooltips, stable hover targets, trigger-relative popovers, and diagnosing one-pixel shifts.

Use `css-animations` for dedicated CSS implementation guidance and
`motion-react` for Motion for React implementation guidance. The references
above preserve focused examples that help apply this skill's motion direction.

Err on the side of loading a reference rather than approximating a value.

## The Animation Decision Framework

Answer these in order **before** writing animation code.

### 1. Should this animate at all?

Match motion to how often the user sees it:

| Frequency | Decision |
| --- | --- |
| 100+/day (keyboard shortcuts, command-palette toggle, arrow-key list nav) | Prefer an immediate state change; omit motion that delays feedback |
| Tens/day (hover effects, list navigation) | Remove or drastically reduce |
| Occasional (modals, drawers, toasts) | Standard animation |
| Rare / first-time (onboarding, feedback, celebrations) | Can add delight |

Avoid delayed spatial motion on rapidly repeated keyboard actions. Preserve an
immediate focus or selection change, and add motion only when it communicates a
state transition without making input feel disconnected. A high-frequency
selection highlight should track the current item instead of trailing it.

### 2. What's the purpose?

Every animation needs one of: **explanation** (marketing/onboarding), **feedback/responsiveness** (a button that reacts to a press), **spatial consistency** (an element enters and exits the same way), **state indication**, **preventing a jarring change** (a toast that eases in instead of popping), or — rarely — **delight** (reserved for interactions seen seldom, so it stays a pleasant surprise). "It looks cool" on a frequently-seen element is not a purpose.

### 3. Then pick the ingredients

Easing → duration → physicality → (spring?) → interruptibility → performance → accessibility. The rest of this file is those ingredients.

## Easing

Easing is the single most important part of an animation — it can make a bad animation look great or a great one feel wrong.

| Situation | Curve |
| --- | --- |
| Entering or exiting the screen | **`ease-out`** (fast start, gentle settle — feels responsive) |
| Moving / morphing while already on screen | **`ease-in-out`** (car accelerating then braking) |
| Hover / color / background / opacity | **`ease`** (asymmetric, elegant for small changes; CSS default) |
| Constant motion (marquee, spinner, timer, hold-to-delete) | **`linear`** |
| Default | **`ease-out`** |

Avoid `ease-in` when the user is waiting for the first visible response because
its slow start can feel delayed. Use it only when that acceleration supports the
specific transition and survives testing in context.

Built-in named curves are useful baselines. When they feel flat in context, try
a stronger custom curve before changing duration. Asymmetric curves with a fast
start and slow settle often suit responsive entrances.

Use the custom-curve examples in [css-animations](../css-animations/SKILL.md) when warranted; preserve existing product tokens first. For adaptive drawer height, `cubic-bezier(0.25, 1, 0.5, 1)` is another starting point.

**Pair entering and exiting elements to the same direction and curve family** so the interaction reads as one coherent space.

## Duration

Keep UI animations **under ~300ms** unless justified. A 180ms dropdown feels more responsive than a 400ms one. Faster spinners make loads *feel* faster.

| Element | Duration |
| --- | --- |
| Button press | ~150ms |
| Tooltips, small popovers | 125–200ms |
| Dropdowns, selects | 150–250ms |
| Modals, drawers | 200–500ms |
| Small floating drawer | ~270ms |
| Wide menu resize | ~250ms |
| Big element crossing the screen | up to ~1s |

**Duration and easing are inseparable.** A steep curve can afford a longer duration (Vaul's 500ms doesn't feel slow because the curve front-loads the movement); a weak curve must be shorter. **Choose the easing first, then tune duration to it.** Duration scales with **element size and travel distance** (a bigger element is heavier). **Exits are shorter and simpler than entries** — the user already decided; get out of the way. Too fast is as bad as too slow. Marketing pages can run longer; product must feel fast.

For transitions whose size varies (an auto-height drawer), make duration **proportional to how much changed** so small changes don't over-animate — see the adaptive-duration recipe in [references/framer-motion.md](references/framer-motion.md).

## Physicality

- **Never animate from `scale(0)`.** Start entrances from `scale(0.9–0.95)` + `opacity: 0`. Nothing appears from nothing; a near-full start reads as "it was always almost there." Bigger floating elements start closer to 1 (a nav menu uses `scale(0.98)`).
- **Button press:** `transform: scale(0.97)` on `:active`, `transition: transform ~150ms`. Press feedback is *felt, not seen* — `scale(0.9)` visibly collapses. Buttons feel best with **both** hover and press feedback; hover with nothing on click feels dead.
- **Hover scale:** 1–2% is plenty (`scale(1.02)`). `hover:scale-105` inflates like a balloon. Hover duration 100–150ms.
- **Origin-aware popovers.** Scale from the **trigger**, not the center (the CSS default `transform-origin: center` is wrong for almost every triggered element). Use the library's variable:
  ```css
  .popover { transform-origin: var(--radix-popover-content-transform-origin); } /* Radix */
  .popover { transform-origin: var(--transform-origin); }                       /* Base UI */
  .menu    { transform-origin: top center; }                                    /* trigger above */
  ```
  **Modals are exempt** — they appear centered, keep `transform-origin: center`.
- **Never put a hover lift on the hover target itself.** Animating `translateY` on the hovered element moves it out from under the cursor → hover ends → it drops → flicker loop. Move the lift to an inner child; the parent stays under the cursor.

## Springs

Springs model velocity and settling through mass, stiffness, and damping; some
libraries also expose duration-and-bounce controls. Reach for them for drag with
momentum, interruptible gestures, and cursor-following. Simple color or opacity
changes rarely need a spring. CSS can approximate a sampled spring with
`linear()`, while a runtime spring can react continuously to changed input.

For duration-and-bounce or physics configurations, use [references/framer-motion.md](references/framer-motion.md) and the installed Motion version.

- **Default bounce to 0.** No overshoot keeps UI natural and elegant. Add bounce only intentionally — a slight bounce at the *end of a drag* (a drag applies force); a press-to-close gets none. Bounce is personality: more = playful, zero = serious.
- **Bounce scales inversely with element size** — smaller elements need *more* bounce to read the same amount.
- **Springs are interruptible** — redirected mid-motion, they carry velocity, so gestures the user reverses stay smooth. This is why the Sonner toast bug (new toast jumping) was a keyframe/interruptibility problem.
- **"Weird" spring motion is usually fixed by increasing `damping`.**

## Interruptibility

Anything triggered rapidly (toasts, toggles, drawers, accordions, drags) must animate **from its current state**, not restart. CSS **transitions** and **springs** are interruptible; `@keyframes` restart from zero and make new items jump. Prefer transitions/springs for dynamic UI, and `@keyframes` only for autonomous, looping, or one-shot motion. Use `@starting-style` to animate an enter without JS — see [references/css-techniques.md](references/css-techniques.md).

## Performance

Prefer `transform` and `opacity`; they usually avoid layout and paint. Layout
properties such as `width`, `height`, `margin`, and positional offsets are more
expensive candidates, but their real cost depends on the page. CSS and WAAPI can
move eligible work away from JavaScript's main-thread workload, but browser
promotion is not guaranteed. Profile the actual interaction before changing
library syntax or adding `will-change`, containment, or forced layers.

Inherited CSS variables can expand style-recalculation work across descendants,
and large animated blurs can be costly. Treat both as profiling leads rather
than universal diagnoses.

For the full frame-budget model (the Layout/Paint/Composite pipeline, main-thread vs GPU, React re-renders, and a diagnosis checklist for dropped frames), use the `animation-performance` skill.

## Stagger, hierarchy & orchestration

Stagger group entrances 30–80ms apart — longer feels slow, and stagger is decorative so it must never block interaction. **Vary the delay and distance by visual importance**: the most important element appears first with the most screen time; the least important can just fade in without sliding. **Uniform stagger** (identical delay/distance/easing per item) kills hierarchy and feels artificial.

**One entrance per container.** Don't slide a panel in *and* trickle its children in — slide it in with content already there. Sometimes the best animation is no animation.

## Cohesion & spatial consistency

- All of a component's sub-animations should share a timing feel so it reads as a **single entity** (the Family Drawer overrides Vaul's 500ms to 200ms so opening and height changes feel unified).
- **Exit direction matches entry direction**; navigation maps **forward = left, back = right**. A zoomed view expands from its thumbnail (object permanence) — it doesn't fade in from nowhere.
- Match motion to the component's **personality** — playful can be bouncier; a dashboard stays crisp (Sonner uses `ease`, slightly slower, to feel elegant).
- Prefer a **crossfade with a subtle directional hint** (8px shift + opacity + light blur) over a heavy full slide for small, structurally-similar content.
- When a crossfade shows two overlapping states despite tuning, add a subtle **`filter: blur(2px)`** during the transition to blend them into one perceived transformation.

## Accessibility

Under reduced motion, remove or reduce spatial movement, zooming, parallax, and
decorative loops. Preserve meaning with an instant change or a restrained
non-spatial transition such as opacity or color when that helps comprehension.

Use the `animation-accessibility` recipes for reduced-motion variants and touch-safe hover gating.

In Motion for React, `useReducedMotion()` can branch values, and
`<MotionConfig reducedMotion="user">` disables transform and layout animation
while preserving effects such as opacity and background-color changes. Confirm
target sizing and touch behavior against the product's accessibility
requirements rather than relying on hover as an interaction step.

For the two-variant workflow and the recipes for autoplaying media, looping animation, and smooth scrolling, use the `animation-accessibility` skill.

## Process

Great animations take iteration.

- **Record and scrub** the reference (and your own work) frame by frame; tune magic transform values live in the console.
- When the schedule permits, take a fresh-eye pass after a break; do not pause
  authorized work or delay delivery solely to wait for another day.
- **Test gestures on real devices** (hit the dev server by IP; opacity-heavy motion wants high-refresh screens).
- Steal like an artist: recreate great animations by studying proven products rather than inventing patterns.

## Review Format (when asked to review)

Follow the user's requested review format. When no format is specified, use a
compact Markdown table so each issue keeps the current behavior, proposed
change, and reason together.

| Before | After | Why |
| --- | --- | --- |
| `transform: scale(0)` | `transform: scale(0.95); opacity: 0` | Nothing appears from nothing |
| `ease-in` on dropdown | strong `ease-out` custom curve | `ease-in` delays the moment the user watches most |
| `hover:scale-105` | `hover:scale-[1.02]`, gated behind `(hover: hover)` | 5% inflates; 1–2% is enough, and touch shouldn't trigger it |
| `transform-origin: center` on popover | `var(--radix-popover-content-transform-origin)` | Popovers scale from their trigger (modals stay centered) |

For a dedicated, exhaustive reviewer with a strict block/approve verdict, use the `review-animations` skill. To name an effect, use `animation-vocabulary`.
