---
name: imagegen-frontend-web
description: Generate coherent, implementation-ready visual references for a website or web page. Use when the user explicitly asks for frontend comps, section images, or image-first art direction without code implementation.
---

# Frontend Reference Image Generation

Create readable visual references that communicate one coherent web design system. This skill produces images and art direction; use `image-to-code` when implementation is also requested.

## Brief and Routing

Use the user's product, audience, content, conversion goal, brand constraints, viewport, and chosen visual style. Do not replace an explicit aesthetic with another named style or combine conflicting style rules.

If the request is under-specified, infer low-risk details and ask only about decisions that materially change the composition or brand.

## Decide the Image Set

Generate the smallest set that shows every distinct composition at implementation-readable scale.

- A compact page may need one full-page composition.
- A long or varied page may need separate images for sections.
- Dense or interactive elements may need focused detail views.

Do not enforce one image per section when a combined view remains clear. Do not compress many sections into an unreadable contact sheet. Read [references/section-system.md](references/section-system.md) for complex page sets.

## Art Direction

Select a deliberate theme, typography character, palette, material treatment, hero architecture, section system, and media language. Read [references/art-direction-options.md](references/art-direction-options.md) when the brief needs exploration.

Keep the system consistent across images while varying composition anchors, media placement, scale, and density. Treat a named visual style as an alternative selected by the brief, not a rule to mix with every other style skill.

## Content and Conversion

Use plausible, specific content that shows realistic wrapping and hierarchy. Keep the hero focused on the primary promise and action. Vary CTA form only when the task calls for different interaction types.

Avoid filler labels, meaningless metrics, decorative badges, repeated generic cards, and gratuitous marquees. Whitespace may be intentional. Use data displays only when the product actually needs them.

## Generation

Use the available image-generation tool. Generate each required view as a fresh composition at a useful horizontal resolution. Carry forward the same palette, typography, surfaces, and component language in every prompt.

If an output loses text legibility, continuity, or section hierarchy, regenerate that view. Do not crop and upscale an old image to manufacture missing detail.

## Quality Check

Before returning images, check:

- every required section or detail is represented;
- the first viewport is clear on a small laptop;
- hierarchy and text wrapping are credible;
- images share one design system;
- section compositions do not repeat mechanically;
- controls and text have usable contrast;
- there is enough visual detail for implementation.

Read [references/quality-check.md](references/quality-check.md) for a deeper pass. Return the images with a short map from each image to its page section or purpose.
