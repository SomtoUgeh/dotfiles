---
name: technical-svg-diagrams
description: Generate clean, minimal technical SVG diagrams in a consistent Cloudflare-inspired style. Use when creating architecture diagrams, flow diagrams, or component diagrams for blog posts and documentation.
---

<objective>
Generate technical SVG diagrams with consistent styling for blog posts and documentation. Use an accessible text description alongside the SVG, or a title/description and accessible name for meaningful inline diagrams. Do not rely on color alone. All diagrams use a unified visual language: grid backgrounds, monospace fonts, muted colors with semantic accents, and clean geometric shapes.
</objective>

<quick_start>
1. Identify diagram type needed (architecture, flow, or component)
2. Read `references/svg-patterns.md` for templates and color palette
3. Generate SVG using the established patterns
4. Save to target directory with descriptive filename
5. Export only when requested, using an available browser screenshot tool or `cairosvg`
</quick_start>

<design_system>
## Color Palette

| Purpose | Color | Hex |
|---------|-------|-----|
| Background | Light gray | #fafafa |
| Grid lines | Subtle gray | #e5e5e5 |
| Primary text | Dark gray | #333 |
| Secondary text | Medium gray | #666 |
| Muted text | Gray | #666 |
| Borders/arrows | Gray | #ccc |
| Success/positive | Green | #27ae60 |
| Error/negative | Red | #e74c3c |
| Primary accent | Blue | #3498db |
| Warning/sandbox | Orange | #f39c12 |
| Process step | Purple | #9b59b6 |

## Typography

- **Font family:** `monospace` for all text
- **Title:** 14px bold, #333
- **Subtitle/tag:** 12px, #666, in brackets `[ LIKE_THIS ]`
- **Labels:** 10-11px, color matches element
- **Notes:** size for the final display/export; aim for readable text rather than shrinking meaningful content to 7–8px. Verify contrast on the final background.

## Common Elements

**Grid background:**
```xml
<pattern id="grid" width="20" height="20" patternUnits="userSpaceOnUse">
  <path d="M 20 0 L 0 0 0 20" fill="none" stroke="#e5e5e5" stroke-width="0.5"/>
</pattern>
```

**Arrow marker:**
```xml
<marker id="arrow" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
  <path d="M0,0 L0,6 L9,3 z" fill="#ccc"/>
</marker>
```

**Node (circle with inner dot):**
```xml
<circle cx="X" cy="Y" r="35" fill="none" stroke="#ccc" stroke-width="2"/>
<circle cx="X" cy="Y" r="18" fill="#COLOR"/>
```

**Box container:**
```xml
<rect x="X" y="Y" width="W" height="H" fill="none" stroke="#ccc" stroke-width="2"/>
```

**Dashed container (sandbox/isolation):**
```xml
<rect x="X" y="Y" width="W" height="H" fill="none" stroke="#f39c12" stroke-width="2" stroke-dasharray="5,3"/>
```

**Label box:**
```xml
<rect x="X" y="Y" width="W" height="H" fill="none" stroke="#ccc" stroke-width="1"/>
<text x="CX" y="CY" font-family="monospace" font-size="11" fill="#666" text-anchor="middle">LABEL_NAME</text>
```
</design_system>

<diagram_types>
## Architecture Diagrams

Horizontal left-to-right flow showing system components.

**Use for:** Before/after comparisons, system overviews, data flow

**Structure:**
- Title + tag at top left
- Components flow left to right
- Arrows connect components
- Bottom note summarizes key point

**Dimensions:** 800x350 to 800x400

## Flow Diagrams

Vertical top-to-bottom showing process steps.

**Use for:** Execution flows, request lifecycles, step-by-step processes

**Structure:**
- Title + tag at top
- Dashed vertical guide line
- Steps connected by arrows with polygon heads
- Decision diamonds for branching
- Ellipses for start/end states

**Dimensions:** 600x700 (adjust height for steps)

## Component Diagrams

Focused view of a single component's internals.

**Use for:** Showing internal structure, nested elements, detailed breakdowns

**Structure:**
- Outer container box
- Inner elements with semantic colors
- Labels above or below containers
</diagram_types>

<process>
## Creating a Diagram

1. **Determine type and dimensions**
   - Architecture: 800x350-400, horizontal
   - Flow: 600x700+, vertical
   - Component: varies by content

2. **Set up SVG structure**
   ```xml
   <svg viewBox="0 0 WIDTH HEIGHT" xmlns="http://www.w3.org/2000/svg">
     <defs>
       <!-- Grid pattern -->
       <!-- Arrow markers as needed -->
     </defs>

     <!-- Background -->
     <rect width="WIDTH" height="HEIGHT" fill="#fafafa"/>
     <rect width="WIDTH" height="HEIGHT" fill="url(#grid)"/>

     <!-- Title -->
     <text x="40" y="40" font-family="monospace" font-size="14" fill="#333" font-weight="bold">TITLE</text>
     <text x="X" y="40" font-family="monospace" font-size="12" fill="#666">[ TAG ]</text>

     <!-- Content -->

     <!-- Bottom note -->
     <text x="CENTER" y="BOTTOM" font-family="monospace" font-size="10" fill="#666" text-anchor="middle">summary note</text>
   </svg>
   ```

3. **Add components using patterns from references/svg-patterns.md**

4. **Connect with arrows**
   - Solid lines for primary flow
   - Dashed lines for secondary/return flow
   - Use opacity="0.5" for response arrows

5. **Add labels**
   - Component names in SCREAMING_SNAKE_CASE
   - Action labels in lowercase_snake_case
   - Use text-anchor="middle" for centered text

6. **Save with descriptive filename**
   - `diagram-before.svg`, `diagram-after.svg`
   - `diagram-flow.svg`, `diagram-architecture.svg`
</process>

<success_criteria>
Diagram is complete when:
- [ ] Uses consistent color palette
- [ ] All text is monospace
- [ ] Grid background applied
- [ ] Title with bracketed tag present
- [ ] Components properly connected with arrows
- [ ] Labels are clear and properly positioned
- [ ] Bottom summary note included
- [ ] SVG is valid and renders correctly
- [ ] Exported to PNG or WebP if raster output requested
</success_criteria>

<export>
## Export Formats

After creating the SVG, export to raster formats as needed.

### PNG via browser automation

Use an available browser automation surface for pixel-accurate rendering. If the active runtime has no browser tool or `agent-browser` executable, use the `cairosvg` route below rather than stopping or installing a new tool.

**Step 1: Create HTML wrapper**
```bash
# Resolve this to the directory of the loaded skill, not the current project.
SVG_SKILL_DIR="/path/to/loaded/technical-svg-diagrams"
SVG_CAPTURE_DIR="$(mktemp -d)"
bun run "$SVG_SKILL_DIR/scripts/create-html.ts" --svg diagram.svg --output "$SVG_CAPTURE_DIR/diagram.html" --width 1600
```

Options:
- `--padding <px>` — non-negative padding around SVG (default: 40; zero supported)
- `--width <px>` — rendered SVG width (default: 1600)
- `--background <color>` — hex, named, rgb(), or hsl() override for the detected background

Use self-contained SVGs with embedded assets. The wrapper uses SVG image mode, so scripts do not execute and external resources are unavailable. Inspect the actual raster; the background detector handles root styles and full-canvas rectangles, not arbitrary SVG paint/compositing. Use an explicit background for complex art. Bun or modern Node with TypeScript type stripping runs the script; use an already installed runtime.

**Step 2: Capture high-resolution PNG**
```bash
# Load agent-browser's installed core skill first; use a unique task session.
SVG_CAPTURE_SESSION="svg-capture-$$"
agent-browser --session "$SVG_CAPTURE_SESSION" open "file://$SVG_CAPTURE_DIR/diagram.html"
agent-browser --session "$SVG_CAPTURE_SESSION" set viewport 1800 1200
agent-browser --session "$SVG_CAPTURE_SESSION" wait --fn 'document.querySelector("img").complete && document.querySelector("img").naturalWidth > 0'
agent-browser --session "$SVG_CAPTURE_SESSION" screenshot .container diagram.png
agent-browser --session "$SVG_CAPTURE_SESSION" close
```

**Step 3: Clean up**
```bash
rm "$SVG_CAPTURE_DIR/diagram.html"
rmdir "$SVG_CAPTURE_DIR"
```

### WebP via cairosvg

Lightweight, no browser needed. Best when agent-browser is unavailable.

```bash
uvx --from cairosvg cairosvg diagram.svg -o diagram.png --output-width 1600
uv run --with pillow python -c "from PIL import Image; Image.open('diagram.png').save('diagram.webp', 'WEBP', lossless=True)"
rm diagram.png
```
Use `lossless=True` when exact edges and text matter. Compare output size if download weight matters; lossless is not universally smaller than lossy WebP.

**Alternative tools (if available):**
```bash
# ImageMagick
convert -background none -density 150 diagram.svg diagram.webp

# librsvg + cwebp
rsvg-convert -w 1600 diagram.svg -o diagram.png && cwebp diagram.png -o diagram.webp
```

**Platform notes:**
- macOS: `brew install cairo` if cairosvg fails
- Linux: `apt install libcairo2-dev` if needed
</export>
