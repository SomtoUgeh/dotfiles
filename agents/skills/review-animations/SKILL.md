---
name: review-animations
description: Review animation and motion changes for evidenced usability, accessibility, interruption, and performance problems while preserving the project's visual intent.
disable-model-invocation: true
metadata:
  short-description: Review motion with code and browser evidence
---

# Reviewing Animations

Review the requested motion surface. General code review belongs to `code-review`; use it for the remaining scope when requested rather than declining the user's task. Review-only requests return findings without editing files. A direct fix request authorizes the appropriate implementation workflow after confirming the issue.

Read [STANDARDS.md](STANDARDS.md) and follow the [canonical motion policy](../animate/references/canonical-policy.md). They distinguish technical contracts from course-derived design preferences. Do not treat a course anecdote, curve name, keyboard trigger, frequency estimate, or property name as proof of a defect.

## Establish context

Read project instructions, the scoped diff or components, package/lockfile versions, tokens, and relevant primitives. Identify the animation's purpose, trigger, enter/exit lifecycle, expected interruption, and supported browsers/input modes. Preserve documented product decisions unless evidence shows they violate the current request or required behavior.

## Review in order

1. **Correctness:** valid selectors, types, keys, state, measurement, refs, subscriptions, cleanup, and actual mounted/unmounted behavior.
2. **Accessibility:** meaningful state in both motion preferences; live preference changes; keyboard/touch use; focus and hidden content; autoplay controls; target sizes.
3. **Interruption:** rapid reversal, repeated input, overlapping exits, gesture cancellation, stale direction or timers, and content changes during motion.
4. **Performance:** reproduce the workload and use available traces. Inspect layout, paint, React updates, and layer costs. Route deeper measurement to `animation-performance`.
5. **Craft:** responsive timing, origin, hierarchy, continuity, readability during crossfades, and fit with the existing product. Treat unverified taste suggestions as optional.

Run focused existing checks and render the flow when available. For each check, record actual evidence or mark it not assessed. An unavailable browser or real device is a coverage limit, not an automatic pass or a reason to invent a verdict.

## Fix preference

Recommend the smallest change that fixes the observed consequence: correct the API/lifecycle, remove unnecessary work, reduce distance/delay, tune an existing token, or make retargeting continuous. Keep necessary layout behavior and do not change libraries solely to fit a preferred syntax. Add blur, springs, or stagger only when they improve the actual flow. Accessibility is part of the first fix, not final decoration.

## Output

Use the user's review format. Otherwise return one findings table with `file:line`, observed behavior, proposed fix, and consequence. Separate optional polish from blockers; omit empty tables and do not manufacture findings to meet a quota.

Close with one scoped verdict:

- **Block:** an evidenced correctness, usability, accessibility, or material performance regression remains.
- **No blockers found:** the checks performed found no blocking issue. State unavailable runtime/device checks explicitly.

A missing explicit key on a single conditional presence child, a non-pixel radius, ease-in, scale-from-zero, duration above 300ms, or a layout animation is not independently a blocker. Verify the actual behavior and supported API first.
