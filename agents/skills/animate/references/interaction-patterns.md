# Interaction Motion Patterns

Read this reference when a common interaction needs a concrete implementation pattern. Tune the values in the real component and follow [canonical-policy.md](canonical-policy.md) for accessibility, performance, and verification.

## Sequential tooltips

After one tooltip is open, nearby tooltips should usually appear without repeating the initial delay and entrance. Use the component library's provider or state contract when it offers one; otherwise expose an equivalent state explicitly.

```css
.tooltip {
  opacity: 1;
  transform: scale(1);
  transform-origin: var(--transform-origin);
  transition:
    transform 125ms ease-out,
    opacity 125ms ease-out;
}

.tooltip[data-starting-style],
.tooltip[data-ending-style] {
  opacity: 0;
  transform: scale(0.97);
}

.tooltip[data-instant] {
  transition-duration: 0ms;
}
```

Treat the attributes as an example contract. Check the installed library's current API and state attributes before using them.

## Stable hover targets

Moving the hover target can move it away from the pointer and create a flicker loop. Keep the hit area stationary and animate a child.

```html
<a class="card" href="/details">
  <span class="card__surface">...</span>
</a>
```

```css
@media (hover: hover) and (pointer: fine) {
  .card:hover .card__surface {
    transform: translateY(-2%);
  }
}

.card__surface {
  transition: transform 180ms ease-out;
}
```

## Trigger-relative popovers

Triggered content should appear from the trigger side. Prefer the positioning library's computed transform-origin variable because it accounts for collision handling and placement changes.

```css
.radix-popover {
  transform-origin: var(--radix-popover-content-transform-origin);
}

.base-popover {
  transform-origin: var(--transform-origin);
}
```

## One-pixel transform shifts

When an element shifts by a pixel at the start or end of a transform animation, record the interaction and inspect it frame by frame in the target browser. Check rasterization, subpixel values, and layer changes before applying a fix.

If profiling shows that repeated layer promotion is the cause, a targeted hint may help:

```css
.animated-surface {
  will-change: transform;
}
```

`will-change` is a browser hint. Apply it only to the affected element and remove it while idle when practical; retained layers consume memory.
