---
name: frontend-design
description: Design and implement a production-grade web interface when no more specific supplied-design, image-first, redesign, or named-style workflow applies.
---

This skill guides creation of distinctive, production-grade frontend interfaces. Implement real working code with close attention to aesthetic details and purposeful choices.

Use this as the general frontend implementation skill. Route supplied screenshots to shared `image-to-code`, Figma sources to native `figma-design-to-code` when available or shared `implement-design` otherwise, existing-site redesigns to `redesign-existing-projects`, and visual-comp-only requests to `imagegen-frontend-web`. An explicit user choice overrides this routing. If the user chooses a named style, follow it without blending incompatible mandates from other visual skills.

The user provides frontend requirements: a component, page, application, or interface to build. They may include context about the purpose, audience, or technical constraints.

## Design Thinking

Before coding, understand the context and commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this interface solve? Who uses it?
- **Tone**: Pick an extreme: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian, etc. There are so many flavors to choose from. Use these for inspiration but design one that is true to the aesthetic direction.
- **Constraints**: Technical requirements (framework, performance, accessibility).
- **Differentiation**: What makes this UNFORGETTABLE? What's the one thing someone will remember?

**CRITICAL**: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work - the key is intentionality, not intensity.

Then implement working code (HTML/CSS/JS, React, Vue, etc.) that is:
- Production-grade and functional
- Visually striking and memorable
- Cohesive with a clear aesthetic point-of-view
- Meticulously refined in every detail

## Frontend Aesthetics Guidelines

Focus on:
- **Typography**: Choose legible type suited to the subject and existing brand. Establish a deliberate scale and hierarchy; use one family or a clearly differentiated pair. Preserve user-selected and established product fonts.
- **Color & Theme**: Commit to a cohesive aesthetic. Use CSS variables for consistency. Dominant colors with sharp accents outperform timid, evenly-distributed palettes.
- **Motion**: Make user actions and state changes easy to follow. Use non-interactive motion sparingly, respect reduced motion, and follow the repository's existing animation tools. Add a page entrance or scroll effect only when it serves the brief.
- **Spatial Composition**: Unexpected layouts. Asymmetry. Overlap. Diagonal flow. Grid-breaking elements. Generous negative space OR controlled density.
- **Backgrounds & Visual Details**: Create atmosphere and depth rather than defaulting to solid colors. Add contextual effects and textures that match the overall aesthetic. Apply creative forms like gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows, decorative borders, custom cursors, and grain overlays.

Avoid thoughtless defaults such as an unrelated font swap, a decorative purple gradient, or a layout copied without regard for the product. Established brand fonts and system fonts are valid when the repository or user chose them.

Interpret creatively where the brief leaves room. Choose light or dark mode, typography, and composition from the actual product context rather than forcing novelty across runs.

**IMPORTANT**: Match implementation complexity to the aesthetic vision. Maximalist designs need elaborate code with extensive animations and effects. Minimalist or refined designs need restraint, precision, and careful attention to spacing, typography, and subtle details. Elegance comes from executing the vision well.

Before finishing, inspect the rendered interface and its primary interactions.
Check responsive layout, keyboard focus, contrast, and reduced motion. Remove
decorative labels, repeated effects, and placeholder copy that do not help the
person using the product. Report any visual checks that could not run.
