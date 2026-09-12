---
name: high-end-visual-design
description: Apply a polished luxury-agency web aesthetic when the user explicitly asks for premium, luxury, or high-end agency art direction.
---

# Luxury Web Art Direction

Use this selectable direction when explicitly requested. Preserve the user's
brand, content, licensed assets, accessibility constraints, and existing stack.
The options below support art direction; they do not override established fonts,
components, or the requested layout. Combine named styles only when requested.
Follow the [canonical motion policy](../animate/references/canonical-policy.md).

## Choose a direction from the brief

Use an existing reference or brand first. Otherwise select a coherent palette,
typography, and composition from these starting points. Consistency across pages
matters more than inventing a different aesthetic on each invocation.

- **Ethereal glass:** OLED black, restrained luminous accents, fine translucent
  edges, geometric typography. Use blur sparingly with legible opaque fallbacks.
- **Editorial luxury:** warm cream, sage or espresso, a licensed expressive serif
  for headings, generous whitespace, optional subtle paper grain.
- **Soft structuralism:** silver-grey or white, bold typography, airy spacing,
  soft ambient shadows where they clarify depth.

An asymmetric bento can organize varied content; an editorial split can pair a
strong headline with imagery. Overlapping cards can create depth when they keep
reading order and touch targets clear. These are options, not a required menu.
Use available licensed typefaces and a consistent icon family. Prefer deliberate
borders and shadows over adding decoration to every surface.

## Optional component treatments

Apply a treatment only where it strengthens the chosen direction:

- **Double bezel:** a subtle outer shell around an inner surface can frame a
  hero image or feature card. Keep radii concentric (inner radius = outer radius
  minus inset). Flat cards, ordinary inputs, and undecorated content remain valid.
- **Inset CTA icon:** a pill button may include a visually inset circular arrow
  wrapper. Keep it one semantic button; never nest interactive buttons. Existing
  button shapes and simple text-plus-icon treatments are equally valid.
- **Spatial rhythm:** generous section spacing and occasional eyebrow labels can
  support hierarchy. Derive spacing from content and responsive tokens instead
  of imposing one minimum padding or a badge above every heading.
- **Floating navigation:** a detached pill works for short navigation. Use a
  conventional header when it better fits the information architecture.

## Motion and responsive behavior

Use motion to clarify an interaction, with explicit animated properties and
appropriate timing. Simple color feedback and instant state changes are valid.
Optional press scaling, icon movement, or hamburger-to-close morphs must preserve
focus, keyboard/touch operation, and reduced-motion alternatives.

A mobile menu can be a panel or overlay depending on its content. Do not require
heavy blur, full-screen expansion, or staggered links. Keep navigation immediately
usable. Occasional scroll reveals must preserve visible content if JavaScript
fails and omit decorative travel or delay under reduced motion.

Collapse asymmetric layouts where content needs it; remove overlaps or rotations
that obstruct mobile targets. Use project breakpoints and spacing tokens. Choose
`svh` for stable small-viewport height or `dvh` to track browser chrome only after
checking the intended scrolling and keyboard behavior.

## Verify the result

Render the important states at desktop and mobile sizes. Check hierarchy, real
content, focus, keyboard/touch interaction, reduced motion, and loading/failure
states appropriate to the change. Use the existing stacking scale for overlays;
texture layers must not intercept input or obscure content.

Prefer transform/opacity when they preserve geometry. Measure costly blur,
shadow, clipping, or layout effects when warranted; fixed placement and
`will-change` do not guarantee acceleration. Test opaque fallbacks for translucent
surfaces. Report untested states and visual inferences rather than claiming a
universal quality score from a checklist of decorative effects.
