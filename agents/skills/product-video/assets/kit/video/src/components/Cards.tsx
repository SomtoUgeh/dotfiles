import { AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { brand, color, easeOutExpo, layout } from "../brand/tokens";

/** Fade + rise entrance, starting `delay` seconds into the scene. */
const Rise: React.FC<{
  readonly delay: number;
  readonly children: React.ReactNode;
  readonly style?: React.CSSProperties;
}> = ({ delay, children, style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <div
      style={{
        ...style,
        opacity: interpolate(frame, [delay * fps, (delay + 0.6) * fps], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        }),
        translate: interpolate(frame, [delay * fps, (delay + 0.9) * fps], ["0px 36px", "0px 0px"], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(...easeOutExpo),
        }),
      }}
    >
      {children}
    </div>
  );
};

const headline: React.CSSProperties = {
  fontSize: layout.headline,
  fontWeight: 500,
  lineHeight: 1.02,
  letterSpacing: "-0.035em",
  margin: 0,
};

const support: React.CSSProperties = {
  fontSize: layout.support,
  fontWeight: 400,
  lineHeight: 1.15,
  letterSpacing: "-0.015em",
};

const safeColumn: React.CSSProperties = {
  position: "absolute",
  left: layout.safeX,
  right: layout.safeX,
  top: layout.safeY,
  bottom: layout.safeY,
  display: "flex",
  flexDirection: "column",
};

/** Logo file when the brand has one, otherwise the product name as text. */
const Wordmark: React.FC<{ readonly file: string | null; readonly height: number }> = ({ file, height }) =>
  file ? (
    <Img src={staticFile(file)} style={{ height }} />
  ) : (
    <div style={{ fontSize: Math.round(height * 0.62), fontWeight: 500, letterSpacing: "-0.02em" }}>
      {brand.name}
    </div>
  );

/** Opening card: logo, headline and subline on the light background. */
export const IntroCard: React.FC<{ readonly title: string; readonly subtitle?: string }> = ({
  title,
  subtitle,
}) => (
  <AbsoluteFill style={{ backgroundColor: color.background, color: color.foreground }}>
    <div style={{ ...safeColumn, justifyContent: "space-between" }}>
      <Rise delay={0.1}>
        <div style={{ color: color.primary }}>
          <Wordmark file={brand.logo} height={76} />
        </div>
      </Rise>
      <div>
        <Rise delay={0.35}>
          <h1 style={{ ...headline, color: color.primary, maxWidth: 1250 }}>{title}</h1>
        </Rise>
        {subtitle ? (
          <Rise delay={0.75} style={{ marginTop: 36 }}>
            <div style={{ ...support, color: color.muted }}>{subtitle}</div>
          </Rise>
        ) : null}
      </div>
    </div>
  </AbsoluteFill>
);

/** Chapter card on the primary colour. */
export const ChapterCard: React.FC<{ readonly title: string; readonly eyebrow?: string }> = ({
  title,
  eyebrow,
}) => (
  <AbsoluteFill style={{ backgroundColor: color.primary, color: color.onPrimary }}>
    <div style={{ ...safeColumn, justifyContent: "center" }}>
      {eyebrow ? (
        <Rise delay={0.15} style={{ marginBottom: 40 }}>
          <div
            style={{
              fontSize: 40,
              fontWeight: 500,
              letterSpacing: "0.1em",
              textTransform: "uppercase",
              color: color.onPrimaryMuted,
            }}
          >
            {eyebrow}
          </div>
        </Rise>
      ) : null}
      <Rise delay={0.3}>
        <h1 style={{ ...headline, maxWidth: 1500 }}>{title}</h1>
      </Rise>
    </div>
  </AbsoluteFill>
);

/** Closing card: logo, tagline, address. */
export const OutroCard: React.FC<{ readonly tagline: string; readonly url: string }> = ({
  tagline,
  url,
}) => (
  <AbsoluteFill
    style={{
      backgroundColor: color.primary,
      color: color.onPrimary,
      alignItems: "center",
      justifyContent: "center",
      textAlign: "center",
    }}
  >
    <Rise delay={0.15}>
      <Wordmark file={brand.logoOnPrimary} height={150} />
    </Rise>
    <Rise delay={0.5} style={{ marginTop: 64 }}>
      <div style={{ ...support, fontWeight: 500 }}>{tagline}</div>
    </Rise>
    <Rise delay={0.8} style={{ marginTop: 20 }}>
      <div style={{ ...support, color: color.onPrimaryMuted }}>{url}</div>
    </Rise>
  </AbsoluteFill>
);
