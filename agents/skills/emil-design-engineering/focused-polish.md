# Focused Polish

Use this mode when a component or small interface region works but feels
visually or interactively off. Diagnose the cause before changing values. Keep
the pass consistent with the product's existing tokens and primitives.

## Work locally

Inspect the component in its real context and states: default, hover, pressed,
focus-visible, disabled, loading, error, and selected where relevant. Check its
smallest supported viewport, dark theme, and touch input. If the problem comes
from a shared token or primitive, fix that source rather than compensating in
one caller.

Prioritize the details people notice together:

1. geometry and spacing
2. typography and wrapping
3. surface hierarchy
4. state feedback and hit area
5. motion, only when it clarifies the state change

## Geometry and optical alignment

### Concentric radii

For closely nested rounded surfaces, start with:

```text
outer radius = inner radius + inset between them
```

For example, an inner radius of `12px` inside `8px` padding suggests a `20px`
outer radius. Treat this as a geometric starting point and inspect the rendered
result. When layers are visually separate, choose their radii independently.

### Align by visual weight

Geometric centering can look wrong for asymmetric icons. Nudge play triangles,
carets, arrows, and icon-and-label groups by a pixel or two when inspection
shows an imbalance. Prefer fixing an SVG's view box or path when the same icon
needs compensation everywhere; use local spacing when the imbalance belongs to
one composition.

For a trailing icon in a labelled button, slightly less padding on the icon side
can balance its visual weight. Start with a `1px` or `2px` difference and tune it
with the actual font and icon instead of treating the value as universal.

## Surfaces

### Rings, shadows, and borders

Use a low-opacity ring plus small layered shadows when a card or button needs
both an edge and elevation:

```css
.surface {
  box-shadow:
    0 0 0 1px rgb(0 0 0 / 0.06),
    0 1px 2px -1px rgb(0 0 0 / 0.06),
    0 2px 4px rgb(0 0 0 / 0.04);
}
```

In dark themes, a quiet light ring often reads more clearly than several dark
shadows. Use borders for dividers, dense table structure, and input outlines
when the edge conveys structure or state. Do not replace every border with a
shadow.

### Image outlines

An inset, low-opacity outline can keep images legible against similar
backgrounds without changing layout:

```css
.image {
  outline: 1px solid rgb(0 0 0 / 0.1);
  outline-offset: -1px;
}
```

Adapt the color for the theme and skip it when the image already has a strong
edge or the treatment conflicts with the product's visual language.

## Typography

- Apply font smoothing once at the application root when it improves the chosen
  typeface on macOS; verify the weight rather than assuming thinner is better.
- Use `text-wrap: balance` for short headings and `text-wrap: pretty` for body
  copy where supported. Inspect the result and use an intentional line break
  when automatic balancing produces an awkward shape.
- Use `font-variant-numeric: tabular-nums` for changing values and aligned
  numeric columns. Check the font because tabular glyphs can change the visual
  width and shape of digits.
- Keep font weight stable across hover and selected states when a weight change
  would shift layout.

## Interaction details

Specify only the properties that change:

```css
.button {
  transition:
    scale 150ms ease-out,
    background-color 150ms ease-out;
}
```

Avoid `transition: all`. Add `will-change` only after a trace or visible first
frame problem justifies the extra layer, and remove it when the element is no
longer animation-sensitive.

A small press scale can make a control feel responsive. Values around
`0.96`-`0.98` are a useful starting range, but omit the effect when it conflicts
with the product's motion language, the control is used constantly, or reduced
motion calls for a non-spatial response.

For interactive state changes, prefer an interruptible transition that can
retarget when intent changes. Use staged keyframes for sequences that are meant
to run once. For an occasional first-entry sequence, split the content into
semantic groups and use a restrained stagger instead of animating one large
container. Keep exits quieter than entrances.

For an icon swap, reuse an installed motion library when it already earns its
bundle cost; otherwise keep both icons in the DOM and cross-fade them with CSS.
Do not add a motion dependency for one small transition. With Motion for React,
use `initial={false}` on `AnimatePresence` only when the default state should be
present on first paint; keep the initial animation when the entrance itself is
intentional.

For animation direction or implementation, use the focused motion skills:

- `animate` for motion decisions and planning
- `css-animations` for CSS implementation
- `motion-react` for Motion for React
- `animation-performance` for measured jank or compositor questions
- `animation-accessibility` for reduced-motion behavior

## Pointer target sizes

Use the standards precisely:

- [WCAG 2.2 Success Criterion 2.5.8](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum)
  is the Level AA baseline: a pointer target is at least `24px` by `24px` in CSS
  pixels, or it satisfies one of the criterion's spacing or other exceptions.
- [WCAG 2.2 Success Criterion 2.5.5](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced)
  sets a `44px` by `44px` Level AAA enhanced target, with its own exceptions.
- For touch-heavy web controls, aim for a `44px` by `44px` hit area as a
  comfortable design target. Platform units differ; for example,
  [Apple's accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility)
  specifies points for Apple platform controls.

The visible glyph can remain smaller than the hit area. Enlarge the actual
button or its clickable pseudo-element, associate labels with compact form
controls, and keep neighboring hit areas from overlapping. Do not describe
`44px` as the WCAG Level AA minimum.

## Focused review

- Nested surfaces have intentional radii and spacing.
- Icons and labels look optically aligned at actual size.
- Borders, rings, and shadows express the intended hierarchy.
- Text wraps cleanly and changing numbers do not shift nearby content.
- Every interactive state remains legible in light and dark themes.
- Pointer targets meet the WCAG baseline and touch controls aim for the larger
  design target.
- Motion is interruptible, reduced-motion aware, and routed to the relevant
  specialist when it needs more than a local adjustment.
