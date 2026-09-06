# Canonical Web Motion Policy

This file is the shared policy for the animation skills. When a companion skill
uses a stronger or conflicting rule, this policy wins. Treat timing and easing
values as starting points; verify them in the actual interface.

## Scope routing

- Use `animate` to decide whether motion belongs, set its purpose, and coordinate
  motion across an interaction.
- Use `css-animations` when the implementation is CSS transitions, keyframes,
  transforms, or `@starting-style`.
- Use `motion-react` when the implementation uses Motion for React, including
  variants, gestures, layout transitions, or motion values.
- Use `animation-performance` to diagnose measured frame drops, main-thread
  contention, layout or paint cost, and compositor behavior.
- Use `animation-accessibility` to design and test the reduced-motion variant.
- Use `emil-design-engineering` for broad interface craft. Route deep motion work
  to the focused skills above.

## Accessibility

Respect `prefers-reduced-motion: reduce` from the first implementation pass.
Reduce or remove spatial movement, zooming, parallax, smooth scrolling, and
autoplaying or looping decorative motion. Preserve state meaning with an instant
change or a restrained non-spatial transition such as opacity or color when that
helps comprehension. Do not assume every animation needs a second animated
variant: disabling a decorative animation is valid.

Test both preference states in browser emulation and, for important flows, on a
real device. Check library-level defaults and component overrides; a global
setting is a safety net rather than proof that every interaction is suitable.

## Performance

Prefer `transform` and `opacity` because they usually avoid layout and paint.
Other properties may be appropriate when correctness requires them or profiling
shows their cost is acceptable. CSS and Web Animations can run eligible effects
away from JavaScript's main-thread work, but compositor promotion and GPU use are
browser decisions, not guarantees.

Do not infer performance from syntax alone. Library internals and browser support
change. Check current framework documentation, record the interaction in browser
performance tools, and test representative hardware before making a categorical
claim. Diagnose the actual bottleneck before adding `will-change`, containment,
forced layers, or transform workarounds; those techniques have memory and
rendering costs of their own.

Target the display's refresh budget rather than a fixed universal number. At
60 Hz a frame is about 16.7 ms; at 120 Hz it is about 8.3 ms. Use recordings to
identify long tasks, style recalculation, layout, paint, and dropped frames.

## Choosing a driver

- CSS transitions suit state changes that should retarget from the current
  computed value.
- CSS keyframes suit autonomous loops and fixed multi-step sequences.
- Web Animations and motion libraries suit runtime orchestration, gestures,
  springs, layout transitions, and cases where CSS becomes harder to maintain.

Choose by interaction needs, current project conventions, bundle constraints,
browser support, and measured behavior. No driver is universally smoother.

## Review gate

For every changed interaction, verify purpose, interruption and reversal,
keyboard and touch behavior, both motion preferences, and performance under a
representative workload. Report what was observed; do not claim a device,
browser, or assistive setting was tested when it was not.
