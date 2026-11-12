import type { Box, ClipTimeRef } from "../script/types";

/** Events logged by the Playwright capture (times in seconds of the assembled mp4). */
export type ClipEvent =
  | { readonly t: number; readonly type: "beat"; readonly id: string; readonly note?: string }
  | {
      readonly t: number;
      readonly type: "click" | "type" | "hover";
      readonly box: Box;
      readonly label?: string;
    }
  | { readonly t: number; readonly type: "scroll"; readonly dy: number }
  | { readonly t: number; readonly type: "url"; readonly url: string };

export type PointerEvent = Extract<ClipEvent, { type: "click" | "type" | "hover" }>;
export type UrlEvent = Extract<ClipEvent, { type: "url" }>;

export type ClipMeta = {
  readonly clip: string;
  readonly duration: number;
  readonly fps: number;
  readonly events: readonly ClipEvent[];
};

export const isPointerEvent = (e: ClipEvent): e is PointerEvent =>
  e.type === "click" || e.type === "type" || e.type === "hover";

const beats = (clip: ClipMeta) =>
  clip.events
    .filter((e): e is Extract<ClipEvent, { type: "beat" }> => e.type === "beat")
    .sort((a, b) => a.t - b.t);

const resolveRef = (clip: ClipMeta, ref: ClipTimeRef): number => {
  if (typeof ref === "number") return ref;
  const beat = beats(clip).find((b) => b.id === ref);
  if (!beat) {
    const known = beats(clip).map((b) => b.id).join(", ");
    throw new Error(`Clip "${clip.clip}" has no beat "${ref}". Known beats: ${known}`);
  }
  return beat.t;
};

/** Source range in seconds for a scene: `from` until `to`, or until the next beat. */
export const resolveSegment = (
  clip: ClipMeta,
  from: ClipTimeRef,
  to: ClipTimeRef | undefined,
): { start: number; end: number } => {
  const start = Math.max(0, resolveRef(clip, from));
  let end: number;
  if (to !== undefined) {
    end = resolveRef(clip, to);
  } else {
    const next = beats(clip).find((b) => b.t > start + 1e-3);
    end = next ? next.t : clip.duration;
  }
  end = Math.min(end, clip.duration);
  if (end - start < 0.2) {
    throw new Error(`Segment ${String(from)} → ${String(to)} of "${clip.clip}" is empty`);
  }
  return { start, end };
};

/**
 * Segments that end on a click usually run into the next page's first paint. That tail
 * belongs to the next scene, so stop just before the first navigation in the last
 * `window` seconds. The cross-fade then carries the page change.
 */
export const trimTrailingNavigation = (
  clip: ClipMeta,
  segment: { start: number; end: number },
  window = 1.2,
): { start: number; end: number } => {
  const nav = clip.events.find(
    (e) => e.type === "url" && e.t > segment.start + 1 && e.t <= segment.end && segment.end - e.t <= window,
  );
  return nav ? { start: segment.start, end: nav.t - 0.05 } : segment;
};

/**
 * How footage fills a scene of `sceneFrames`. Long segments speed up to `maxRate`, then trim;
 * short segments play at 1x and hold their last frame.
 */
export type Playback = {
  /** Source second shown at scene frame 0. */
  readonly sourceStart: number;
  readonly rate: number;
  /** Scene frames during which footage moves; after this it freezes. */
  readonly playFrames: number;
};

export const planPlayback = ({
  start,
  end,
  sceneFrames,
  fps,
  maxRate,
  trim,
}: {
  start: number;
  end: number;
  sceneFrames: number;
  fps: number;
  maxRate: number;
  trim: "end" | "start";
}): Playback => {
  const sourceFrames = (end - start) * fps;
  const neededRate = sourceFrames / sceneFrames;
  if (neededRate <= 1) {
    return { sourceStart: start, rate: 1, playFrames: Math.max(1, Math.floor(sourceFrames)) };
  }
  if (neededRate <= maxRate) {
    return { sourceStart: start, rate: neededRate, playFrames: sceneFrames };
  }
  const shown = (sceneFrames * maxRate) / fps;
  return {
    sourceStart: trim === "start" ? end - shown : start,
    rate: maxRate,
    playFrames: sceneFrames,
  };
};

/** Source time (s) visible at a scene frame. */
export const sourceTimeAt = (p: Playback, frame: number, fps: number) =>
  p.sourceStart + (Math.min(Math.max(frame, 0), p.playFrames - 1) * p.rate) / fps;

/** Scene frame at which a source time is shown (may be outside the scene). */
export const frameOfSourceTime = (p: Playback, t: number, fps: number) =>
  ((t - p.sourceStart) * fps) / p.rate;
