import { Easing } from "remotion";
import type { Box, ZoomMode } from "../script/types";

/**
 * Pure camera path for an app shot. Everything is in scene frames and CSS px of the
 * recorded 1440x900 viewport. The camera is a visible-region centre plus a zoom factor.
 */
export type Camera = { readonly z: number; readonly cx: number; readonly cy: number };

export type FocusEvent = {
  readonly frame: number;
  readonly kind: "click" | "type" | "hover";
  readonly box: Box;
};

export type CameraOptions = {
  readonly fps: number;
  readonly viewport: { readonly width: number; readonly height: number };
  readonly sceneFrames: number;
  /** Frames at the end of the scene covered by the outgoing transition. */
  readonly transitionOutFrames: number;
  readonly maxZoom?: number;
  /**
   * Screen y (CSS px) above which the focus should sit, e.g. the top of a bottom caption.
   * The camera centres targets in the clear band when it has room to pan.
   */
  readonly clearBottom?: number;
};

type Command = { frame: number; target: Camera; duration: number };

const ease = Easing.spring({ damping: 200 });

const DEFAULT_MAX_ZOOM = 1.45;
const HOVER_MAX_ZOOM = 1.3;
const MIN_WORTHWHILE_ZOOM = 1.15;

const union = (a: Box, b: Box): Box => {
  const x = Math.min(a.x, b.x);
  const y = Math.min(a.y, b.y);
  return {
    x,
    y,
    width: Math.max(a.x + a.width, b.x + b.width) - x,
    height: Math.max(a.y + a.height, b.y + b.height) - y,
  };
};

const fitZoom = (box: Box, viewport: CameraOptions["viewport"], maxZoom: number) => {
  const w = Math.max(box.width + 360, 680);
  const h = Math.max(box.height + 260, 425);
  const z = Math.min(viewport.width / w, viewport.height / h);
  return Math.min(Math.max(z, 1), maxZoom);
};

const clampCamera = (c: Camera, viewport: CameraOptions["viewport"]): Camera => {
  const halfW = viewport.width / (2 * c.z);
  const halfH = viewport.height / (2 * c.z);
  return {
    z: c.z,
    cx: Math.min(Math.max(c.cx, halfW), viewport.width - halfW),
    cy: Math.min(Math.max(c.cy, halfH), viewport.height - halfH),
  };
};

const cameraFor = (box: Box, z: number, opts: CameraOptions): Camera => {
  const { viewport } = opts;
  const bx = box.x + box.width / 2;
  const by = box.y + box.height / 2;
  // Place the target in the middle of the clear band rather than the middle of the frame.
  const clearBottom = opts.clearBottom ?? viewport.height;
  const desiredScreenY = Math.min(viewport.height / 2, clearBottom / 2);
  const cy = by - (desiredScreenY - viewport.height / 2) / z;
  return clampCamera({ z, cx: bx, cy }, viewport);
};

export const fullFrame = (viewport: CameraOptions["viewport"]): Camera => ({
  z: 1,
  cx: viewport.width / 2,
  cy: viewport.height / 2,
});

type Cluster = { f0: number; f1: number; box: Box; hoverOnly: boolean };

const clusterEvents = (
  events: readonly FocusEvent[],
  urlFrames: readonly number[],
  opts: CameraOptions,
  maxZoom: number,
): Cluster[] => {
  const gap = 2.5 * opts.fps;
  const clusters: Cluster[] = [];
  for (const e of events) {
    const last = clusters[clusters.length - 1];
    if (last) {
      const merged = union(last.box, e.box);
      const navigatedBetween = urlFrames.some((u) => u > last.f1 && u <= e.frame);
      if (
        e.frame - last.f1 <= gap &&
        !navigatedBetween &&
        fitZoom(merged, opts.viewport, maxZoom) >= 1.35
      ) {
        last.f1 = e.frame;
        last.box = merged;
        last.hoverOnly = last.hoverOnly && e.kind === "hover";
        continue;
      }
    }
    clusters.push({ f0: e.frame, f1: e.frame, box: e.box, hoverOnly: e.kind === "hover" });
  }
  return clusters;
};

const planAuto = (
  events: readonly FocusEvent[],
  urlFrames: readonly number[],
  opts: CameraOptions,
): Command[] => {
  const { fps, viewport } = opts;
  const maxZoom = opts.maxZoom ?? DEFAULT_MAX_ZOOM;
  const lead = 0.9 * fps;
  const zoomIn = 0.9 * fps;
  const zoomOut = 0.8 * fps;
  const hold = 1.4 * fps;
  const minSettled = 0.8 * fps;
  const latestRelease = opts.sceneFrames - opts.transitionOutFrames - zoomOut;

  const sorted = [...events].sort((a, b) => a.frame - b.frame);
  const shots = clusterEvents(sorted, urlFrames, opts, maxZoom)
    .map((c) => {
      const z = fitZoom(c.box, viewport, c.hoverOnly ? HOVER_MAX_ZOOM : maxZoom);
      const start = Math.max(0, c.f0 - lead);
      const nextUrl = urlFrames.find((u) => u > c.f1);
      const end = Math.min(c.f1 + hold, nextUrl ?? Infinity, latestRelease);
      return { z, start, end, target: cameraFor(c.box, z, opts) };
    })
    .filter((s) => s.z >= MIN_WORTHWHILE_ZOOM && s.end - (s.start + zoomIn) >= minSettled);

  const commands: Command[] = [];
  shots.forEach((s, i) => {
    const prev = commands[commands.length - 1];
    const start = prev ? Math.max(s.start, prev.frame + 1) : s.start;
    commands.push({ frame: start, target: s.target, duration: zoomIn });
    const next = shots[i + 1];
    // Pan straight to the next shot when it follows closely; otherwise release.
    if (!next || next.start > s.end + 0.6 * fps) {
      commands.push({ frame: s.end, target: fullFrame(viewport), duration: zoomOut });
    }
  });
  return commands;
};

const planFixed = (region: Box, zoom: number | undefined, opts: CameraOptions): Command[] => {
  const { fps, viewport } = opts;
  const z = zoom ?? fitZoom(region, viewport, opts.maxZoom ?? DEFAULT_MAX_ZOOM);
  const release = opts.sceneFrames - opts.transitionOutFrames - 0.8 * fps;
  return [
    { frame: 0.2 * fps, target: cameraFor(region, z, opts), duration: 1.2 * fps },
    { frame: Math.max(release, 1.4 * fps), target: fullFrame(viewport), duration: 0.8 * fps },
  ];
};

export const planCamera = (
  mode: ZoomMode,
  events: readonly FocusEvent[],
  urlFrames: readonly number[],
  opts: CameraOptions,
): Command[] => {
  if (mode === "off") return [];
  if (mode === "auto") return planAuto(events, urlFrames, opts);
  return planFixed(mode.region, mode.zoom, opts);
};

const mix = (a: Camera, b: Camera, t: number): Camera => ({
  z: Math.exp(Math.log(a.z) + (Math.log(b.z) - Math.log(a.z)) * t),
  cx: a.cx + (b.cx - a.cx) * t,
  cy: a.cy + (b.cy - a.cy) * t,
});

/** Camera at a frame: each command eases from wherever the previous motion had reached. */
export const cameraAt = (
  commands: readonly Command[],
  frame: number,
  viewport: CameraOptions["viewport"],
): Camera => {
  const valueOf = (from: Camera, cmd: Command, f: number) => {
    const p = Math.min(Math.max((f - cmd.frame) / cmd.duration, 0), 1);
    return mix(from, cmd.target, ease(p));
  };
  let from = fullFrame(viewport);
  let active: Command | null = null;
  for (const cmd of commands) {
    if (cmd.frame > frame) break;
    if (active) from = valueOf(from, active, cmd.frame);
    active = cmd;
  }
  const cam = active ? valueOf(from, active, frame) : from;
  return clampCamera(cam, viewport);
};
