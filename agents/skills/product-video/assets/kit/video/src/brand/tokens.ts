/**
 * Brand settings for the video. Change this file first when you start a new product:
 * the name, the address-bar host, the logos, the fonts and the colours.
 */
export const brand = {
  /** Shown as a text wordmark on the cards when no logo file is set. */
  name: "Your Product",
  /** Host shown in the address bar instead of the recorded (local) host. */
  host: "app.example.com",
  /** Logo for light backgrounds: a file in public/brand, e.g. "brand/logo.svg". */
  logo: null as string | null,
  /** Logo for the primary-colour cards (usually white). */
  logoOnPrimary: null as string | null,
  /**
   * Font files in public/fonts. Leave empty to use the system font. Only add fonts that
   * your licence lets you use in video.
   */
  fonts: [] as readonly { readonly family: string; readonly file: string; readonly weight: string }[],
  /**
   * Path segments that are scaffolding when an id follows them. With ["workspaces"],
   * `/workspaces/<id>/settings` is shown as `/settings`.
   */
  urlScaffold: [] as readonly string[],
} as const;

export const color = {
  primary: "#14213d",
  primaryDeep: "#0b1326",
  background: "#fbfaf8",
  card: "#efede8",
  stage: "#e6e3dc",
  foreground: "#1c1b19",
  muted: "#6f6c66",
  accent: "#dfe7f5",
  onPrimary: "#fbfaf8",
  onPrimaryMuted: "#b9c3d8",
  /** "r, g, b" of the shadow and hairline colour around the browser window. */
  shadowRgb: "20, 33, 61",
} as const;

export const fontFamily =
  'system-ui, -apple-system, "Segoe UI", "Helvetica Neue", Arial, sans-serif';

/**
 * Average character width of the caption font, in em. It sizes the caption card so the
 * camera can keep the action clear of it. Measure again when you change the font.
 */
export const captionCharEm = 0.53;

/** Composition canvas. Layout rules are written for 1080 width and scaled by `unit`. */
export const canvas = { width: 1920, height: 1080, fps: 30 } as const;
const unit = canvas.width / 1080;

export const layout = {
  /** Keep key text inside this inset (80px sides / 100px top-bottom at 1080 width). */
  safeX: Math.round(80 * unit),
  safeY: Math.round(100 * unit),
  /** Minimum sizes (84 / 44 at 1080 width). */
  headline: Math.round(84 * unit),
  support: Math.round(44 * unit),
} as const;

/**
 * Browser window placement on the stage. The recorded viewport is 1440x900 CSS px; the
 * window content is drawn at exactly that size, so 1 CSS px = 1 canvas px. If you record
 * at another viewport size, change it here and in capture/playwright.config.ts.
 */
const viewport = { width: 1440, height: 900 } as const;
const barHeight = 46;
const windowWidth = viewport.width;
const windowHeight = viewport.height + barHeight;
const windowLeft = (canvas.width - windowWidth) / 2;
const windowTop = Math.round((canvas.height - windowHeight) / 2);

export const browser = {
  viewport,
  barHeight,
  radius: 18,
  width: windowWidth,
  height: windowHeight,
  left: windowLeft,
  top: windowTop,
  /** Top-left of the app content area on the canvas. */
  contentLeft: windowLeft,
  contentTop: windowTop + barHeight,
} as const;

/** Shared motion curve for entrances. */
export const easeOutExpo = [0.16, 1, 0.3, 1] as const;
