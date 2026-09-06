---
name: web-typography
description: Design or review typography for prose-heavy web pages, articles, documentation, and reading interfaces. Use when type scale, line length, leading, font choice, or reading comfort is a central part of the request; skip for routine UI text changes.
---

# Web Typography

Treat typography as part of the product's existing visual system. These are starting points, not universal laws; tune them for the chosen typeface, language, content, viewport, and user preferences.

## Reading measure and size

- Long-form body text usually works around 45–75 characters per line. Start near `65ch` and inspect real content.
- Keep body text at least `1rem` unless the design system and accessibility testing justify another value.
- Preserve browser text-size preferences with `rem` font sizes and unitless line-height.
- Do not shrink mobile body text merely to preserve a desktop line length.

```css
.prose {
  max-width: 65ch;
  font-size: 1rem;
  line-height: 1.5;
}
```

Apply width constraints to the reading container itself. Avoid broad selectors such as `main > *` that can unexpectedly constrain application layout.

## Leading and vertical rhythm

Useful starting ranges:

| Content | Line height |
| --- | --- |
| Long-form body text | 1.4–1.65 |
| Short UI text | 1.2–1.4 |
| Large headings | 1.0–1.25 |
| Small captions | 1.4–1.7 |

Long lines, small type, and reversed text often need more leading. Headings usually need less. Use a small spacing scale for paragraph and heading margins; exact baseline-grid multiples are optional on responsive screens.

## Paragraphs and alignment

- Use paragraph spacing or indentation, usually not both.
- Do not indent the opening paragraph after a heading.
- Flush-left, ragged-right text is the dependable default for Latin-script prose.
- If justified text is required, test it in every supported language and viewport. `hyphens: auto` requires a correct `lang` attribute and browser dictionary support.
- Keep poetry, code, and other line-sensitive content out of justification.

## Letter spacing and font features

- Let the font's kerning tables work; avoid manual tracking on body text.
- Modest positive tracking can help all-caps labels, but inspect the actual face.
- Use real small-cap, old-style numeral, and tabular numeral features only when the selected font contains them and the content benefits.
- Do not use `scaleX()` to fake condensed or expanded letterforms.

```css
.all-caps-label {
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.numeric-table {
  font-variant-numeric: tabular-nums lining-nums;
}
```

Do not globally transform every `<abbr>` into small caps or remove its affordance. Abbreviations, product names, and mixed-case initialisms need content-aware treatment.

## Type scale

Use a small, named scale instead of scattered arbitrary values. A modular ratio is one option; optical adjustment is expected.

```css
:root {
  --text-sm: 0.875rem;
  --text-base: 1rem;
  --text-lg: 1.25rem;
  --text-xl: 1.75rem;
  --text-2xl: 2.5rem;
}
```

Keep captions and code readable. Avoid applying relative font-size reduction to both a container and its nested child:

```css
pre {
  font-size: 0.875rem;
  line-height: 1.6;
}

pre code {
  font-size: inherit;
}

:not(pre) > code {
  font-size: 0.875em;
}
```

## Wrapping and punctuation

- `text-wrap: balance` can improve short headings; `text-wrap: pretty` can improve prose where supported. Verify the resulting layout and performance on long documents.
- Use typographically correct punctuation when authoring prose, while preserving exact user input, identifiers, code, URLs, and data.
- Use non-breaking spaces sparingly where a line break would change meaning, such as a number and unit.
- Set the document language accurately; do not hardcode `lang="en"` for multilingual content.

## Font loading

When adding web fonts, include loading behavior in the design decision:

- choose subsets and weights actually used;
- define useful fallbacks and metric overrides when layout shift matters;
- preload only critical fonts;
- test fallback, slow-network, and user-font-size states.

Avoid copying a generic font stack into an established product without checking its design tokens and licensing.

## Review checklist

- Reading container has an intentional measure.
- Body and small text remain readable at supported zoom and viewport sizes.
- Heading hierarchy is visible and semantic.
- Line height matches size, measure, and typeface.
- Links and abbreviations retain recognizable affordances.
- Code, tables, numerals, and multilingual text use appropriate features.
- Font loading does not cause avoidable layout shift or invisible text.
- Rules are scoped to the intended content instead of global structural selectors.

When reporting findings, cite the concrete selector and `file:line`; explain the reading or layout effect rather than enforcing a number without context.

## Sources

Principles are informed by Richard Rutter's *The Elements of Typographic Style Applied to the Web*, the U.S. Web Design System, and modern CSS specifications. Do not reproduce licensed source text beyond what the task permits.
