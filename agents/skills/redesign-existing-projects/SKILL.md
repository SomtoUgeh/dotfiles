---
name: redesign-existing-projects
description: Audit and improve the visual design of an existing website or app in its current stack when the user explicitly requests a redesign.
---

# Redesign Skill

Preserve explicit user choices, brand rules, accessibility constraints, and working product behavior. Treat the audit below as diagnostic prompts; apply a change only when the observed interface shows the problem.

## How This Works

When applied to an existing project, follow this sequence:

1. **Scan** — Read the codebase. Identify the framework, styling method (Tailwind, vanilla CSS, styled-components, etc.), and current design patterns.
2. **Diagnose** — Inspect the rendered interface against the brief. Report usability, hierarchy, consistency, or accessibility problems with evidence. A familiar font, layout, or component is not a defect by itself.
3. **Fix** — Apply targeted upgrades working with the existing stack. Do not rewrite from scratch. Improve what's there.

## Design Audit

Distinguish functional/accessibility defects from aesthetic options. For the latter, name the observed mismatch with the brief before changing anything; keep an established choice that works. The examples below are alternatives, not requirements to replace conventional patterns. Do not add imagery, texture, motion, dependencies, or new product scope merely to satisfy a checklist.

### Typography

Check for these problems and fix the ones supported by the interface:

- **Typeface does not fit the brief or harms readability.** Preserve established fonts, including Inter and system fonts. If a change is justified, evaluate available fonts against the brand, loading cost, and rendered text; an editorial brief may benefit from a serif/sans pairing.
- **Headlines do not establish the intended hierarchy.** Tune size, weight, spacing, and line-height against the rendered page; a restrained headline may fit the brief.
- **Body text too wide.** Limit paragraph width to roughly 65 characters. Increase line-height for readability.
- **Text hierarchy is unclear.** Adjust size, spacing, or weight as needed. Two weights may be sufficient; add weights only when they distinguish meaningful levels.
- **Numbers in proportional font.** Use a monospace font or enable tabular figures (`font-variant-numeric: tabular-nums`) for data-heavy interfaces.
- **Tracking hurts legibility or hierarchy.** Adjust only where the font, size, and rendered text warrant it.
- **Subheader treatment hurts reading or conflicts with the voice.** Compare case and emphasis options; preserve readable all-caps when intentional.
- **Orphaned words.** Single words sitting alone on the last line. Fix with `text-wrap: balance` or `text-wrap: pretty`.

### Color and Surfaces

- **Dark surfaces obscure hierarchy or strain readability.** Test contrast and separation; pure black and tinted darks are both valid when they fit the design.
- **Accent colors compete with content or fail contrast.** Adjust the palette against rendered evidence; do not impose a universal saturation cutoff.
- **Accent colors have inconsistent roles.** Define clear semantic and brand roles. Preserve multiple accents when they support those roles.
- **Neutral colors appear inconsistent.** Check their semantic and brand roles before consolidating them; intentional warm/cool contrast may be useful.
- **Gradients conflict with the brief or reduce legibility.** Adjust them only for that observed problem; hue alone is not evidence of poor design.
- **Shadows obscure surface relationships.** Tune hue, opacity, and spread to clarify elevation; neutral shadows are valid.
- **Surface treatment does not support the intended hierarchy.** Flat surfaces are valid. Consider texture only when the brief calls for it and it preserves legibility.
- **Gradient treatment lacks the intended emphasis.** Compare linear, radial, or other treatments against the brief; uniformity alone does not require a change.
- **Inconsistent lighting direction.** Audit all shadows to ensure they suggest a single, consistent light source.
- **A contrasting section disrupts hierarchy or readability.** Check whether its contrast intentionally groups content or emphasizes an action. Keep purposeful mixed light/dark sections; adjust only the observed mismatch.
- **Sections lack a clear content hierarchy.** Improve grouping, typography, and spacing first. Add relevant imagery only when it serves the brief; keep prototypes clearly labelled and do not introduce arbitrary stock photos into an existing product.

### Layout

- **Alignment weakens scanning or emphasis.** Compare centered and asymmetric arrangements when evidence supports changing the composition.
- **Feature grouping hides differences or breaks responsiveness.** Choose a layout that supports comparison and reading order. Equal card columns are valid when they serve the content.
- **Full-screen sections clipped by browser chrome.** Choose `min-height: 100svh` for a stable small viewport or `100dvh` to track the changing viewport. `dvh` can resize during scrolling; test browser chrome and keyboard states.
- **Complex flexbox percentage math.** Replace with CSS Grid for reliable multi-column structures.
- **No max-width container.** Add a container constraint (around 1200-1440px) with auto margins so content doesn't stretch edge-to-edge on wide screens.
- **Card sizing creates clipping or excessive empty space.** Balance content fit with aligned comparison; equal heights and variable heights are both valid.
- **Corner treatment conflicts with nesting or the visual system.** Adjust radii only where that improves consistency; uniform radii are valid.
- **Layer relationships are unclear.** Use spacing, borders, or elevation to express them; do not add overlap just for decoration.
- **Padding appears optically unbalanced.** Adjust against rendered content rather than enforcing either symmetry or asymmetry.
- **Navigation does not fit task frequency or screen size.** Preserve a useful sidebar; compare alternatives only for an observed navigation problem.
- **Crowding hurts reading or interaction.** Increase spacing where needed while preserving useful density; validate the result at target sizes.
- **Buttons not bottom-aligned in card groups.** When cards have different content lengths, CTAs end up at random heights. Pin buttons to the bottom of each card so they form a clean horizontal line regardless of content above.
- **Feature lists starting at different vertical positions.** In pricing tables or comparison cards, the list of features should start at the same Y position across all columns. Use consistent spacing above the list or fixed-height title/price blocks.
- **Inconsistent vertical rhythm in side-by-side elements.** When placing cards, columns, or panels next to each other, align shared elements (titles, descriptions, prices, buttons) across all items. Misaligned baselines make the layout look broken.
- **Mathematical alignment that looks optically wrong.** Centering by the math doesn't always look centered to the eye. Icons next to text, play buttons in circles, or text in buttons often need 1-2px optical adjustments to feel right.

### Interactivity and States

- **Interactive controls lack pointer feedback.** Add suitable hover feedback where useful, gated for hover-capable pointers; movement is optional.
- **Pressed state is unclear.** Use color, border, or restrained movement when it clarifies activation; preserve reduced-motion behavior.
- **Unclear state changes.** Add the least feedback that clarifies the action. Instant changes are valid for frequent actions and reduced motion; avoid blanket transitions.
- **Missing focus ring.** Ensure visible focus indicators for keyboard navigation. This is an accessibility requirement, not optional.
- **Loading lacks clear feedback.** Use the existing spinner, progress indicator, or skeleton that best communicates the wait and preserves layout.
- **No empty states.** An empty dashboard showing nothing is a missed opportunity. Design a composed "getting started" view.
- **No error states.** Add clear, inline error messages for forms. Do not use `window.alert()`.
- **Dead links.** Buttons that link to `#`. Either link to real destinations or visually disable them.
- **No indication of current page in navigation.** Style the active nav link differently so users know where they are.
- **Disorienting anchor navigation.** Check sticky-header offsets and focus. Add smooth scrolling only where useful, under `prefers-reduced-motion: no-preference`.
- **Expensive animations.** Prefer transform/opacity when geometry remains correct; profile layout and paint before replacing dimension or position animation.

### Content

- **Example identities distract from the task.** Use clearly labelled sample data appropriate to the prototype; preserve real identities.
- **Unsupported numbers or contact details.** Preserve source data. Use clearly labelled sample data in prototypes; never invent metrics, prices, testimonials, or reachable contact details to make a product look credible.
- **Placeholder company names are mistaken for real brands.** Label them as samples; preserve established product names.
- **AI copywriting cliches.** Never use "Elevate", "Seamless", "Unleash", "Next-Gen", "Game-changer", "Delve", "Tapestry", or "In the world of...". Write plain, specific language.
- **Success messages conflict with the product voice.** Prefer clear confirmation; punctuation alone is not a defect.
- **"Oops!" error messages.** Be direct: "Connection failed. Please try again."
- **Passive voice.** Use active voice: "We couldn't save your changes" instead of "Mistakes were made."
- **Suspicious or missing publication dates.** Verify the content source. Preserve actual dates and mark unknown dates; never randomize them to appear real.
- **Avatars misidentify people.** Preserve verified assets; use initials or clearly labelled placeholders when a real image is unavailable.
- **Lorem Ipsum.** Never use placeholder latin text. Write real draft copy.
- **Heading case is inconsistent with the product voice.** Follow the existing style guide; sentence case and title case are both valid.

### Component Patterns

- **Card grouping obscures hierarchy.** Adjust borders, elevation, background, or spacing to clarify relationships; conventional cards may already do this well.
- **Actions compete for attention.** Clarify primary, secondary, and tertiary actions. Keep familiar filled/ghost combinations when their priority is clear.
- **Badges overpower the content.** Reduce emphasis or change their treatment only when they distract or misrepresent status.
- **FAQs are hard to find or scan.** Compare an accordion, inline list, or search based on content length and user tasks; an accordion alone is not a defect.
- **Testimonials are hard to browse or verify.** Improve controls and source attribution. Preserve real quotes and choose a layout that supports reading.
- **Pricing tiers are hard to compare.** Align shared features and make meaningful differences clear; preserve useful column layouts.
- **Modal interaction interrupts a simple task.** Consider inline editing or a panel when it improves the flow. Keep necessary dialog semantics and focus behavior.
- **Avatar treatment conflicts with the visual system.** Standardize shape and crop; circles are a valid default.
- **Theme controls are unclear or inaccessible.** Preserve a recognizable toggle or settings control that communicates its current state and system preference.
- **Footer organization hides important destinations.** Group links around navigation needs and preserve required legal links.

### Iconography

- **Icons are unclear or inconsistent with the brand.** Prefer the existing icon set, including Lucide or Feather; replace it only for a demonstrated mismatch.
- **Icon metaphors confuse the action.** Prefer recognizable meaning over novelty; keep conventional icons when clear.
- **Inconsistent stroke widths across icons.** Audit all icons and standardize to one stroke weight.
- **Missing favicon.** Always include a branded favicon.
- **Stock "diverse team" photos.** Use real team photos, candid shots, or a consistent illustration style instead of uncanny stock imagery.

### Code Quality

- **Div soup.** Use semantic HTML: `<nav>`, `<main>`, `<article>`, `<aside>`, `<section>`.
- **Inline styles mixed with CSS classes.** Move all styling to the project's styling system.
- **Hardcoded pixel widths.** Use relative units (`%`, `rem`, `em`, `max-width`) for flexible layouts.
- **Missing alt text on images.** Describe image content for screen readers. Never leave `alt=""` or `alt="image"` on meaningful images.
- **Arbitrary z-index values like `9999`.** Establish a clean z-index scale in the theme/variables.
- **Commented-out dead code.** Remove all debug artifacts before shipping.
- **Import hallucinations.** Check that every import actually exists in `package.json` or the project dependencies.
- **Missing meta tags.** Add proper `<title>`, `description`, `og:image`, and social sharing meta tags.

### Strategic Omissions (What AI Typically Forgets)

- **No legal links.** Add privacy policy and terms of service links in the footer.
- **No "back" navigation.** Dead ends in user flows. Every page needs a way back.
- **No custom 404 page.** Design a helpful, branded "page not found" experience.
- **No form validation.** Add client-side validation for emails, required fields, and format checks.
- **No "skip to content" link.** Essential for keyboard users. Add a hidden skip-link.
- **No cookie consent.** If required by jurisdiction, add a compliant consent banner.

## Upgrade Techniques

Use these optional techniques only when the brief and observed problem justify them; conventional or static treatments may be the best fit:

### Typography Upgrades
- **Variable font animation.** Interpolate weight or width on scroll or hover for text that feels alive.
- **Outlined-to-fill transitions.** Text starts as a stroke outline and fills with color on scroll entry or interaction.
- **Text mask reveals.** Large typography acting as a window to video or animated imagery behind it.

### Layout Upgrades
- **Broken grid / asymmetry.** Elements that deliberately ignore column structure — overlapping, bleeding off-screen, or offset with calculated randomness.
- **Whitespace maximization.** Aggressive use of negative space to force focus on a single element.
- **Parallax card stacks.** Sections that stick and physically stack over each other during scroll.
- **Split-screen scroll.** Two halves of the screen sliding in opposite directions.

### Motion Upgrades
- **Scroll treatment.** Preserve native scrolling by default. Custom inertia requires explicit brief support, input parity, reduced-motion handling, and real-device tests.
- **Staggered entry.** Elements cascade in with slight delays, combining Y-axis translation with opacity fade. Keep content available immediately; use stagger only when it helps and remove decorative delay for reduced motion.
- **Spring physics.** Use springs for gestures and retargeting when they help. Preserve linear timing for constant motion and progress indicators.
- **Scroll-driven reveals.** Content entering through expanding masks, wipes, or draw-on SVG paths tied to scroll progress.

### Surface Upgrades
- **True glassmorphism.** Go beyond `backdrop-filter: blur`. Add a 1px inner border and a subtle inner shadow to simulate edge refraction.
- **Spotlight borders.** Card borders that illuminate dynamically under the cursor.
- **Grain and noise overlays.** A fixed, pointer-events-none overlay with subtle noise to break digital flatness.
- **Colored, tinted shadows.** Shadows that carry the hue of the background rather than using generic black.

## Fix Priority

Apply changes in this order for maximum visual impact with minimum risk:

1. **Typography fit** — preserve established fonts; change them only when the brief and rendered evidence support it
2. **Color palette cleanup** — remove clashing or oversaturated colors
3. **Hover and active states** — makes the interface feel alive
4. **Layout and spacing** — proper grid, max-width, consistent padding
5. **Component fit** — revise components only where their behavior or presentation does not serve the task
6. **Add loading, empty, and error states** — makes it feel finished
7. **Polish typography scale and spacing** — the premium final touch

## Rules

- Work with the existing tech stack. Do not migrate frameworks or styling libraries.
- Preserve existing functionality. After a coherent edit, run focused checks for the affected flows and inspect the rendered result. Repeat checks when new edits or failures warrant it.
- Before importing any new library, check the project's dependency file first.
- If the project uses Tailwind, check the version (v3 vs v4) before modifying config.
- If the project has no framework, use vanilla CSS.
- Keep changes reviewable and focused. Small, targeted improvements over big rewrites.
