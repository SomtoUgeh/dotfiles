# Framer Motion / Motion for React

Recipes for Motion for React, imported from `motion/react` in the current
package. Load from [SKILL.md](../SKILL.md) when building JS-driven or
interruptible motion. Check the installed version and the official upgrade
guide before migrating older `framer-motion` code.

## When to reach for it (vs CSS)

Prefer CSS when you can get the same result in reasonable time (hover, simple enter/exit via Radix `[data-state]`, marquees). Reach for Framer Motion when CSS genuinely can't do it:

- real **spring physics** and interruptible, momentum gestures
- **layout** changes and properties CSS can't animate (`flex-direction`, `justify-content`)
- **shared-element / morph** transitions (`layoutId`)
- animating **out unmounted** components (`AnimatePresence`)

Its main cost is bundle size — a real consideration on size-sensitive pages (Vercel avoided it in Next.js docs; a project already using it reaches for it freely).

## Basics

```jsx
import { motion, AnimatePresence } from "motion/react";

<motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} />
```

Motion uses a hybrid engine: work may run through browser animation APIs or
JavaScript depending on the property, animation type, and installed version.
Motion values can update styles outside React's render cycle, which avoids that
render cost but does not guarantee a frame rate. Profile the actual interaction.
Transition defaults also vary by value type and version; set them explicitly
when the behavior matters.

## Transition & spring configs

```jsx
transition={{ duration: 0.3, ease: "easeOut" }}                 // tween
transition={{ type: "spring", duration: 0.3, bounce: 0 }}      // UI text/state swaps (no overshoot)
transition={{ type: "spring", duration: 0.5, bounce: 0.2 }}    // slight, lively overshoot
transition={{ type: "spring", stiffness: 100, damping: 10, mass: 0.75 }} // physics form
```

Set a default for a whole subtree with `MotionConfig`:

```jsx
<MotionConfig transition={{ type: "spring", duration: 0.5, bounce: 0 }}> … </MotionConfig>
```

For these product UI recipes, choose `bounce: 0` unless overshoot is intentional
for a drag release or playful interaction. This is a design default for the
skill, not Motion's library default; check the installed version's documentation
before relying on an omitted value. Smaller elements may need more bounce for
the same perceptual effect. Excess oscillation can often be reduced by raising
`damping`.

## AnimatePresence (exit animations)

```jsx
<AnimatePresence mode="popLayout" initial={false} custom={direction}>
  <motion.span
    key={state}                         // REQUIRED — no key, no exit
    custom={direction}                  // pass again so the exiting element isn't stale
    initial={{ opacity: 0, y: -25 }}
    animate={{ opacity: 1, y: 0 }}
    exit={{ opacity: 0, y: 25 }}
    transition={{ type: "spring", duration: 0.3, bounce: 0 }}
  />
</AnimatePresence>
```

- **A `key` is required** or the component never unmounts and the exit won't fire. If an exit isn't playing, check the key first.
- **`mode="wait"`** — old element fully out before the new one enters (icon swaps, rich state morphs). **`mode="popLayout"`** — exit and enter at once, siblings reflow (crossfades, chip/list removal). **`initial={false}`** skips the mount animation for state swaps.
- **Pass `custom` to both** `AnimatePresence` and the `motion` element — an exiting element's props are otherwise stale, which breaks direction-aware slides.

### Variants (incl. direction-aware)

```jsx
const variants = {
  initial: (direction) => ({ x: `${110 * direction}%`, opacity: 0 }),
  active:  { x: "0%", opacity: 1 },
  exit:    (direction) => ({ x: `${-110 * direction}%`, opacity: 0 }),
};
// <motion.div variants={variants} initial="initial" animate="active" exit="exit" custom={direction} />
```

## Layout & shared-element

- Add **`layout`** to animate any layout/position/size change automatically (even `flex-direction`). Add `layout` to sibling elements that would otherwise jump.
- Give two elements the same **`layoutId`** to morph one into the other across mount/unmount — tab indicators, App-Store card→detail, button→popover, the trash "throw." You can't steer *how* it moves; to add extra motion, animate the **parent** so children follow (`<motion.div animate={{ y: 73 }} transition={{ delay: 0.13 }}>`).
- Layout animation can distort `border-radius` and `box-shadow` because it uses
  transforms. Motion can correct those properties when they are provided
  through `style`, `animate`, or another animation prop. Add `layout` to direct
  children when they also need scale correction.

## Animating height (auto)

Framer Motion can't animate `auto` → `auto`. Measure the content and animate to it:

```jsx
import useMeasure from "react-use-measure";
const [ref, bounds] = useMeasure();

<motion.div animate={{ height: bounds.height || "auto" }}>  {/* auto on 1st render, avoids shift */}
  <div ref={ref} className="p-6">{content}</div>  {/* ref on an INNER element that carries the padding */}
</motion.div>
```

Do **not** put the `ref` and `animate={{ height }}` on the same element — the outer div would freeze at its animated height and stop reacting. `useMeasure` uses `ResizeObserver` under the hood.

## Motion values & hooks

Motion values can update styles outside React's render cycle, avoiding React
render work for high-frequency updates such as pointer movement. They do not
guarantee a target frame rate; measure the interaction under representative
load.

```jsx
const x = useMotionValue(0);            // <motion.div style={{ x }} />; .set()/.get()
const sx = useSpring(x, { damping: 18 }); // springs toward new values (feels alive)
const scale = useTransform(y, [0, 300], [1, 1.5]);       // map input→output range
const label = useTransform(angle, v => `${Math.round(v)}°`); // function form
const clip = useMotionTemplate`inset(0 ${clipValue}% 0 0)`;  // tagged template — needed for reactive strings
```

- **`useSpring`** for most interactions (a raw `useMotionValue` feels lifeless). **`useMotionValue`** when the value must track a gesture 1:1 (drag-to-dismiss scale).
- Prefer declarative props; use imperative `useAnimate()` (`[scope, animate]`) only to orchestrate many elements across events — target `[data-animate]` selectors, use a `times: [0, 0.4]` array to map keyframes to fractions of the duration, and return `Promise.all(...)` so callers can await. Stop an in-flight animation before restarting to avoid conflicts.

## Gestures

```jsx
<motion.div drag dragConstraints={boxRef} dragMomentum={false} whileTap={{ scale: 0.95 }} />
```

`drag` makes an element draggable (keeps momentum by default — `dragMomentum={false}` to disable); `dragConstraints` bounds it. For a real drawer with momentum, overlay-opacity-tracks-drag, focus trapping, and escape-to-close, use **Vaul** rather than hand-rolling. Prefer **controlled** components (own `open` via `useState` + `open`/`onOpenChange`).

## Accessibility

`useReducedMotion()` branches values (`const closedX = reduce ? 0 : "-100%"`); provide an opacity-only variant set and gate `layout`/`height` (`layout={!reduce}`). App-wide: `<MotionConfig reducedMotion="user">` disables transform/layout animations but preserves other animated values. Provide a persistent accessible input label; placeholders are supplementary. Mark fake placeholder visuals `aria-hidden`.

## Component recipes

### Auto-height drawer + crossfade content (Family Drawer)

Outer `motion.div` animates `height: bounds.height`; swap views inside `AnimatePresence mode="popLayout"` so the old content exits while the new enters:

```jsx
<AnimatePresence initial={false} mode="popLayout" custom={view}>
  <motion.div key={view}
    initial={{ opacity: 0, scale: 0.96 }}
    animate={{ opacity: 1, scale: 1 }}
    exit={{ opacity: 0, scale: 0.96 }}
    transition={{ duration }} />
</AnimatePresence>
```

**Height easing** `[0.25, 1, 0.5, 1]` (strong ease-out), duration ~`0.27s`. **Cohesion:** override library defaults so opening and height changes share timing (Vaul overridden from 500ms to 200ms — the drawer should feel like one entity).

**Adaptive opacity duration** — proportional to how much the height changed, so short→short doesn't over-fade:

```js
const MIN = 0.15, MAX = 0.27;
const delta = Math.abs(bounds.height - previousHeightRef.current);
const duration = Math.min(Math.max(delta / 500, MIN), MAX); // recompute in useMemo on [bounds.height]
```

### Morph a button into a popover (feedback popover)

Give the button and popover the same `layoutId="wrapper"`, and the label `layoutId="title"`. Provide `borderRadius` through a Motion animation or `style` prop so scale correction can apply. The gray "placeholder" is a separate `aria-hidden` span, not the textarea's real placeholder — an illusion made with `layoutId`.

### Shared-element / App Store card → detail

Give each corresponding pair a matching `layoutId` (`layoutId={`image-${game.title}`}`, plus title, description, button). Separate `AnimatePresence` blocks for the overlay (fast exit `transition:{duration:0.05}`) and the card.

### Dynamic Island morph (advanced)

Springs **with bounce**, hardcoded per transition because smaller views need more bounce (`idle: 0.5`, `timer-ring: 0.35`, `timer-idle: 0.3`). Animate `layout` between **fixed** width/height values for full control; inline pixel `borderRadius` to avoid distortion; `mode="wait"` to morph one rich state to another; slight `blur()` on enter/exit; `tabular-nums` for changing digits. For simultaneous exit-scale that differs by direction, pass per-transition `scale`/`y`/`bounce` via the `custom` prop. Hardcoding a finite set of transitions is fine — "a Dynamic Island on the web has a finite number of states."

### Trash "throw" (shared layout + parent motion)

Grid images share `layoutId`s with stacked images in the bin; since you can't steer shared-layout motion, animate the **parent** so children drop in (`animate={{ y: 73 }}`, delayed). Fade unselected items out fast: `exit={{ opacity: 0, filter: "blur(4px)", transition: { duration: 0.05 } }}`. Blur-in/out (`filter: blur(4px)` ↔ `blur(0px)`) throughout for a soft feel.

### Nav menu (Radix, CSS-driven)

Animate the Radix viewport size with its CSS vars and a transition; use **`ease`** (not `ease-out`) for a large, frequently-triggered menu so it's calm, not aggressive; scale from `0.98` (never 0); direction-aware content via Radix `[data-motion]`. See [css-techniques.md](css-techniques.md) for the `[data-state]` exit pattern.
