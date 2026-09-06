---
name: gpt-taste
description: Apply a bold editorial web style with wide typography, dense grids, cinematic spacing, and deliberate motion when the user explicitly requests this aesthetic.
---

# Bold Editorial Web Direction

Use this as one visual direction, not as a universal frontend standard. Preserve the user's brief, existing brand system, accessibility requirements, content structure, and chosen libraries. If another named visual style is explicitly selected, follow that style instead of combining incompatible mandates.

## Composition

- Keep display headlines broad enough to avoid awkward tall wraps. Choose type size and measure responsively from the actual copy rather than enforcing a fixed line count.
- Use deliberate asymmetry, strong negative space, or a dense grid when it supports the content.
- In bento layouts, verify intentional occupancy at every breakpoint. Empty space may be purposeful; accidental grid holes are not.
- Give each major section a distinct role and rhythm. AIDA is useful for conversion pages, but do not force it onto dashboards, tools, or content pages.
- Use a small number of signature components instead of repeating generic cards.

## Visual Character

- Prefer expressive typography that the project can legally and reliably load.
- Maintain readable contrast for text, controls, focus states, and media overlays.
- Avoid placeholder meta-labels, decorative badges, and stats that add no meaning.
- Choose imagery from the project's assets or an approved source. Do not insert a remote placeholder-image dependency without checking the project and user intent.
- Prevent accidental horizontal overflow at the element that causes it; do not hide page-wide overflow as a blanket workaround.

## Motion

Static interfaces are valid. Add motion only when it clarifies hierarchy, feedback, continuity, or narrative.

Inspect the existing stack before choosing CSS, WAAPI, Motion, or GSAP. Use GSAP and ScrollTrigger for complex scroll choreography when the project already depends on them or the user accepts the dependency. Prefer lighter native techniques for simple transitions.

Every motion treatment must include reduced-motion behavior, keyboard and focus parity, cleanup for subscriptions or timelines, and responsive testing. Avoid mandatory pinning, scrubbing, or stacking when content length, input mode, or device size makes it fragile.

## Before Implementation

State the selected composition, typography, palette, responsive constraints, and motion purpose in plain language when a plan helps. Never pretend to execute random code. If variation is useful, choose deliberately from several relevant alternatives or run a real tool and report its actual output.

Verify the rendered result at representative viewport sizes, including a small laptop and mobile, and check contrast, focus visibility, overflow, headline wrapping, grid occupancy, and reduced motion.
