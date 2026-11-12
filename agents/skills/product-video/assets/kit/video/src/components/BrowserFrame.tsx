import { AbsoluteFill } from "remotion";
import { browser, color } from "../brand/tokens";

/** Soft stage behind app footage. */
export const Stage: React.FC = () => (
  <AbsoluteFill
    style={{
      backgroundColor: color.stage,
      backgroundImage: `radial-gradient(120% 95% at 50% 35%, ${color.background} 0%, ${color.stage} 75%)`,
    }}
  />
);

const Lock: React.FC = () => (
  <svg width={13} height={15} viewBox="0 0 13 15" style={{ flexShrink: 0 }}>
    <rect x={1} y={6.5} width={11} height={7.5} rx={1.8} fill={color.muted} />
    <path
      d="M3.6 6.6 V4.6 A2.9 2.9 0 0 1 9.4 4.6 V6.6"
      fill="none"
      stroke={color.muted}
      strokeWidth={1.5}
    />
  </svg>
);

/**
 * Minimal browser window: rounded, softly shadowed, a quiet top bar with a URL pill.
 * Children render in the 1440x900 content area.
 */
export const BrowserFrame: React.FC<{
  readonly url: string;
  readonly children: React.ReactNode;
}> = ({ url, children }) => (
  <div
    style={{
      position: "absolute",
      left: browser.left,
      top: browser.top,
      width: browser.width,
      height: browser.height,
      borderRadius: browser.radius,
      overflow: "hidden",
      backgroundColor: color.background,
      boxShadow:
        `0 50px 100px -30px rgba(${color.shadowRgb}, 0.28), 0 18px 40px -20px rgba(${color.shadowRgb}, 0.22), 0 0 0 1px rgba(${color.shadowRgb}, 0.08)`,
    }}
  >
    <div
      style={{
        height: browser.barHeight,
        display: "flex",
        alignItems: "center",
        position: "relative",
        backgroundColor: color.card,
        borderBottom: `1px solid rgba(${color.shadowRgb}, 0.08)`,
      }}
    >
      <div style={{ display: "flex", gap: 8, paddingLeft: 20 }}>
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            style={{
              width: 12,
              height: 12,
              borderRadius: 6,
              backgroundColor: color.stage,
            }}
          />
        ))}
      </div>
      <div
        style={{
          position: "absolute",
          left: "50%",
          translate: "-50% 0",
          minWidth: 420,
          height: 30,
          padding: "0 18px",
          borderRadius: 15,
          backgroundColor: color.background,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 8,
          fontSize: 15,
          letterSpacing: "0.005em",
          color: color.foreground,
          whiteSpace: "nowrap",
        }}
      >
        <Lock />
        {url}
      </div>
    </div>
    <div
      style={{
        position: "relative",
        width: browser.viewport.width,
        height: browser.viewport.height,
        overflow: "hidden",
      }}
    >
      {children}
    </div>
  </div>
);
