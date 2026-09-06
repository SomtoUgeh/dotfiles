---
name: emil-design-engineering
description: "Apply Emil Kowalski's design-engineering craft to polished, accessible web interfaces. Use for broad UI review and implementation across forms, controls, touch behavior, typography, layout stability, component APIs, marketing pages, and performance, or for a focused local polish pass when an interface feels off. Route deep motion work to the focused motion skills."
---

# Emil's Design Engineering Principles

A comprehensive guide for building polished, accessible web interfaces based on Emil Kowalski's design engineering practices.

## Choose the scope

- **Broad design-engineering pass:** read the references that match the surface
  being built or reviewed. Check structure, interaction, accessibility, visual
  craft, and performance together.
- **Focused polish pass:** when a component or small region "feels off," read
  [focused-polish.md](focused-polish.md). Keep the pass local unless the cause is
  a shared token, primitive, or layout rule.

For motion work, follow
[../animate/references/canonical-policy.md](../animate/references/canonical-policy.md)
as the canonical policy. It wins when this skill or a companion reference makes
a stronger or conflicting claim. Route to `animate`, `css-animations`,
`animation-performance`, or `animation-accessibility` as appropriate.

## Quick Reference

| Category                                        | When to Use                                          |
| ----------------------------------------------- | ---------------------------------------------------- |
| [Focused Polish](focused-polish.md)             | Local spacing, type, surfaces, states, optical fixes |
| [Animations](animations.md)                     | Enter/exit transitions, easing, springs, performance |
| [UI Polish](ui-polish.md)                       | Typography, visual design, layout, colors            |
| [Forms & Controls](forms-controls.md)           | Inputs, buttons, form submission                     |
| [Touch & Accessibility](touch-accessibility.md) | Mobile, touch devices, keyboard nav, a11y            |
| [Component Design](component-design.md)         | Compound components, composition, props API          |
| [Marketing](marketing.md)                       | Landing pages, blogs, docs sites                     |
| [Performance](performance.md)                   | Virtualization, preloading, optimization             |
| [Design Rules](design-rules.md)                 | Paired right/wrong calls across icons, type, color, IA, interaction, copy |

## Core Principles

### 1. No Layout Shift

Dynamic elements should cause no layout shift. Use hardcoded dimensions, `font-variant-numeric: tabular-nums` for changing numbers, and avoid font weight changes on hover/selected states.

### 2. Touch-First, Hover-Enhanced

Design for touch first, then add hover enhancements. Disable hover effects on touch devices. Meet the WCAG target-size baseline and aim for a comfortable 44px touch target. Never rely on hover for core functionality.

### 3. Keyboard Navigation

Tabbing should work consistently. Only allow tabbing through visible elements. Ensure keyboard navigation scrolls elements into view with `scrollIntoView()`.

### 4. Accessibility by Default

Every animation needs `prefers-reduced-motion` support. Every icon button needs an aria label. Every interactive element needs proper focus states.

### 5. Speed Over Delight

Product UI should be fast and purposeful. Skip animations for frequently-used interactions. Marketing pages can be more elaborate.

## Decision Flowcharts

### Should I Animate This?

```
Will users see this 100+ times daily?
├── Yes → Don't animate
└── No
    ├── Is this user-initiated?
    │   └── Yes → Animate with ease-out (150-250ms)
    └── Is this a page transition?
        └── Yes → Animate (300-400ms max)
```

### What Easing Should I Use?

```
Is the element entering or exiting?
├── Yes → ease-out
└── No
    ├── Is it moving on screen?
    │   └── Yes → ease-in-out
    └── Is it a hover/color change?
        ├── Yes → ease
        └── Default → ease-out
```

## Common Mistakes

| Mistake                     | Fix                                         |
| --------------------------- | ------------------------------------------- |
| `transition: all`           | Specify exact properties                    |
| Hover effects on touch      | Use `@media (hover: hover)`                 |
| Font weight change on hover | Use consistent weights                      |
| Costly layout animation     | Prefer transform/opacity; profile the flow |
| No reduced motion support   | Add `prefers-reduced-motion` query          |
| z-index: 9999               | Use fixed scale or `isolation: isolate`     |
| Custom page scrollbars      | Only customize scrollbars in small elements |

## Review Checklist

When reviewing UI code, check:

- [ ] No layout shift on dynamic content
- [ ] Animations have reduced motion support
- [ ] Pointer targets meet WCAG 2.2 AA; touch-heavy controls aim for 44px
- [ ] Hover effects disabled on touch devices
- [ ] Keyboard navigation works properly
- [ ] Icon buttons have aria labels
- [ ] Forms submit with Enter/Cmd+Enter
- [ ] Inputs are 16px+ to prevent iOS zoom
- [ ] No `transition: all`
- [ ] z-index uses fixed scale

## Reference Files

For detailed guidance on specific topics:

- [animations.md](animations.md) - Easing, timing, springs, performance
- [focused-polish.md](focused-polish.md) - Local visual diagnosis and high-value detail work
- [ui-polish.md](ui-polish.md) - Typography, shadows, gradients, scrollbars
- [forms-controls.md](forms-controls.md) - Inputs, buttons, form patterns
- [touch-accessibility.md](touch-accessibility.md) - Touch devices, keyboard nav, a11y
- [component-design.md](component-design.md) - Compound components, composition, props API
- [marketing.md](marketing.md) - Landing pages, blogs, docs
- [performance.md](performance.md) - Virtualization, preloading, optimization
