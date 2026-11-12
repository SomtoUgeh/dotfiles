import { Easing, interpolate } from "remotion";
import { color } from "../brand/tokens";
import type { CursorState } from "../lib/cursor";

const ARROW_HEIGHT = 30;

const rippleDiameter = (progress: number, zoom: number) =>
  interpolate(progress, [0, 1], [14, 64 * zoom], {
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

/** macOS-style pointer; hotspot at the tip (0,0). */
const Arrow: React.FC<{ readonly size: number }> = ({ size }) => (
  <svg
    width={(size * 20) / 30}
    height={size}
    viewBox="0 0 20 30"
    style={{ position: "absolute", left: -1, top: -1, overflow: "visible" }}
  >
    <path
      d="M1.5 1.5 L1.5 23.5 L6.8 18.6 L10.3 26.8 L14.1 25.2 L10.7 17.2 L17.8 17.2 Z"
      fill="#111"
      stroke="#fff"
      strokeWidth={1.6}
      strokeLinejoin="round"
      style={{ filter: "drop-shadow(0 2px 3px rgba(0,0,0,0.28))" }}
    />
  </svg>
);

/** Text I-beam centred on the point. */
const IBeam: React.FC<{ readonly size: number }> = ({ size }) => {
  const w = size * 0.42;
  return (
    <svg
      width={w}
      height={size}
      viewBox="0 0 12 30"
      style={{ position: "absolute", left: -w / 2, top: -size / 2, overflow: "visible" }}
    >
      <path
        d="M2 2 Q6 2 6 5 Q6 2 10 2 M6 5 L6 25 M2 28 Q6 28 6 25 Q6 28 10 28"
        fill="none"
        stroke="#fff"
        strokeWidth={4}
        strokeLinecap="round"
      />
      <path
        d="M2 2 Q6 2 6 5 Q6 2 10 2 M6 5 L6 25 M2 28 Q6 28 6 25 Q6 28 10 28"
        fill="none"
        stroke="#111"
        strokeWidth={1.8}
        strokeLinecap="round"
      />
    </svg>
  );
};

/**
 * Draws the cursor in screen space (so it stays crisp) at a position already mapped
 * through the camera. `zoom` scales it mildly so it feels attached to the UI.
 */
export const Cursor: React.FC<{
  readonly state: CursorState;
  readonly toScreen: (x: number, y: number) => { x: number; y: number };
  readonly zoom: number;
}> = ({ state, toScreen, zoom }) => {
  const size = ARROW_HEIGHT * (1 + (zoom - 1) * 0.45);
  const p = toScreen(state.x, state.y);
  const ripple = state.ripple;
  const r = ripple ? toScreen(ripple.x, ripple.y) : null;
  return (
    <>
      {ripple && r ? (
        <div
          style={{
            position: "absolute",
            left: r.x,
            top: r.y,
            width: 0,
            height: 0,
            opacity: state.opacity,
          }}
        >
          <div
            style={{
              position: "absolute",
              width: rippleDiameter(ripple.progress, zoom),
              height: rippleDiameter(ripple.progress, zoom),
              left: -rippleDiameter(ripple.progress, zoom) / 2,
              top: -rippleDiameter(ripple.progress, zoom) / 2,
              borderRadius: "50%",
              border: `2px solid ${color.primary}`,
              backgroundColor: "rgba(255,255,255,0.4)",
              opacity: interpolate(ripple.progress, [0, 0.12, 1], [0, 0.75, 0]),
            }}
          />
        </div>
      ) : null}
      <div
        style={{
          position: "absolute",
          left: p.x,
          top: p.y,
          width: 0,
          height: 0,
          opacity: state.opacity,
          scale: state.press,
        }}
      >
        {state.shape === "ibeam" ? <IBeam size={size * 0.85} /> : <Arrow size={size} />}
      </div>
    </>
  );
};
