# Animations

Follow the [canonical motion policy](../animate/references/canonical-policy.md). Use `animate` for direction, `css-animations` or `motion-react` for implementation, and the focused accessibility/performance skills for verification. Preserve the project's existing tokens and product intent.

## Choose motion with a purpose

Use motion for feedback, continuity, state change, or explanation. Frequent actions must respond immediately; a keyboard trigger alone does not ban animation. Remove delays or movement that obstruct the task. Marketing sequences may run longer when they serve the story and keep content accessible.

Useful starting points:

| Interaction | Timing |
| --- | --- |
| Small feedback | 100–200ms |
| Dropdown or tooltip | 125–250ms |
| Modal or drawer | 200–500ms |

Tune timing with distance, size, easing, frequency, and interruption. Named curves are valid: ease-out for responsive entrance/exit, ease-in-out for movement between visible states, ease for small color changes, and linear for constant progress or rotation. Custom curves are optional, not a quality gate.

## Physical continuity

- Keep press feedback immediate; use a small scale only where it fits and reduced motion permits it.
- Anchor a triggered popover to its positioning library's computed origin, including collision flips. Centered modals can remain centered.
- Animate an inner surface if moving the hover target causes flicker.
- Retarget from the current visible state on reversal. CSS transitions handle changing targets; runtime springs can preserve velocity for gestures. Keyframes follow a timeline and require explicit controls for interruption.
- Set spring parameters using the installed library's contract. Apple damping ratios and Motion's damping coefficient are different quantities. Extra damping can reduce oscillation but also lengthen settling.

## Presence and layout

Keep the presence boundary mounted while children exit. Use stable keys for swapped/list children; use the installed primitive's lifecycle instead of assuming React will wait for CSS. Radix and Base UI do not share identical attributes. Motion's `wait` mode handles one child; `popLayout` removes exiting items from flow and needs correct ref/containing-block behavior.

For changing intrinsic height, measure an inner element and animate the outer one. Restore `height: "auto"` under reduced motion instead of leaving a stale pixel height. Check initial unmeasured values and meaningful zero-height content separately.

## Performance

Transform and opacity usually avoid layout/paint, but no syntax guarantees GPU use or frame rate. Motion is a hybrid engine; the actual driver varies by feature, version, and property. Record the interaction before replacing `x` with a transform string or adding `will-change`.

Dimension, clipping, shadow, blur, and inherited-variable changes need measurement in their real context. There is no universal 20px blur cutoff. Layer hints and containment can consume memory or change rendering. Pause decorative loops while off-screen and clean up animation handles/subscriptions on unmount.

## Accessibility

Design both motion preferences from the beginning. Under reduced motion, remove or reduce spatial/decorative movement and preserve meaning with instant or restrained non-spatial feedback.

```jsx
import { motion, useReducedMotion } from "motion/react";

function Notice() {
  const reduce = useReducedMotion();
  return (
    <motion.div
      initial={reduce ? false : { opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
    >Saved</motion.div>
  );
}
```

`MotionConfig reducedMotion="user"` disables transform and layout animation while retaining other animated values. It is a baseline, not proof that explicit height, SVG, autoplay, or custom code respects the preference. Use the accessibility skill for SSR and live preference changes.

Keep hover decorative and gate spatial hover by both pointer capability and motion preference. Keyboard focus, touch operation, and readable hidden states must work independently. Do not hide focusable content with opacity alone. Preserve native media controls and handle rejected playback promises.

## Verify

Replay enter, exit, rapid reversal, keyboard/touch input, both preferences, live preference changes, and the relevant workload. For gestures, test pointer cancellation and real-device behavior when possible. Choose swipe thresholds from measured velocity units, distance, and product behavior; there is no universal `0.10` threshold.

Report what was observed and what remains untested. Do not prescribe a next-day pause or claim Safari/device coverage from desktop Chrome.

Sources: [Motion accessibility](https://motion.dev/docs/react-accessibility), [Motion performance](https://motion.dev/docs/performance), [Motion presence](https://motion.dev/docs/react-animate-presence).
