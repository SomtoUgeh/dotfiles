---
name: pick-ui-library
description: "Choose a UI primitive or animation library, or assess build-versus-dependency tradeoffs. Use when library selection is unresolved; preserve suitable existing dependencies."
metadata:
  short-description: Pick the animation or UI library the animations.dev course trusts
---

# Picking a Library

**Know your tools.** Don't blindly jump into code — look around first and see what already exists. Most of the time you shouldn't invent a new pattern; the existing one is battle-tested and proven to work.

This course-derived shortlist is a starting point, not a current maintenance or compatibility guarantee. Check the project lockfile, supported React/browser versions, and current primary documentation before recommending a dependency. Follow the [canonical motion policy](../animate/references/canonical-policy.md).

## Before recommending anything

1. **Read `package.json` first.** If something already installed covers the task, use it. Proposing a second animation library or a second primitives library is a finding, not a recommendation.
2. **Match the task, not the name the user said.** "Add a toast" is a toast recommendation even if they mentioned Framer Motion.
3. **Recommend one thing.** Offer alternatives only when asked.
4. **Say when you're off the list.** If the course doesn't cover the task, state that plainly before naming anything outside it.

## What should this animation be written with?

| The animation | Use | Why |
| --- | --- | --- |
| User-triggered state change — hover, click, open/close | **CSS transitions** | Interruptible: hover and unhover mid-flight and it retargets smoothly |
| Re-triggered rapidly — toasts stacking, toggles, accordions, drawers | **CSS transitions** or a **spring** | `@keyframes` restart from zero; that's the Sonner bug where a second toast jumps to its new position |
| Infinite loop — marquee, spinner, orbit, coin flip | **CSS `@keyframes`** + `animation-iteration-count: infinite` | Nothing else needed; `linear` is the right curve here |
| Runs automatically once — page intro, text reveal, staggered entrance | **CSS `@keyframes`** (+ `animation-fill-mode: backwards`/`forwards`) | Delay via `calc(var(--delay) * var(--stagger))`; no JS |
| A few discrete steps — blink, pulse | **CSS `@keyframes`** | Past a handful of steps it gets unwieldy — reach for Motion |
| Simple enter/exit that won't be interrupted — dialog, popup | **CSS keyframes** or **`@starting-style`** | `@starting-style` gives an enter transition with no `mounted` state and no `useEffect` |
| Must stay smooth while the main thread is busy | **CSS** or **WAAPI** | Eligible effects can run on the compositor; verify the property, browser, and recording. Motion also has a hybrid engine |
| Programmatic, but you want it hardware-accelerated and colocated with the JS logic | **WAAPI** | What the course uses for the `clip-path` scroll reveal, to keep all animation logic in one place |
| Real springs, momentum, interruptions that keep velocity | **Motion for React** | Real springs are impossible in CSS — `linear()` is only an approximation |
| Animating a component **out** after React removes it | **Motion for React** — `AnimatePresence` | The element is gone from the DOM; CSS has nothing left to animate |
| Morphing one element into another — shared element, tab indicator, App Store card, trash interaction | **Motion for React** — `layout` / `layoutId` | Animates what CSS can't, including `flex-direction` and layout position |
| Drag, drag-to-dismiss, momentum | **Motion for React** — `drag` | Momentum comes free; `dragMomentum={false}` to turn it off |
| Scroll-triggered reveal, when Motion **isn't** already installed | **Intersection Observer API** | Don't pull in a heavy library just to know when something enters the viewport |
| Theme toggle wipe | **View Transitions API** | The course's own `clip-path` version duplicates the whole page — hacky; the API does it properly |

Rule of thumb: **CSS for simple and hardware-accelerated motion, Motion for complex and sophisticated motion.** Combining both in one project is normal and is what the course does.

**Your users don't care whether you used CSS.** They care about what they see. If beautiful requires a library, use the library — bundle size is usually not the thing that ruins the experience, and property choice alone does not guarantee a frame rate; measure the actual interaction.

### Motion for React (formerly Framer Motion)

Import from `motion/react` — the current package is `motion`; check the [upgrade guide](https://motion.dev/docs/react-upgrade-guide) because major versions can change behavior beyond the import path. Not using React? Vanilla **Motion** is the alternative; with React, stay on Motion for React, it's tailored to the framework.

- **For:** springs, layout and shared-layout animations, complex motion in very little code, an API that fits React.
- **Against:** bundle size, and a lot of magic — when something doesn't work it's hard to see why, and the docs follow the happy path.

Prefer the declarative API (`initial`/`animate`/`exit`). Imperative `useAnimate` is more powerful but harder to write and maintain — the course almost never uses it.

### React Spring

Spring-based and highly configurable (compare actual bundled imports before claiming a size advantage), and pairs well with the rest of the Poimandres set (`use-gesture` for a macOS-dock-style interaction). Against it: steep learning curve, more code for the same animation, and documentation that's hard to parse. Recommend it when spring control matters more than developer speed.

### GSAP

Framework-agnostic with an excellent timeline feature, a large community, and arguably the easiest to learn. It powers a lot of award-site work. Against it: **no spring animations**, and it isn't tailored to React (there is a `useGSAP` hook). Now fully free after the Webflow acquisition. Recommend it for timeline-heavy marketing work, not for product UI that needs springs.

Anime.js and Popmotion exist; the course doesn't use them, so don't recommend them as if it did.

## Don't build these yourself

Making a dropdown accessible is genuinely hard, and so is a select, a toast, or a navigation menu — keyboard navigation, focus management and ARIA all have to be right. Unstyled primitives do the boring work and leave the styling entirely to you.

| Task | Use |
| --- | --- |
| Dropdown menu, navigation menu, dialog, tooltip, tabs, select, popover | **Radix Primitives** (or **Base UI**) |
| Toast / notifications | **Sonner** |
| Drawer / bottom sheet with an iOS feel | **Vaul** |

Radix is the course's default: mature, battle-tested, used by shadcn and by many respected teams — it's the base of Vercel's design system and of Linear's navigation — and it makes animation easy — origin-aware `transform-origin` variables, `data-state` for exit animations, and `data-motion` for direction-aware navigation-menu transitions.

**Base UI** is another primitive library, with different component composition, state attributes, and lifecycle contracts. It uses `render` where Radix uses `asChild`; migration needs component-specific behavior, focus, and animation tests. Its tooltip exposes `data-instant`. **React Aria** is another option when it matches the project. See [Base UI useRender](https://base-ui.com/react/utils/use-render).

Check current releases, open compatibility issues, accessibility behavior, and project support requirements. Do not assert maintenance status from course-era notes or assume patching/forking is free.

## Utilities the course reaches for

| Need | Use |
| --- | --- |
| Measure dynamic intrinsic height when CSS cannot cover the required browsers/transition | `react-use-measure` |
| Dismiss on outside click | `useOnClickOutside` from `usehooks-ts` |
| Conditional class names | `clsx` |
| Hover gating, hit-area utilities, arbitrary transforms | Tailwind — v4 gates `hover:` with `(hover: hover)`; add `(pointer: fine)` separately when required |

From the guest lesson: **torph** for morphing characters inside a changing string, and **DialKit** for tweaking animation parameters live in any web app.

## Deciding on a dependency at all

- **Weigh what it saves.** Someone already spent weeks on that navigation menu; you will not beat its quality in an afternoon.
- **Bundle size is a real trade-off, not a veto.** Vaul deliberately shipped without a spring library — a smaller package was worth more than a perfectly native feel, and that cost it the small bounce iOS has on snap points. Make the trade explicitly.
- **Don't chase the shiny thing.** Stitches was the hot new thing, got adopted, then stopped being maintained. Ask what problem it solves for *you*, not who is excited about it this month.

## Intercept these

Flag and redirect when you see:

- A hand-rolled toast, drawer, dropdown, select or tooltip with manual focus and keyboard handling.
- Motion pulled in for a plain hover effect or a simple fade — CSS is enough.
- A second animation library added alongside one that's already installed.
- `@keyframes` used for anything that can be re-triggered while it's still playing.
- A heavy library imported only to detect that an element scrolled into view.

For the rules that govern *how* the chosen tool should be used — easing, duration, origin, interruptibility — use the `animate` skill.
