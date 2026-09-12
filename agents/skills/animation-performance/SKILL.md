---
name: animation-performance
description: "Diagnose measured web-animation jank, dropped frames, layout/paint cost, main-thread work, and compositor behavior. Use evidence to choose animation drivers and layers."
metadata:
  short-description: Diagnose animation bottlenecks with browser recordings
---

# Animation Performance

Follow the [canonical motion policy](../animate/references/canonical-policy.md).
Use [Motion's performance guide](https://motion.dev/docs/performance) and the
installed library's documentation for current behavior. This skill owns the
measurement and diagnosis workflow; `animate` owns motion direction,
`motion-react` and `css-animations` own implementation, and
`animation-accessibility` owns reduced-motion behavior.

## Establish a baseline

Reproduce the specific interaction, including rapid reversal and the workload
that exposes the problem: navigation, hydration, data loading, or a large list.
Record the browser, library version, viewport, device, refresh rate, and motion
preference. At 60 Hz the frame budget is about 16.7 ms; at 120 Hz it is 8.3 ms.

Capture a browser performance recording with frame timing, main-thread work,
style/layout, paint, and layer information. Use representative hardware when
available. CPU throttling is useful for comparison but does not reproduce a
phone's GPU or memory budget. Report device coverage you could not verify.

## Identify the work that misses the budget

| Evidence | Investigate |
| --- | --- |
| Long JavaScript tasks overlap dropped frames | Animation driver, rendering, data processing, and task scheduling |
| React renders for each pointer or animation update | State-driven frame updates versus motion values or a bounded imperative animation |
| Repeated layout across a large subtree | Size/position changes, forced measurement, and read/write ordering |
| Large or repeated paints | Shadows, blur, clipping, painted area, and invalidation |
| Growing layer count or memory use | Blanket `will-change`, forced transforms, oversized surfaces |
| Cost grows with descendants | Inherited style updates, animated CSS variables, and the number of active nodes |

Treat these as hypotheses to test, not diagnoses inferred from syntax.

## Rendering cost and driver are separate

`transform` and `opacity` are usually inexpensive choices because they can avoid
layout and paint. Size and flow changes can be appropriate when the interaction
requires them; measure the affected area. A transform changes visual geometry,
not document flow, so it is not always a correct replacement for layout.

Paint or compositor behavior for filters, clipping, colors, and SVG depends on
the effect and browser. A drop shadow is not identical to a box shadow, and a
clip-path can clip content that a border radius would leave visible. Verify
visual semantics as well as performance before substituting properties.

| Driver | What to verify |
| --- | --- |
| JavaScript `requestAnimationFrame` | Frame callbacks compete with main-thread work |
| CSS or Web Animations API | Eligible effects may avoid per-frame JavaScript; acceleration is not guaranteed |
| Motion's hybrid engine | Browser APIs or JavaScript may be selected by feature, property, and version |

Do not classify every `motion/react` component as JavaScript-only or replace it
with CSS just because the page is busy. Inspect the actual driver and recording.
Motion values can reduce React render work without removing every other frame
cost. Full transform strings and independent transform values may use different
paths; check the installed version before changing a readable convention.

## Apply the smallest demonstrated fix

- Remove unnecessary per-frame React updates. Use existing motion values or a
  bounded imperative animation with cleanup when it fits the component.
- Reduce avoidable layout/paint work while preserving geometry, focus, hit
  testing, hidden states, and scroll behavior. Opacity alone does not hide a
  control from keyboard navigation or assistive technology.
- Pause decorative loops while off-screen. Preserve state and resume only when
  the interaction and reduced-motion preference allow it.
- If inherited CSS-variable updates cause measured style recalculation, test a
  more local update. Do not assume every variable invalidates every descendant.
- If a large blur dominates paint/compositing, reduce its area, radius, or
  frequency and compare recordings; there is no universal safe pixel cutoff.
- Add a targeted `will-change` hint only when a trace demonstrates a benefit.
  It can cost memory and does not force GPU acceleration. Remove it when idle
  where practical, and compare layer count and frame timing afterward.

## Verify and report

Replay the same workload after the fix. Compare the measured bottleneck and
frame timing; verify rapid interruption, keyboard/touch use, both motion
preferences, and relevant browsers. Stop broadening the optimization when the
identified problem is resolved.

Report the reproduction, observed cause, changed behavior, before/after
measurement, and limitations. Do not claim a guaranteed frame rate or describe
a library migration as a performance fix without comparative evidence.
