# Motion audit checklist

The [canonical policy](../animate/references/canonical-policy.md) owns shared
motion rules. This checklist organizes evidence; it does not introduce a
second set of mandatory durations, curves, drivers, or accessibility defaults.
Use the project's established motion choices unless evidence supports a change.

Record each category as checked, not assessed, or not applicable for the
surfaces in scope. Name the evidence and any device or runtime limitations.

## 1. Purpose and frequency

- State what the animation communicates: feedback, continuity, changed state,
  hierarchy, or explanation. Distinguish a product interaction from marketing.
- Check frequent keyboard, selection, and repeated actions for feedback that
  trails the input or delays the next action. Instant feedback can be correct.
- Respect a documented brand or product choice. Frequency is a reason to test
  responsiveness, not an automatic defect attached to every transition.

## 2. Easing and duration

- Compare related interactions with the project's tokens and exemplars.
  Look for visible lag, abrupt stops, or travel that outlasts its purpose.
- Evaluate duration with distance, size, easing, and interruption behavior.
  Values in `animate` are starting points, not proof that another value fails.
- Check whether an exit needs the same complexity as an entrance. Preserve
  intentional constant motion and deliberate marketing sequences.
- Flag `transition: all` when it animates unintended properties; identify the
  actual property and consequence rather than assuming a GPU failure.

## 3. Physicality and origin

- Check trigger-anchored overlays against the correct primitive's transform
  origin. Radix and Base UI expose different variables and lifecycle attributes;
  verify the installed primitive using `css-animations` or `motion-react`.
- Look for distracting scale, large travel, and hover regions that flicker when
  the animated element moves out from under the pointer.
- Press feedback may use color, opacity, a border, or movement. Missing press
  scaling is not itself a defect. Check both motion preferences.

## 4. Interruption and springs

- Toggle and reverse the interaction while it is running; add/remove items and
  change targets rapidly. Report observed jumps or stale exit states.
- Match the driver to the interaction. CSS transitions can retarget; keyframes
  suit fixed sequences; runtime libraries can handle gestures and springs.
  No driver is inherently correct for every overlay or toast.
- A gesture that must track the pointer directly should not acquire unwanted
  spring lag. Bounce is a design choice, not a universal library default.
- Check mount/unmount behavior against the actual primitive. An enter transition
  alone does not prove an exit transition will survive unmounting.

## 5. Performance

Use `animation-performance` for the measurement workflow. A code pattern is a
candidate to investigate, not proof of dropped frames.

- Record the interaction under its relevant workload and display refresh rate.
- Identify long JavaScript work, React renders, layout, paint, or layer costs.
- Prefer inexpensive properties where they preserve geometry. Replacing layout
  with a transform can change document flow, hit testing, or scroll behavior.
- Motion uses a hybrid engine. Check the actual property, feature, version, and
  browser before replacing shorthands or claiming main-thread execution.
- Test inherited CSS variables, blur, and `will-change` only when a trace points
  to them. There is no universal blur cutoff or guaranteed layer promotion.

## 6. Accessibility

Use `animation-accessibility` and test both motion preferences.

- Reduce or remove spatial, zoom, parallax, and decorative looping motion.
  Preserve meaning with an instant state change or useful non-spatial feedback;
  reduced motion does not require a second animation.
- Verify focus, keyboard operation, autoplay controls, and hidden states.
  Opacity alone does not remove an element from navigation or accessibility APIs.
- Gate hover interaction for the relevant input capability and spatial hover
  effects for motion preference. Test touch and keyboard behavior separately.
- Check target size against the applicable standard. WCAG 2.2 AA's
  [24 CSS pixel minimum has exceptions](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html);
  [44 CSS pixels is the enhanced criterion](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html)
  and a useful touch target, not a blanket AA requirement.
- Check component overrides even when `MotionConfig reducedMotion="user"` is
  set. Global configuration alone does not prove every effect is suitable.

## 7. Cohesion and spatial consistency

- Compare related durations, curves, origins, and directional transitions.
  Check whether entry, exit, Back, and Next preserve understandable continuity.
- Look for parent/child animation combinations or stagger that hide content or
  delay interaction. Uniform timing can be correct when it serves the design.
- Evaluate morphs and crossfades visually. Do not add blur or shared layout
  solely because the checklist mentions them.

## 8. Missed opportunities

Report optional additions separately from defects. Consider feedback for
consequential state changes, continuity between related surfaces, and abrupt
content changes only where they improve comprehension or control. Each addition
must fit purpose, frequency, input capability, and reduced-motion behavior.
