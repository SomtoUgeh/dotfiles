# Touch & Accessibility

Touch devices, mobile considerations, keyboard navigation, and accessibility.

## Touch Devices

### Hover Effects

Disable hover effects on touch devices. Touch devices trigger hover on tap,
causing false positives. Keep spatial hover motion small and contextual, and
omit it when reduced motion is requested:

```css
/* Opt in only on precise pointers when spatial motion is acceptable. */
@media (hover: hover) and (pointer: fine) and (prefers-reduced-motion: no-preference) {
  .element--hover-scale:hover {
    transform: scale(1.02);
  }
}
```

**Important:** Don't rely on hover effects for the UI to work properly. Hover should enhance, not enable functionality.

### Touch Action

Disable `touch-action` for custom components that implement pan and zoom gestures to prevent interference from native behavior:

```css
.custom-canvas {
  touch-action: none;
}
```

### Double-Tap Zoom

Set `touch-action: manipulation` to prevent double-tap zoom on controls:

```css
button, a, input {
  touch-action: manipulation;
}
```

### Tap Targets

WCAG 2.2 Level AA requires pointer targets to be at least 24×24 CSS pixels or
meet a listed spacing or other exception. For touch-heavy controls, aim for a
comfortable 44×44px hit area; 44×44 is also the WCAG enhanced Level AAA target,
not the Level AA minimum. See [focused-polish.md](focused-polish.md#pointer-target-sizes)
for the standards and platform distinction.

```css
.icon-button {
  /* Visual size can be smaller */
  width: 24px;
  height: 24px;
  position: relative;
}

/* Comfortable touch target */
.icon-button::before {
  content: '';
  position: absolute;
  inset: -10px;
}
```

Or use padding:

```css
.small-button {
  min-width: 44px;
  min-height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
}
```

### Video Autoplay

Apply `muted` and `playsinline` to `<video>` tags to autoplay on iOS without opening a fullscreen video popup:

```html
<video autoplay muted playsinline loop>
  <source src="video.mp4" type="video/mp4" />
</video>
```

### OS-Specific Shortcuts

Replace `Cmd` with `Ctrl` based on operating system:

```js
const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
const modKey = isMac ? 'Cmd' : 'Ctrl';

// Display: "Save (Cmd+S)" on Mac, "Save (Ctrl+S)" on Windows
```

## Keyboard Navigation

### Tab Order

Tabbing should work consistently across the site. Users should only be able to tab through visible elements:

```css
/* Hide from tab order when not visible */
.hidden-panel {
  visibility: hidden;
}

/* Or use inert attribute */
<div inert={!isVisible}>...</div>
```

### Scroll Into View

Ensure keyboard navigation scrolls elements into view if needed:

```jsx
function handleFocus(e) {
  e.target.scrollIntoView({
    behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth',
    block: 'nearest',
  });
}
```

### Focus Management

When opening modals or dialogs, move focus to the first interactive element or the modal itself. When closing, return focus to the trigger element.

## Accessibility

### ARIA Labels

Always set aria labels on buttons with an icon as content:

```html
<button aria-label="Close dialog">
  <CloseIcon />
</button>

<button aria-label="Search">
  <SearchIcon />
</button>
```

### Code Illustrations

Illustrations built in code should have proper `aria-label` attribute:

```jsx
<div
  role="img"
  aria-label="Abstract geometric pattern"
  className="decorative-illustration"
/>
```

### Reduced Motion

See [animations.md](animations.md) for `prefers-reduced-motion` implementation. Every animation needs reduced motion support.

### Videos

Use the tested [media recipe](../animation-accessibility/SNIPPETS.md#autoplaying-video): native controls remain available, play() rejection is handled, and enabling reduced motion pauses ongoing playback. In React, use `playsInline`, not the HTML spelling `playsinline`; read browser preferences through an SSR-safe subscription, not `window` during render.

### Time-Limited Actions

Distinguish a pausable local presentation timer from a server-authoritative deadline. A session/token expiry, auction, or security timeout must retain its real deadline while the tab is hidden. For pausable UI, initialize the remaining duration and start time, pause on visibilitychange, clamp remaining time to zero, and clean up the timer and listener on unmount. Do not copy an uninitialized countdown or reset an authoritative expiry.

## Feedback

Ensure feedback components are visible on the page. Feedback is important—don't hide it behind hover states or modals.

## Tooltips

### Delay and Animation

Tooltips should have a delay before appearing to prevent accidental activation:

```css
.tooltip {
  transition-delay: 200ms;
}
```

**Sequential tooltips:** Once a tooltip is open, hovering over other tooltips should open them with no delay and no animation. Track "warm" state:

```jsx
const [isWarm, setIsWarm] = useState(false);

// When any tooltip opens, set warm state
// Clear warm state after 300ms of no tooltip being open
```

### Submenus

Use the installed menu primitive's pointer-grace behavior when available. A clip-path pseudo-element alone does not implement submenu intent: it needs real hit-area dimensions, correct positioning, and state/lifecycle behavior. Test diagonal movement, keyboard navigation, touch, and collision flips in the real component.
