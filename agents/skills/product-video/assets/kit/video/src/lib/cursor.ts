import { Easing, interpolate } from "remotion";
import type { FocusEvent } from "./camera";

/** Pure synthetic-cursor path, in scene frames and CSS px of the recorded viewport. */
export type CursorState = {
  readonly x: number;
  readonly y: number;
  readonly opacity: number;
  readonly shape: "arrow" | "ibeam";
  /** 1 at rest, < 1 while pressing. */
  readonly press: number;
  /** Click ripple, progress 0..1, or null. */
  readonly ripple: { readonly x: number; readonly y: number; readonly progress: number } | null;
};

type Stop = {
  x: number;
  y: number;
  frame: number;
  kind: FocusEvent["kind"];
  depart: number;
  arrive: number;
  group: number;
};

const glideEase = Easing.bezier(0.45, 0, 0.15, 1);

export type CursorPlan = { stops: Stop[]; fps: number };

export const planCursor = (events: readonly FocusEvent[], fps: number): CursorPlan => {
  const sorted = [...events].sort((a, b) => a.frame - b.frame);
  const arriveEarly = 0.35 * fps;
  const glide = 0.75 * fps;
  const groupGap = 4 * fps;
  const stops: Stop[] = [];
  sorted.forEach((e, i) => {
    const prev = stops[i - 1];
    // Text fields: rest the I-beam near the start of the text, not mid-field.
    const x = e.kind === "type" ? e.box.x + Math.min(e.box.width / 2, 36) : e.box.x + e.box.width / 2;
    const y = e.box.y + e.box.height / 2;
    const newGroup = !prev || e.frame - prev.frame > groupGap;
    const group = newGroup ? (prev ? prev.group + 1 : 0) : prev.group;
    let arrive = e.frame - arriveEarly;
    let depart = arrive - glide;
    if (!newGroup && prev) {
      arrive = Math.max(arrive, prev.frame + 2);
      depart = Math.min(Math.max(depart, prev.frame + 0.12 * fps), arrive - 2);
    }
    stops.push({ x, y, frame: e.frame, kind: e.kind, depart, arrive, group });
  });
  return { stops, fps };
};

const ENTRY_OFFSET = { x: 150, y: 120 };

export const cursorAt = ({ stops, fps }: CursorPlan, frame: number): CursorState | null => {
  if (stops.length === 0) return null;

  // Visibility per group: fade in while gliding in, fade out after the last action.
  let opacity = 0;
  for (const g of new Set(stops.map((s) => s.group))) {
    const members = stops.filter((s) => s.group === g);
    const first = members[0];
    const last = members[members.length - 1];
    const o = interpolate(
      frame,
      [first.depart - 0.1 * fps, first.depart + 0.25 * fps, last.frame + 1.0 * fps, last.frame + 1.35 * fps],
      [0, 1, 1, 0],
      { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
    );
    opacity = Math.max(opacity, o);
  }
  if (opacity <= 0.001) return null;

  // Position: hold at the last stop reached, glide toward the next.
  let index = -1;
  for (let i = 0; i < stops.length; i++) {
    if (stops[i].depart <= frame) index = i;
  }
  let x: number;
  let y: number;
  if (index === -1) {
    x = stops[0].x + ENTRY_OFFSET.x;
    y = stops[0].y + ENTRY_OFFSET.y;
  } else {
    const target = stops[index];
    const prev = stops[index - 1];
    const origin =
      prev && prev.group === target.group
        ? prev
        : { x: target.x + ENTRY_OFFSET.x, y: target.y + ENTRY_OFFSET.y };
    const t = glideEase(
      Math.min(Math.max((frame - target.depart) / Math.max(target.arrive - target.depart, 1), 0), 1),
    );
    x = origin.x + (target.x - origin.x) * t;
    y = origin.y + (target.y - origin.y) * t;
  }

  // Shape: I-beam once it has reached a text field, until it leaves for the next stop.
  const reached = stops.filter((s) => s.arrive <= frame);
  const current = reached[reached.length - 1];
  const next = current ? stops[stops.indexOf(current) + 1] : undefined;
  const onField = current?.kind === "type" && (!next || frame < next.depart);
  const shape = onField ? "ibeam" : "arrow";

  // Press and ripple for the most recent click.
  let press = 1;
  let ripple: CursorState["ripple"] = null;
  for (const s of stops) {
    if (s.kind !== "click") continue;
    const p = interpolate(frame, [s.frame - 0.1 * fps, s.frame, s.frame + 0.2 * fps], [1, 0.82, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    press = Math.min(press, p);
    const progress = (frame - s.frame) / (0.55 * fps);
    if (progress >= 0 && progress <= 1) ripple = { x: s.x, y: s.y, progress };
  }

  return { x, y, opacity, shape, press, ripple };
};
