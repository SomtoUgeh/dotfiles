import { Easing, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { browser, canvas, captionCharEm, color, easeOutExpo, layout } from "../brand/tokens";
import type { Box } from "../script/types";

// Captions sit over a live UI; 52px reads well on a laptop at 1080p without
// covering the action. The large support size is kept for full-frame cards.
const TEXT_SIZE = 52;
const EYEBROW_SIZE = 24;
const PAD_X = 32;
const PAD_TOP = 20;
const PAD_BOTTOM = 24;
const LINE = 1.08;

/** Card geometry on the canvas, so the camera and placement logic can avoid it. */
export const captionLayout = (text: string, hasEyebrow: boolean) => {
  // Bottom of the caption text sits on the bottom safe line.
  const bottom = canvas.height - layout.safeY + PAD_BOTTOM;
  const height =
    PAD_TOP + (hasEyebrow ? EYEBROW_SIZE * 1.4 + 6 : 0) + TEXT_SIZE * LINE + PAD_BOTTOM;
  // Estimated from the font's average character width (tokens.ts).
  const width = Math.round(text.length * TEXT_SIZE * captionCharEm + PAD_X * 2);
  return { top: bottom - height, bottom, height, width };
};

export type Side = "left" | "right";

type Rect = { x0: number; y0: number; x1: number; y1: number };

/** The caption card's rectangle in viewport (CSS px) coordinates of the app content. */
export const captionRect = (text: string, hasEyebrow: boolean, side: Side): Rect => {
  const { top, bottom, width } = captionLayout(text, hasEyebrow);
  const left = side === "left" ? layout.safeX : canvas.width - layout.safeX - width;
  return {
    x0: left - browser.contentLeft,
    y0: top - browser.contentTop,
    x1: left + width - browser.contentLeft,
    y1: bottom - browser.contentTop,
  };
};

export const overlapArea = (r: Rect, b: Box, margin = 0) => {
  const w = Math.min(r.x1 + margin, b.x + b.width) - Math.max(r.x0 - margin, b.x);
  const h = Math.min(r.y1 + margin, b.y + b.height) - Math.max(r.y0 - margin, b.y);
  return w > 0 && h > 0 ? w * h : 0;
};

/** Pick the bottom corner that hides the least of the scene's action. */
export const chooseCaptionSide = (text: string, hasEyebrow: boolean, boxes: readonly Box[]): Side => {
  const cost = (side: Side) => {
    const r = captionRect(text, hasEyebrow, side);
    return boxes.reduce((sum, b) => sum + overlapArea(r, b), 0);
  };
  return cost("right") < cost("left") ? "right" : "left";
};

/**
 * Lower-third that interprets the screen in a few words. Enters once the scene has
 * faded in and leaves before the outgoing transition, so captions never cross-fade.
 */
export const Caption: React.FC<{
  readonly text: string;
  readonly eyebrow?: string;
  readonly side: Side;
  readonly enterAt: number;
  readonly exitAt: number;
}> = ({ text, eyebrow, side, enterAt, exitAt }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { bottom } = captionLayout(text, Boolean(eyebrow));

  return (
    <div
      style={{
        position: "absolute",
        bottom: canvas.height - bottom,
        [side]: layout.safeX,
        backgroundColor: color.primary,
        color: color.onPrimary,
        borderRadius: 24,
        padding: `${PAD_TOP}px ${PAD_X}px ${PAD_BOTTOM}px`,
        boxShadow: "0 24px 60px -18px rgba(1, 34, 25, 0.45), 0 2px 6px rgba(1, 34, 25, 0.18)",
        opacity: interpolate(
          frame,
          [enterAt, enterAt + 0.45 * fps, exitAt - 0.3 * fps, exitAt],
          [0, 1, 1, 0],
          { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
        ),
        translate: interpolate(frame, [enterAt, enterAt + 0.7 * fps], ["0px 28px", "0px 0px"], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(...easeOutExpo),
        }),
      }}
    >
      {eyebrow ? (
        <div
          style={{
            fontSize: EYEBROW_SIZE,
            fontWeight: 500,
            letterSpacing: "0.08em",
            textTransform: "uppercase",
            color: color.onPrimaryMuted,
            marginBottom: 6,
          }}
        >
          {eyebrow}
        </div>
      ) : null}
      <div
        style={{
          fontSize: TEXT_SIZE,
          fontWeight: 500,
          lineHeight: LINE,
          letterSpacing: "-0.025em",
          whiteSpace: "nowrap",
        }}
      >
        {text}
      </div>
    </div>
  );
};
