# Animation Standards Reference

Use these checks with the [canonical motion policy](../animate/references/canonical-policy.md). Course values are design starting points, not universal limits or evidence that another curve, duration, library, or input method is wrong.

## Purpose and frequency

Identify the animation's purpose: feedback, continuity, state change, hierarchy, explanation, or occasional delight. Frequent actions should respond immediately and remain usable while motion runs. A keyboard trigger or estimated daily count is a reason to test responsiveness, not an automatic blocker.

## Easing and duration

Start from project tokens. Useful baseline families:

| Situation | Starting point |
| --- | --- |
| Responsive entrance/exit | ease-out |
| Movement between visible states | ease-in-out |
| Small color/opacity feedback | ease |
| Constant progress or rotation | linear |

Named curves are valid. Custom curves can improve a particular interaction:

```css
:root {
  --ease-out-expo: cubic-bezier(0.19, 1, 0.22, 1);
  --ease-out-quad: cubic-bezier(0.25, 0.46, 0.45, 0.94);
  --ease-in-out-cubic: cubic-bezier(0.645, 0.045, 0.355, 1);
  --ease-sheet: cubic-bezier(0.32, 0.72, 0, 1);
}
```

Small feedback often starts near 100–200ms, dropdowns near 150–250ms, and larger overlays near 200–500ms. Judge the actual distance, frequency, curve, workload, and interruption behavior. A longer duration or ease-in is a finding only when its consequence conflicts with the intended interaction. Do not sum animation duration into purported lost productivity.

## Physicality and origin

Check trigger-relative overlays against the positioning library's computed origin, including collision flips. Centered modals can remain centered. Small press scales near 0.97 or hover scales near 1.02 are optional. Color-only and instant feedback are valid. Preserve visible focus and stable hit areas; animate a child when moving the hover target would cause flicker.

## Interruption, springs, and presence

Reverse and retrigger the interaction while it is running. Check that it starts from the current visible state without a jump or unwanted input delay.

- CSS transitions retarget computed values. Keyframes follow defined timelines; they can be paused/reversed through playback controls but do not automatically retarget like transitions.
- Runtime springs can preserve velocity; use direct values for motion that must track the pointer one-to-one. Damping reduces oscillation, but excessive damping can slow settling.
- `@starting-style` can define first-render transitions. It does not retain an element after React unmounts it.
- Radix and Base UI have different attributes and exit lifecycles. Check the installed primitive rather than sharing selectors between them.
- In `AnimatePresence`, use stable unique keys for multiple or swapped children. Keep the presence boundary mounted. A single conditional child can exit without an explicit key; absence of a key alone is not proof of failure.
- `mode="wait"` handles one child at a time. `popLayout` overlaps exit/entry and removes the exiting item from flow; custom immediate children must expose the relevant DOM ref. Keep the containing block positioned when the popped item needs it.
- Presence-level `custom` delivers updated exit data; motion-child `custom` supplies its own variant data. Check both when using direction-dependent variants.

Use the [Motion presence documentation](https://motion.dev/docs/react-animate-presence) and the project's installed types.

## Layout, SVG, and values

Motion layout animation measures geometry and uses transforms; inline non-replaced elements need a transformable display box. Provide border radius and shadow through a supported style/animation prop when scale correction is needed. Check child distortion, scroll containers, and fixed-position roots. See [Motion layout](https://motion.dev/docs/react-layout-animations).

For dynamic intrinsic height, measure an inner element and animate the outer one. Use `bounds.height || "auto"` for the initial unmeasured state, not scalar `null`, which current Motion types reject. If empty content must collapse to zero, distinguish "not measured" from a measured zero. Under reduced motion explicitly restore intrinsic height so a previously applied pixel height cannot remain frozen.

Motion values avoid per-frame React updates, but no hook guarantees a frame rate. `useMotionTemplate` creates reactive strings; ordinary template strings do not subscribe to value updates. `useAnimate()` returns `[scope, animate]`.

For SVG:

- Close only contours intended to be closed; `Z` adds a return segment.
- `pathLength="100"` normalizes numeric stroke lengths; percentages refer to viewport geometry, not path length.
- Define matching dash/offset units for line drawing. Keep the final state in base styles or use the appropriate fill mode.
- Zero-length strokes can paint with round/square caps.
- Set `transform-box` and `transform-origin` for the intended pivot. Do not assume Motion always overwrites an explicit style origin.
- Path morphs require compatible structures or an appropriate interpolator.

See [Motion SVG](https://motion.dev/docs/react-svg-animation) and the [SVG recipe](../animate/references/svg-animation.md).

## Performance

Prefer transform and opacity when they preserve the required layout. Profile dimension, filter, clipping, shadow, and CSS-variable changes in the actual browser. Neither a property name nor an animation library proves compositor execution, GPU use, or dropped frames.

Use `animation-performance` for trace-based diagnosis. Record workload, viewport, browser/library version, refresh rate, and device. At 60Hz a frame is about 16.7ms; at 120Hz it is about 8.3ms. There is no universal safe blur radius. `will-change`, containment, and forced transforms require before/after evidence and can consume memory or alter rendering.

## Stagger and continuity

Delays around 30–80ms can help an occasional group entrance, but total delay matters. Keep content and controls available immediately. Uniform stagger, parent/child choreography, and asymmetric timing are choices to assess in context, not automatic defects.

Use direction consistent with navigation, writing direction, and the product's spatial model. Do not force left-to-right assumptions onto RTL interfaces. Inspect overlapping crossfades before adding blur to conceal them.

## Accessibility

Test both motion preferences and live preference changes. Remove or reduce spatial/decorative movement; an instant state change is valid. MotionConfig with `reducedMotion="user"` disables transform/layout animation while retaining other animated values. Explicit dimensions, SVG effects, and autoplay still need component checks.

- Preserve keyboard/touch access independently of hover. Gate decoration by pointer capability, not core content or action access.
- Hidden content must not remain focusable merely because opacity is zero.
- Keep one semantic control when duplicating visual layers; decorative copies must be hidden from assistive technology and non-interactive.
- WCAG 2.2 AA target size is 24×24 CSS pixels or an applicable spacing/other exception. 44×44 is the enhanced AAA target and a useful touch design goal.
- Do not require a two-tap hover emulation for an ordinary link or button.
- Keep native media controls or tested custom controls; handle play() rejection, pause on reduced-motion activation, and remove subscriptions on teardown.

See [WCAG target size](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) and [animation-accessibility](../animation-accessibility/SKILL.md).

## Verification limits

A source review can identify a broken selector, invalid API, or missing preference branch. It cannot establish how motion feels or performs on a device. State which interactions were actually rendered, reversed, operated by keyboard/touch, and recorded. Name untested browsers, devices, and assistive technology. A fresh-eye pass can help; do not delay authorized delivery until another day.
