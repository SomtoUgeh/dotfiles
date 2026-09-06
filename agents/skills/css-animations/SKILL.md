---
name: css-animations
description: Implement web motion with CSS transitions, keyframes, transforms, 3D, `clip-path`, and `@starting-style`. Use when writing or fixing CSS-only entrances, exits, hover and press feedback, autonomous loops, multi-step sequences, staggers, or touch-safe hover states. Use `animate` for overall direction and focused skills for performance diagnosis or reduced-motion design.
metadata:
  short-description: Animate with CSS the way the animations.dev course teaches
---

# CSS Animations

The CSS Animations module of Emil Kowalski's *Animations on the Web* course ([animations.dev](https://animations.dev/)), as a working reference. The animation driver here is CSS; recipes can use JavaScript or React for state and lifecycle.

Follow [../animate/references/canonical-policy.md](../animate/references/canonical-policy.md)
for the shared motion policy. It wins if this guide conflicts with it.

For the worked patterns (hover reveals, toast stacks, text reveals, orbits, clip-path effects), load **[RECIPES.md](RECIPES.md)**.

## Is CSS the right tool?

**Reach for CSS when:**

- A simple hover effect.
- Animating an element in or out.
- An infinite, linear animation — marquee, spinner.
- The project is bundle-size sensitive.

**Reach for Motion / another library when:**

- The animation is complex.
- You want it to feel more sophisticated than CSS can manage.
- It must be **interruptible** and feel natural — real spring physics.

CSS transitions can retarget state changes smoothly. Runtime springs add velocity-aware gesture behavior, while CSS `linear()` can approximate a fixed spring curve. Choose by the actual interaction and existing stack; no driver guarantees polish or frame rate.

CSS can let the browser sample eligible animation without per-frame JavaScript,
which helps during main-thread contention. Compositor promotion and GPU use are
browser decisions, so confirm important performance claims with a recording.

## Transition or keyframes — who drives it?

The whole choice reduces to one question: **is the user driving this change, or is the page?**

| Use a **transition** when | Use **`@keyframes`** when |
| --- | --- |
| User interaction triggers it (hover, click, state change) | It runs automatically (page intro) |
| It can be interrupted or retargeted mid-flight (Sonner) | It loops forever (marquee, spinner) |
| | It needs multiple steps (pulse, blink) |
| | It's a simple enter/exit that never gets interrupted (dialog, popup) |

**Transitions retarget computed values; keyframes follow a defined timeline.** Keyframe animations can be paused, reversed, or controlled through WAAPI; reapplying a different animation can jump to its starting keyframe. Prefer transitions or springs for frequent retargeting unless the implementation explicitly preserves continuity.

## Transitions

`transition` is shorthand for `property duration timing-function delay`:

```css
.box {
  transition: transform 0.2s ease;
}
```

Rules from the course:

- **Put the transition on the base state, not only on `:hover`.** On `:hover` alone, the return to default is instant.
- **Never use `all`.** Be explicit so an unrelated property change can't sneak into the animation. For several properties sharing one timing:
  ```css
  /* More repetition */
  .button {
    transition:
      color 0.2s ease,
      background-color 0.2s ease,
      border-color 0.2s ease;
  }

  /* Less repetition, more consistency */
  .button {
    transition: 0.2s ease;
    transition-property: color, background-color, border-color;
  }
  ```
- **Write `ease` out explicitly.** It's the default, but many people assume the default is `linear` — spell it so readers know it was a decision.
- **Declare `transition-delay` on its own line.** `transition: transform 0.2s ease 1s` is hard to read; `transition-delay: 1s` isn't.
- **Transitions can do enter animations too**, and they're the right choice when the end state can change mid-flight (a toast shifting position because another one arrived). See the toast recipe.

## Keyframes

```css
@keyframes fade-in {
  from { opacity: 0; }
  to   { opacity: 1; }
}

.element {
  animation: fade-in 1s ease;
}
```

Use the `animation` shorthand for the first three values only (name, duration, timing-function) and declare the rest separately — it reads better.

- **Omit `0%`/`100%` and CSS uses the element's existing values there.** `@keyframes blink { 50% { visibility: hidden; } }` is a complete blink.
- **`animation-fill-mode: forwards`** keeps the end state; without it the element snaps back when the animation finishes. Needed only when the underlying styles do not already describe the final state; keeping the final state in normal CSS also works.
- **`animation-fill-mode: backwards`** applies the *first* keyframe before the animation starts — the fix for a delayed enter animation flashing its natural state first. `both` does both.
- **`animation-iteration-count: infinite`** for loops. Counts between 1 and infinite are rarely worth it.
- **`animation-direction: alternate`** plays back and forth instead of teleporting to the start.
- **`animation-play-state: paused`** pauses an animation — the one thing transitions can't do.
- **Re-trigger an animation in React by changing the element's `key`**, which forces a remount.
- **Many steps usually means the wrong tool.** Complex multi-step choreography is easier and better in Motion; keyframes are for the simple cases.

## Transforms

`transform` changes how an element looks without touching document flow — siblings lay out as if it never moved. Same as `clip-path` in that respect.

**Translate.** Positive moves down/right, negative up/left. Prefer `translateX`/`translateY` over `translate(x, y)` for readability. **Percentages are relative to the element's own size** — `translateY(100%)` moves it down by exactly its own height whatever that is. Sonner and Vaul animate exclusively with percentage `translateY` for this reason: a toast or drawer of any height hides itself perfectly, where a hardcoded `300px` only works at one size. **Prefer percentages even when the dimensions are fixed** — they're less error-prone.

**Scale.** A multiplier: `scale(2)` doubles, `scale(0.5)` halves. Unlike `width`/`height`, **scaling scales the children too** — font size, icons, and `border-radius` all come along, which is exactly what you want for a button press or a zoom.

- Press feedback: `scale(0.97)` on `:active`.
- **Almost never animate from `scale(0)`.** Nothing in the real world disappears and reappears like that. Start around `0.5`–`0.97` combined with an opacity animation.
- `scaleX`/`scaleY` alone usually looks bad.

**Rotate.** Used less often. **Pure rotation with no other transform looks best with `ease-in-out`** — it accelerates and decelerates like a car. Constant rotation (loaders, coins) uses `linear`.

**Order matters.** `rotate` then `translateX` lands somewhere different from `translateX` then `rotate`.

**`transform-origin`** is the anchor every transform runs from — the center by default. **All popovers, dropdowns, and tooltips should animate from their trigger, not from their own center**, so they don't appear out of nowhere. Radix exposes this as a CSS variable.

**Inline elements can't be transformed.** A non-replaced inline `<span>` is not a transformable box; give it `display: inline-block` before animating it.

### 3D

```css
.parent {
  transform-style: preserve-3d;  /* children live in real 3D space, not flattened */
  perspective: 500px;            /* distance from viewer — creates depth perception */
}
.child {
  transform: rotateY(20deg) translateZ(74px);
  backface-visibility: hidden;   /* hide the reverse side, e.g. for a coin */
}
```

- Think of `rotateY` and `rotateX` as screws. Screw one in from the top and turn it — that's `rotateY`, a revolving door. `rotateX` is the same idea sideways: a rotisserie chicken.
- `translateZ` moves along the z-axis, positive toward the viewer. Perspective produces size/depth cues; translateZ can still affect 3D placement and occlusion without it. The closer the viewer, the more dramatic small changes look.
- Without `preserve-3d` there is no depth, so a child can never pass behind its sibling.

## clip-path

`clip-path` defines a clipping region: content inside is visible, content outside
is hidden. Like `transform` it does not change document layout, which often makes
it a useful reveal tool. Its paint and compositor behavior varies by shape and
browser, so profile complex or large effects.

Shapes include `circle()`, `ellipse()`, `polygon()`, and `url()` for an SVG path, but **`inset()` does nearly all the animation work**. Its four values are offsets from the top, right, bottom, and left, exactly like `margin`:

- `inset(0)` — fully visible.
- `inset(100%)` — fully hidden.
- `inset(0 50% 0 0)` — right half hidden.

Once you can hide half of an element on any axis and animate the boundary, you have comparison sliders, text masks, image reveals, seamless tab highlights, theme-switch wipes, and hold-to-delete. All of them are in [RECIPES.md](RECIPES.md).

## Hover belongs to pointers

Tapping an interactive element on a touch device triggers its hover state — accidental and annoying. Gate hover effects:

```css
@media (hover: hover) and (pointer: fine) {
  .card:hover { background: blue; }
}
```

Tailwind v4 gates `hover:` with `(hover: hover)` only; add `(pointer: fine)` separately if the effect needs it. In v3, set `future.hoverOnlyWhenSupported` in the config.

And when hover reveals *information* rather than decoration, pair it with **`:focus-visible`** so keyboard users get it too. (`:focus-visible` fires for keyboard focus; `:focus` also fires on click.)

```css
.card:hover .card-description,
.card:focus-visible .card-description { transform: translateY(0); }
```

## Easing blueprint

Built-in easings are rarely strong enough for anything deliberate. These are the course's curves:

```css
--ease-out-expo:     cubic-bezier(0.19, 1, 0.22, 1);      /* strong ease-out: reveals, card hovers */
--ease-out-quad:     cubic-bezier(0.25, 0.46, 0.45, 0.94);/* button press */
--ease-in-out-cubic: cubic-bezier(0.645, 0.045, 0.355, 1);/* on-screen back-and-forth */
--ease-in-out-circ:  cubic-bezier(0.785, 0.135, 0.15, 0.86);
--ease-vaul:         cubic-bezier(0.32, 0.72, 0, 1);      /* iOS sheet — extremely steep start */
```

**Duration and easing are inseparable.** A steep curve buys you a longer duration: `500ms` with `ease-out-expo` doesn't read as slow, because almost all the distance is covered in the first fraction. The same `500ms` on `ease` would feel sluggish. Default hovers sit at `150–200ms` with `ease`.

## Reverse engineering

If a CSS animation impresses you, open dev tools — everything is right there: properties, durations, curves. (With JS-driven motion you'll still see which properties move and how the element is styled.) Be selective about what you copy from; curate a small list of sites worth studying. Emil's: [Vercel](https://vercel.com/home) and [Geist](https://vercel.com/geist/introduction), [Linear](https://linear.app/homepage), [Aave](https://aave.com/) and their docs.
