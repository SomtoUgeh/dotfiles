---
name: web-typography
description: >
  Apply professional typographic principles when creating web pages, components, stylesheets,
  or any HTML/CSS output. Use this skill whenever generating or reviewing CSS that involves
  text styling, layout of reading content, font sizing, spacing, or any UI where readable
  prose matters. Triggers include: requests for "good typography", "readable text", "type scale",
  styling body copy, blog layouts, article pages, documentation sites, landing pages with prose,
  email templates, or any review of typographic quality in existing CSS/HTML.
---

# Web Typography Skill

A definitive guide for producing excellent typography on the web, distilled from Robert
Bringhurst's *The Elements of Typographic Style* as applied to the web by Richard Rutter,
and supplemented with modern CSS best practices.

**When to consult this skill:** Any time you write or review CSS/HTML that involves readable
text — body copy, articles, documentation, blogs, email, or prose-heavy UI.

---

## 1. Horizontal Rhythm — Word & Letter Spacing

### 1.1 Word Spacing

The ideal word space is approximately 0.25 em, but varies by typeface. Loosely fitted or
bold faces need wider word spaces; tighter faces need narrower ones.

```css
/* Increase word spacing for a loose face */
p.loose-face {
  word-spacing: 0.05em;
}

/* Tighten word spacing for a display heading */
h1 {
  word-spacing: -0.02em;
}
```

**Always specify `word-spacing` in `em`** so it scales proportionally with font size.

### 1.2 Single Word Space Between Sentences

Use exactly one space between sentences — never two. HTML collapses all whitespace to a
single space automatically, so this is handled by default. Never insert `&nbsp;&nbsp;` or
extra spacing between sentences.

### 1.3 Strings of Initials

Add little or no extra space within strings of initials (e.g., J.F.K., U.S.A.). The
periods provide sufficient separation. Use a normal word space after the final period.

### 1.4 Letterspace All-Caps and Small Caps

**Strings of capital letters and small caps must always be letterspaced.** Without it,
capitals crowd together and become harder to read.

```css
/* Abbreviations and acronyms in small caps */
abbr,
.small-caps {
  font-variant-caps: all-small-caps;
  letter-spacing: 0.05em; /* 5–10% of type size */
}

/* Any text in all-caps */
.all-caps,
.uppercase {
  text-transform: uppercase;
  letter-spacing: 0.06em;
}
```

The recommended range is **5–10% of type size** (0.05em–0.1em). Always use `em` units.

### 1.5 Don't Letterspace Lowercase

Lowercase letters are designed to fit together without tracking adjustments. Never
letterspace body text. The only exceptions are very bold condensed faces used at large
display sizes, where a small amount (0.01em–0.02em) may improve legibility.

### 1.6 Kerning

Enable font kerning and let the typeface designer's kerning tables do their work. Don't
override kerning without a specific reason.

```css
body {
  font-kerning: auto;
  /* Or explicitly: */
  font-feature-settings: "kern" 1;
}
```

Kern consistently and modestly — or not at all.

### 1.7 Don't Alter Letter Widths or Shapes

Never use `transform: scaleX()` or `font-stretch` to artificially compress or expand
letterforms. If you need a condensed or extended face, choose a typeface that was designed
that way.

### 1.8 Don't Stretch the Space Until It Breaks

Avoid justified text on the web unless you also enable hyphenation. Without hyphenation,
justified text produces "rivers" of white space — ugly, uneven gaps between words.

---

## 2. Measure (Line Length)

This is one of the most impactful typographic decisions you will make.

### The Rule

| Context              | Characters per line | CSS approximation |
|----------------------|--------------------|-------------------|
| Single column prose  | **45–75** (ideal: **66**) | `max-width: 33em` or `max-width: 66ch` |
| Multi-column text    | **40–50**          | `max-width: 25em` |
| Short companion text | **30–40**          | `max-width: 20em` |

### Implementation

```css
/* Best: use ch unit (width of the "0" glyph) */
article,
.prose {
  max-width: 66ch;
}

/* Good alternative: em-based (1 char ≈ 0.5em) */
.content {
  max-width: 33em;
}
```

**Why `ch` or `em` over `px`?** Elastic widths ensure the measure remains stable when
readers change their text size. A `px`-based width changes the character count when text
is resized; `em` and `ch` do not.

**Never let body text run to the full viewport width.** Lines exceeding 80 characters are
uncomfortable to read because the eye struggles to track back to the next line start.

### Responsive Considerations

On small screens, the screen width naturally constrains measure. Don't reduce font size
just to preserve an "ideal" measure — prioritise readable font size (minimum 16px) and
accept a shorter measure on mobile (even down to 25–35 characters is fine for handheld
devices). Adjust line-height to compensate (see §3).

---

## 3. Vertical Rhythm — Leading (Line Height)

### 3.1 Choose a Basic Leading

```css
/* Good defaults for body text */
body {
  line-height: 1.4;  /* Minimum for comfortable reading */
}

/* Common comfortable range */
.prose {
  line-height: 1.5;  /* This page-like feel works well for most text */
}
```

**General guidance:**

| Situation                      | line-height   |
|-------------------------------|---------------|
| Body text, long-form reading   | **1.4–1.6**  |
| Short text, UI labels          | **1.2–1.4**  |
| Large headings                 | **1.0–1.2**  |
| Small / caption text           | **1.5–1.8**  |

**Key relationships:**
- Longer lines (wider measure) need **more** line-height.
- Shorter lines need **less** line-height.
- Larger text needs **less** line-height.
- Smaller text needs **more** line-height.
- Light or reversed text (white on black) needs more line-height.

**Always use a unitless multiplier** (e.g., `1.5`, not `1.5em` or `24px`) so
line-height scales correctly with font-size changes.

### 3.2 Add and Delete Vertical Space in Measured Intervals

Maintain vertical rhythm by keeping all vertical spacing as **multiples of the base
line-height.** Headings, blockquotes, images, and other intrusions into the text should
return the text to its baseline rhythm.

```css
:root {
  --base-size: 1rem;      /* 16px default */
  --base-lh: 1.5;         /* line-height multiplier */
  --rhythm: calc(var(--base-size) * var(--base-lh)); /* 24px */
}

p {
  font-size: var(--base-size);
  line-height: var(--base-lh);
  margin-top: 0;
  margin-bottom: var(--rhythm);
}

h2 {
  font-size: 1.5rem;
  line-height: 1.3;
  /* Margins should combine to a multiple of the base rhythm */
  margin-top: calc(var(--rhythm) * 2);    /* 2 lines above */
  margin-bottom: var(--rhythm);           /* 1 line below */
}

blockquote {
  margin-top: var(--rhythm);
  margin-bottom: var(--rhythm);
  padding-left: 1.5em;
}
```

When text size changes (headings, sidenotes), adjust line-height so each element
occupies a whole multiple of the base rhythm unit.

---

## 4. Blocks & Paragraphs

### 4.1 Opening Paragraphs: Flush Left

The first paragraph of any section — after a heading, after the start of the document —
should be set flush left with no indent. An indent signals continuation; there is nothing
to continue from at the very beginning.

### 4.2 Subsequent Paragraphs: Indent or Space — Not Both

Choose ONE method to separate paragraphs:

**Option A — Indentation (traditional/print feel):**
```css
p {
  margin: 0;
}

p + p {
  text-indent: 1.5em; /* At least 1em; often matches line-height */
}

/* Never indent after headings */
h1 + p,
h2 + p,
h3 + p,
h4 + p,
h5 + p,
h6 + p {
  text-indent: 0;
}
```

**Option B — Block paragraphs with vertical space (common web convention):**
```css
p {
  margin-top: 0;
  margin-bottom: 1.5em; /* Equal to line-height for rhythm */
}
```

Using both an indent AND vertical space is redundant and creates awkward gaps.

### 4.3 Block Quotations

Add extra vertical space (equal to the line-height) before and after block quotations.
Indent from the left, and optionally from the right. Do NOT reduce the font size of block
quotes unless they are genuinely secondary (like footnotes).

```css
blockquote {
  margin: 1.5em 0;      /* Vertical space matches rhythm */
  padding-left: 1.5em;  /* Indent from left */
  padding-right: 1.5em;
  border-left: 3px solid currentColor;
  opacity: 0.85;
}
```

### 4.4 Verse and Poetry

Centre verse quotations on the longest line, or indent them. Set flush left with
ragged right. Never justify poetry.

---

## 5. Alignment & Justification

### Default: Flush Left (Ragged Right)

For virtually all web text, use `text-align: left`. This is the most readable alignment
because word spacing remains consistent and readers can easily find the start of each line.

```css
body {
  text-align: left;
}
```

### Justified Text — Only With Hyphenation

If you must justify, enable CSS hyphenation to prevent rivers of whitespace:

```css
.justified {
  text-align: justify;
  hyphens: auto;
  -webkit-hyphens: auto;
  hyphenate-limit-chars: 6 3 2; /* min word length, chars before break, chars after */
  hyphenate-limit-lines: 3;     /* Max consecutive hyphenated lines */
  hyphenate-limit-zone: 8%;
}

/* Never justify the last line */
.justified {
  text-align-last: left;
}
```

**Important hyphenation rules:**
- Leave at least **2 characters** before the break and **3 characters** after.
- Never allow more than **3 consecutive hyphenated lines**.
- Set the `lang` attribute on your `<html>` element — browsers need it for correct
  hyphenation dictionaries.

### Non-Breaking Spaces

Use `&nbsp;` to prevent breaks within short numerical and mathematical expressions:

```html
<!-- Good: keeps number and unit together -->
<p>The sample weighed 3.5&nbsp;kg and measured 10&nbsp;cm.</p>

<!-- Good: keeps date components together -->
<p>On 1&nbsp;January&nbsp;2026, the policy takes effect.</p>
```

---

## 6. Type Scale — Don't Compose Without a Scale

Use a modular scale to create harmonious size relationships. The traditional typographic
scale (developed over 400 years) provides time-tested intervals.

### Classic Modular Scales

| Scale name        | Ratio  | Sequence (base 16px)                   |
|-------------------|--------|----------------------------------------|
| Minor Third       | 1.2    | 16, 19.2, 23, 27.6, 33.2              |
| Major Third       | 1.25   | 16, 20, 25, 31.3, 39                  |
| Perfect Fourth    | 1.333  | 16, 21.3, 28.4, 37.9, 50.5            |
| Augmented Fourth  | 1.414  | 16, 22.6, 32, 45.3                     |
| Perfect Fifth     | 1.5    | 16, 24, 36, 54                         |
| Golden Ratio      | 1.618  | 16, 25.9, 41.9, 67.8                   |

### Implementation with CSS Custom Properties

```css
:root {
  --scale-ratio: 1.25;    /* Major Third */
  --base-size: 1rem;       /* 16px */

  --size-sm:  calc(var(--base-size) / var(--scale-ratio));         /* 0.8rem / ~13px */
  --size-base: var(--base-size);                                    /* 1rem / 16px */
  --size-md:  calc(var(--base-size) * var(--scale-ratio));          /* 1.25rem / 20px */
  --size-lg:  calc(var(--base-size) * var(--scale-ratio) * var(--scale-ratio));  /* 1.563rem / 25px */
  --size-xl:  calc(var(--base-size) * var(--scale-ratio) * var(--scale-ratio) * var(--scale-ratio));  /* 1.953rem / ~31px */
  --size-2xl: calc(var(--base-size) * var(--scale-ratio) * var(--scale-ratio) * var(--scale-ratio) * var(--scale-ratio)); /* 2.441rem / ~39px */
}

body  { font-size: var(--size-base); }
small, .caption { font-size: var(--size-sm); }
h4    { font-size: var(--size-md); }
h3    { font-size: var(--size-lg); }
h2    { font-size: var(--size-xl); }
h1    { font-size: var(--size-2xl); }
```

### Body Text Minimum Size

- **Desktop:** 16px minimum (1rem). 18px–20px is increasingly common and improves
  readability.
- **Mobile:** 16px minimum. Never go below 14px. Larger is almost always better.

Use `rem` for font sizes to respect user preferences. Set a percentage on the body to
establish the base:

```css
body {
  font-size: 100%; /* Respects user's browser setting, typically 16px */
}
```

---

## 7. Numerals, Capitals & Small Caps

### 7.1 Old-Style (Text) vs. Lining (Titling) Figures

| Context                          | Figure style     | CSS                                |
|----------------------------------|------------------|------------------------------------|
| Running body text                | Old-style        | `font-variant-numeric: oldstyle-nums` |
| Headings in ALL CAPS / Title Case| Lining           | `font-variant-numeric: lining-nums`   |
| Tables and data                  | Tabular lining   | `font-variant-numeric: lining-nums tabular-nums` |

```css
/* Body text: old-style figures blend with lowercase */
.prose {
  font-variant-numeric: oldstyle-nums proportional-nums;
}

/* Tables: tabular lining figures for vertical alignment */
table {
  font-variant-numeric: lining-nums tabular-nums;
}

/* Headings in caps: lining figures to match */
h1, h2, h3 {
  font-variant-numeric: lining-nums;
}
```

**Note:** Many system and web fonts only ship lining figures. If old-style figures are
important to your design, choose a typeface that includes them (e.g., Georgia, Palatino,
EB Garamond, Source Serif Pro, Literata).

### 7.2 Abbreviations and Acronyms in Small Caps

In running text, abbreviations like NASA, HTML, CSS should ideally be set in **spaced
small caps** so they don't shout amid lowercase text.

```css
abbr[title] {
  font-variant-caps: all-small-caps;
  letter-spacing: 0.05em;
  text-decoration: none;      /* Remove default underline */
}
```

**True small caps vs. fake small caps:** `font-variant-caps: all-small-caps` will use
genuine small cap glyphs if the font includes them. Never simulate small caps by scaling
down capitals — the stroke weight will be too thin.

---

## 8. Typographic Details Checklist

Apply these micro-typographic refinements in every project:

### Punctuation & Symbols

| Instead of…           | Use…                    | HTML entity / character |
|-----------------------|-------------------------|------------------------|
| Straight quotes `" '` | Curly quotes `" " ' '`  | `&ldquo; &rdquo; &lsquo; &rsquo;` |
| Hyphen for ranges `-` | En dash `–`             | `&ndash;`              |
| Double hyphen `--`    | Em dash `—`             | `&mdash;`              |
| Three dots `...`      | Ellipsis `…`            | `&hellip;`             |
| `x` for multiply      | Multiplication sign `×` | `&times;`              |
| `(c)` for copyright   | `©`                     | `&copy;`               |

### Hanging Punctuation (Progressive Enhancement)

```css
.prose {
  hanging-punctuation: first allow-end;
}
```

This optically aligns the left edge of text by letting punctuation (quotes, hyphens) hang
into the margin. Browser support is limited to Safari as of 2025, but it is a safe
progressive enhancement.

### Font Smoothing

```css
body {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
}
```

`optimizeLegibility` enables kerning and ligatures in browsers that support it, but can
cause performance issues with very large amounts of text. Use `optimizeSpeed` for long
documents if rendering performance is a concern.

### Ligatures

```css
body {
  font-variant-ligatures: common-ligatures;
  /* Enables fi, fl, ff, ffi, ffl ligatures when available */
}
```

### Widows and Orphans

CSS has `widows` and `orphans` properties for paged media (print stylesheets). For
screen, the newer `text-wrap: pretty` provides some control:

```css
.prose {
  text-wrap: pretty; /* Avoids single-word last lines where possible */
}

h1, h2, h3 {
  text-wrap: balance; /* Balances line lengths in multi-line headings */
}
```

---

## 9. Complete Starter Stylesheet

Here is a production-ready base typography stylesheet applying all the principles above:

```css
/* ==========================================================================
   Base Typography — Applying The Elements of Typographic Style to the Web
   ========================================================================== */

:root {
  /* Scale: Major Third (1.25) */
  --ratio: 1.25;
  --base: 1rem;

  /* Type scale */
  --size-sm:   0.8rem;
  --size-base: 1rem;
  --size-md:   1.25rem;
  --size-lg:   1.563rem;
  --size-xl:   1.953rem;
  --size-2xl:  2.441rem;
  --size-3xl:  3.052rem;

  /* Vertical rhythm */
  --lh: 1.5;
  --rhythm: calc(var(--base) * var(--lh));

  /* Measure */
  --measure: 66ch;
  --measure-narrow: 45ch;
  --measure-wide: 80ch;
}

/* --- Reset & Base -------------------------------------------------------- */

*,
*::before,
*::after {
  box-sizing: border-box;
}

html {
  font-size: 100%;                         /* Respect user preference */
  -webkit-text-size-adjust: 100%;
}

body {
  font-family: "Source Serif 4", Georgia, "Times New Roman", serif;
  font-size: var(--size-base);
  line-height: var(--lh);
  font-kerning: auto;
  font-variant-ligatures: common-ligatures;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  color: #1a1a1a;
  background-color: #fafaf8;
}

/* --- Measure ------------------------------------------------------------- */

article,
.prose,
main > *:not(.full-width) {
  max-width: var(--measure);
}

/* --- Paragraphs ---------------------------------------------------------- */

p {
  margin-top: 0;
  margin-bottom: var(--rhythm);
  hanging-punctuation: first allow-end;
  text-wrap: pretty;
}

/* --- Headings ------------------------------------------------------------ */

h1, h2, h3, h4, h5, h6 {
  font-variant-numeric: lining-nums;
  text-wrap: balance;
  margin-top: calc(var(--rhythm) * 2);
  margin-bottom: var(--rhythm);
}

h1 {
  font-size: var(--size-3xl);
  line-height: 1.1;
  margin-top: 0;
}

h2 {
  font-size: var(--size-2xl);
  line-height: 1.2;
}

h3 {
  font-size: var(--size-xl);
  line-height: 1.25;
}

h4 {
  font-size: var(--size-lg);
  line-height: 1.3;
}

/* First paragraph after heading: no indent, no extra space */
h1 + p,
h2 + p,
h3 + p,
h4 + p,
h5 + p,
h6 + p {
  margin-top: 0;
}

/* --- Blockquotes --------------------------------------------------------- */

blockquote {
  margin: var(--rhythm) 0;
  padding-left: 1.5em;
  border-left: 3px solid currentColor;
  font-style: italic;
}

blockquote > p:last-child {
  margin-bottom: 0;
}

/* --- Lists --------------------------------------------------------------- */

ul, ol {
  margin-top: 0;
  margin-bottom: var(--rhythm);
  padding-left: 1.5em;
}

li {
  margin-bottom: calc(var(--rhythm) * 0.25);
}

/* --- Inline elements ----------------------------------------------------- */

abbr[title] {
  font-variant-caps: all-small-caps;
  letter-spacing: 0.05em;
  text-decoration: none;
  cursor: help;
}

.uppercase,
.all-caps {
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

strong {
  font-weight: 600;
}

/* --- Numerals ------------------------------------------------------------ */

.prose {
  font-variant-numeric: oldstyle-nums proportional-nums;
}

table {
  font-variant-numeric: lining-nums tabular-nums;
}

/* --- Small / Caption text ------------------------------------------------ */

small,
.caption,
figcaption {
  font-size: var(--size-sm);
  line-height: 1.6;       /* Smaller text needs more leading */
}

/* --- Code ---------------------------------------------------------------- */

pre, code {
  font-size: 0.875em;
  line-height: 1.6;
}

/* --- Horizontal rule (section break) ------------------------------------- */

hr {
  border: none;
  border-top: 1px solid currentColor;
  opacity: 0.2;
  margin: calc(var(--rhythm) * 2) 0;
}

/* --- Links --------------------------------------------------------------- */

a {
  color: inherit;
  text-decoration-color: currentColor;
  text-decoration-thickness: 1px;
  text-underline-offset: 0.15em;
}

a:hover {
  text-decoration-thickness: 2px;
}

/* --- Print --------------------------------------------------------------- */

@media print {
  body {
    font-size: 12pt;
    line-height: 1.4;
    color: #000;
    background: #fff;
  }

  p {
    widows: 3;
    orphans: 3;
  }

  h1, h2, h3 {
    page-break-after: avoid;
  }
}
```

---

## 10. Quick-Reference Decision Guide

When producing any web typography, run through this checklist:

1. **Measure set?** Body text constrained to 45–75 characters (`max-width: 66ch`).
2. **Font size readable?** Minimum 16px / 1rem for body text.
3. **Line-height comfortable?** 1.4–1.6 for body; tighter for headings; looser for small text.
4. **Vertical rhythm maintained?** All margins and padding are multiples of base line-height.
5. **Type scale consistent?** Sizes drawn from a modular scale, not arbitrary values.
6. **Alignment appropriate?** Left-aligned by default; justified only with `hyphens: auto`.
7. **Caps letterspaced?** All-caps and small-caps text has `letter-spacing: 0.05em`+.
8. **Lowercase NOT letterspaced?** `letter-spacing` is 0 (default) for body text.
9. **Proper punctuation?** Curly quotes, en/em dashes, real ellipses, × for multiplication.
10. **Figures appropriate?** Old-style in prose, lining in headings, tabular lining in tables.
11. **`lang` attribute set?** `<html lang="en">` — needed for correct hyphenation.
12. **Kerning enabled?** `font-kerning: auto` on body.
13. **Responsive?** Sizes in `rem`/`em`, measure in `ch`/`em`, unitless line-height.
14. **Headings balanced?** `text-wrap: balance` on headings, `text-wrap: pretty` on prose.
15. **No rivers?** If justified, hyphenation is enabled and measure is wide enough (40+ chars).

---

## Attribution

This skill synthesises typographic principles from:

- *The Elements of Typographic Style Applied to the Web* by Richard Rutter (webtypography.net),
  based on Robert Bringhurst's *The Elements of Typographic Style*.
- The U.S. Web Design System (USWDS) typography guidelines.
- Modern CSS specifications (CSS Fonts Module Level 4, CSS Text Module Level 4).

The webtypography.net content is licensed CC BY-NC 4.0 by Richard Rutter.
