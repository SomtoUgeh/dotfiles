# Reduced-Motion Snippets

Copy-ready recipes for the cases that need a specific mechanism rather than an easing swap. From the *Animations on the Web* course ([animations.dev](https://animations.dev/)).

## Smooth scrolling

Scroll-behavior is motion the user didn't ask for, so opt *in* under `no-preference` rather than opting out under `reduce`. Written this way, the accessible behavior is the default even in browsers that don't match either query:

```css
@media (prefers-reduced-motion: no-preference) {
  html {
    scroll-behavior: smooth;
  }
}
```

## Autoplaying images

An animated GIF or AVIF autoplays with no user control at all. `<picture>` swaps in a static frame under `reduce` — no JavaScript, and the browser selects a matching source; check actual requests, especially when the preference changes or preload hints exist:

```html
<picture>
  <!-- Animated versions -->
  <source
    srcset="animated.avifs"
    type="image/avif"
    media="(prefers-reduced-motion: no-preference)"
  />
  <source
    srcset="animated.gif"
    type="image/gif"
    media="(prefers-reduced-motion: no-preference)"
  />
  <!-- Static fallback -->
  <img src="static.png" alt="" />
</picture>
```

## Autoplaying video

Use native controls in both modes so playback failure never leaves the media without a working control. Autoplay only on initial setup with no reduced-motion preference; enabling reduced motion while playing pauses the video. Returning to no-preference does not override a person's manual pause.

```html
<video class="motion-video" controls muted playsinline loop>
  <source src="video.mp4" type="video/mp4" />
</video>
```

```js
function setupMotionVideo(video) {
  const preference = window.matchMedia("(prefers-reduced-motion: reduce)");
  const onPreferenceChange = () => {
    if (preference.matches) video.pause();
  };
  preference.addEventListener("change", onPreferenceChange);
  if (!preference.matches) {
    // Browsers may reject autoplay; native controls remain available.
    void video.play().catch(() => {});
  }
  return () => {
    preference.removeEventListener("change", onPreferenceChange);
    video.pause();
  };
}

const video = document.querySelector(".motion-video");
if (video instanceof HTMLVideoElement) {
  const dispose = setupMotionVideo(video);
  window.addEventListener("pagehide", dispose, { once: true });
}
```

In a component, call `setupMotionVideo` from its media synchronization effect and return `dispose` on unmount. Give meaningful media a description, captions, and transcript as appropriate. [HTMLMediaElement.play()](https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/play) returns a promise; a successful call cannot be assumed.

## Looping animation: pause on a hero frame

Don't just stop a loop — a paused animation sits on frame 0, which is usually its least representative state (an empty chart, a collapsed shape). A **negative `animation-delay` seeks into the timeline**, so pausing lands on a frame you chose:

```css
.animation {
  animation: shake 0.2s infinite;
}

@media (prefers-reduced-motion: reduce) {
  .animation {
    animation-play-state: paused;
    /* Pauses halfway through the 0.2s cycle. Try different values and pick the best-looking frame. */
    animation-delay: -0.1s;
  }
}
```

Vercel does this on their [rendering](https://vercel.com/products/rendering) page: under reduced motion the animation holds on a frame from the middle of the loop, so the visual still reads.

## Dependency-free `useReducedMotion`

When the project has no preference hook, React's external-store API keeps the media query synchronized, including live preference changes. Start with reduced motion on the server so initial hydration never opts someone into spatial motion before checking their preference.

```tsx
import { useSyncExternalStore } from "react";

const QUERY = "(prefers-reduced-motion: reduce)";

function subscribe(onChange: () => void): () => void {
  const query = window.matchMedia(QUERY);
  query.addEventListener("change", onChange);
  return () => query.removeEventListener("change", onChange);
}

export function useReducedMotion(): boolean {
  return useSyncExternalStore(
    subscribe,
    () => window.matchMedia(QUERY).matches,
    () => true,
  );
}
```

Keep content present in both states; change animation values, not access to content. See [React useSyncExternalStore](https://react.dev/reference/react/useSyncExternalStore).

## Worked example: a multi-step component

The generic case. A multi-step form slides horizontally between steps and animates its container height. Three separate things move, so all three need a reduced variant — and this is why a **second variant set** beats patching values inline. Save the external-store hook above as `use-reduced-motion.ts` for live preference changes; Motion 13.2's built-in hook reads the preference on mount.

```jsx
import { useState } from "react";
import { AnimatePresence, motion, MotionConfig } from "motion/react";
import useMeasure from "react-use-measure";
import { useReducedMotion } from "./use-reduced-motion";

export default function MultiStepComponent() {
  const [currentStep, setCurrentStep] = useState(0);
  const [direction, setDirection] = useState(1);
  const [ref, bounds] = useMeasure();
  const reducedMotion = useReducedMotion();

  return (
    <MotionConfig transition={{ duration: 0.5, type: "spring", bounce: 0 }}>
      {/* 1. Height animation: skipped entirely — a growing container is movement. */}
      <motion.div
        animate={{ height: reducedMotion ? "auto" : bounds.height || "auto" }}
        transition={reducedMotion ? { duration: 0 } : undefined}
      >
        <div ref={ref}>
          <AnimatePresence mode="popLayout" initial={false} custom={direction}>
            <motion.div
              key={currentStep}
              /* 2. Slide → crossfade by swapping the whole variant set. */
              variants={reducedMotion ? reducedMotionVariants : variants}
              initial="initial"
              animate="active"
              exit="exit"
              custom={direction}
            >
              {/* step content */}
            </motion.div>
          </AnimatePresence>
          {/* 3. Layout animation on the actions row: off, it repositions the buttons. */}
          <motion.div layout={!reducedMotion} className="actions">
            {/* Back / Continue */}
          </motion.div>
        </div>
      </motion.div>
    </MotionConfig>
  );
}

const variants = {
  initial: (direction) => ({ x: `${110 * direction}%`, opacity: 0 }),
  active: { x: "0%", opacity: 1 },
  exit: (direction) => ({ x: `${-110 * direction}%`, opacity: 0 }),
};

// Same three states, opacity only — the step change stays legible, nothing moves.
const reducedMotionVariants = {
  initial: { opacity: 0 },
  active: { opacity: 1, x: 0 },
  exit: { opacity: 0 },
};
```

The transferable shape: **one `useReducedMotion()` call, then audit every animating property in the component.** Movement usually hides in more than one place — a transform, a measured height, and a `layout` prop are three separate opt-outs, and missing any one leaves the "reduced" variant still moving.
