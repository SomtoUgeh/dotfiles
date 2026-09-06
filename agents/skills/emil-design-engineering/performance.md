# Performance

Optimization, virtualization, and performance considerations.

## Animation Performance

See [animations.md](animations.md) for detailed animation performance guidelines. Key rules:

- Prefer `transform` and `opacity`; they usually avoid layout and paint
- Treat `height`, `width`, `padding`, and `margin` as higher-cost options; use
  them when correctness requires it and a representative recording shows the
  cost is acceptable
- Measure animated blur by area, radius, workload, and browser; no universal pixel cutoff
- Add `will-change` only after profiling identifies a benefit; it consumes
  memory and does not guarantee GPU acceleration
- Pause looping animations when off-screen

Follow the
[canonical motion policy](../animate/references/canonical-policy.md#performance)
for current evidence and driver selection. A measured hybrid of compositor-safe
effects and necessary layout or paint work can be appropriate. Route observed
jank, frame drops, or compositor questions to `animation-performance`.

## Lists & Virtualization

Virtualize large lists. Don't render hundreds of DOM nodes when only a few are visible:

```jsx
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualList({ items }) {
  const parentRef = useRef(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50,
  });

  return (
    <div ref={parentRef} style={{ height: '400px', overflow: 'auto' }}>
      <div style={{ height: virtualizer.getTotalSize(), position: "relative", width: "100%" }}>
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: virtualItem.start,
              left: 0,
              width: '100%',
              height: virtualItem.size,
            }}
          >
            {items[virtualItem.index]}
          </div>
        ))}
      </div>
    </div>
  );
}
```

## Transitions

### Avoid `transition: all`

Never use `transition: all`. It causes accidental animations and performance issues:

```css
/* Bad */
.button {
  transition: all 200ms ease;
}

/* Good - specify exact properties */
.button {
  transition: background-color 200ms ease, transform 200ms ease;
}
```

### Theme Switching

Switching themes should not trigger transitions. Disable transitions during theme changes:

```js
function setTheme(theme) {
  // Disable transitions
  document.documentElement.classList.add('no-transitions');

  // Apply theme
  document.documentElement.setAttribute('data-theme', theme);

  // Re-enable transitions after paint
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      document.documentElement.classList.remove('no-transitions');
    });
  });
}
```

```css
.no-transitions,
.no-transitions * {
  transition: none !important;
}
```

## Layout Performance

### Prevent Layout Shift

Dynamic elements should cause no layout shift:

- Use hardcoded dimensions for images and videos
- Reserve space for async content with skeletons
- Use `font-variant-numeric: tabular-nums` for changing numbers
- Don't change font weight on hover

### Font Loading

Preload only critical fonts to improve discovery. Preloading alone does not prevent layout shift; test fallback metrics and font-display behavior:

```jsx
import { preload } from 'react-dom';

preload('/fonts/inter-var.woff2', {
  as: 'font',
  type: 'font/woff2',
  crossOrigin: 'anonymous',
});
```

## React Performance

### Minimize Re-renders

Avoid driving every animation frame through React state. Prefer the installed
motion library's values or a correctly bounded imperative animation that
computes each frame, stops at completion, and cancels during cleanup. Follow the
project's current React and motion patterns rather than copying a perpetual
`requestAnimationFrame` loop.

### Framer Motion Performance

Do not infer acceleration or speed from Motion syntax alone. `x` and a full
`transform` string may use different implementations across library and browser
versions, and neither form guarantees compositor or GPU execution. Keep the
project's readable convention unless current documentation and a performance
recording identify it as the bottleneck; route that diagnosis to
`animation-performance`.

## CSS Performance

### CSS Variables

Avoid animating CSS variables in deep component trees. Inherited updates can expand style recalculation; measure the actual affected subtree before prescribing a replacement.

### Blur Filters

Blur cost depends on radius, area, browser, and workload. Compare traces on supported devices; do not treat 20px as a universal limit.

## Static Generation

Generate static content at build time:

```jsx
// Next.js Pages Router example; use the project's App Router caching APIs otherwise
export async function getStaticProps() {
  const posts = await fetchPosts();
  return {
    props: { posts },
    revalidate: 3600, // Revalidate hourly
  };
}
```

Don't fetch blog posts, changelog entries, or docs at request time when they can be pre-generated.

## Preloading

### Critical Images

Preload above-the-fold images:

```html
<link rel="preload" as="image" href="/hero.webp" />
```

### Fonts

```html
<link
  rel="preload"
  href="/fonts/inter.woff2"
  as="font"
  type="font/woff2"
  crossorigin
/>
```

## Off-Screen Content

Pause or stop resource-intensive operations when off-screen:

```js
const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      startAnimation();
    } else {
      pauseAnimation();
    }
  });
});

observer.observe(element);
// On component teardown: observer.disconnect(); pauseAnimation();
```
