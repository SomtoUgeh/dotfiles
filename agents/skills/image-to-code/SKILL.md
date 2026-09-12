---
name: image-to-code
description: "Implement a web interface with close fidelity to supplied screenshots/design images or intentionally generated references in an explicitly requested image-first workflow."
---

# Image to Code

Translate visual references into a working interface while preserving the user's content, product requirements, repository conventions, and chosen style.

## Routing

- If the user asks only for design reference images, use `imagegen-frontend-web`.
- If the user provides a Figma file requiring design data, use the Figma implementation workflow.
- If no visual reference exists, generate one only when the user requested an image-first workflow or when image generation is already authorized by the task.
- If the user selected a named style, use it as the art direction; do not merge incompatible style mandates from other visual skills.

## Workflow

1. Read project instructions and inspect the current frontend stack, routes, tokens, assets, and reusable components.
2. View every supplied reference at useful resolution. If generating references, read [references/image-generation.md](references/image-generation.md).
3. Analyze layout, typography, color, spacing, media, components, responsive behavior, and interaction intent. Use [references/visual-analysis.md](references/visual-analysis.md) for complex references.
4. Map the visual system onto existing project primitives. Preserve real product copy and behavior unless the user asked for a rewrite.
5. Implement the complete requested surface, including loading, empty, error, focus, hover, and reduced-motion states where applicable.
6. Render at representative viewport sizes and compare with the reference. Fix the largest visible differences first. Read [references/implementation-and-verification.md](references/implementation-and-verification.md) for the fidelity loop.

## Reference Image Rules

Generate enough images to make each distinct composition legible, not a fixed image count. A single overview can be sufficient for a small page; complex pages may need section or detail images. Never compress many sections into an unreadable board.

When a source image lacks the detail needed for implementation, generate a fresh detail reference or ask for the missing design decision. Do not enlarge a tiny crop and treat invented pixels as source truth.

Across generated images, keep typography, palette, surface treatment, component language, and content model consistent. Allow section composition to vary so the page does not become a repeated left-text/right-image template.

## Fidelity Boundaries

- Derive structure from visible evidence; label uncertain behavior as inference.
- Keep the first viewport readable on a small laptop and test mobile reflow.
- Avoid accidental nested containers, decorative pills, and dense micro-controls unless the reference or product requires them.
- Match intentional whitespace and density instead of filling every gap.
- Use real accessible controls and semantic structure even when the reference is purely visual.
- Do not hide overflow globally to cover layout bugs.

## Completion

Report what was implemented, which references were used or generated, how the result was verified, and any visual or behavioral details that remain inferred.
