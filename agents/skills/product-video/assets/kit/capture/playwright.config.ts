import { defineConfig } from "@playwright/test";

// Recording runs. Each `*.demo.ts` step drives the real app at a viewer's pace while
// recorder.ts streams 2x frames and cursor events for the video edit.
//
// DEMO_BASE_URL  the app to record. Unset: the bundled example site is started and used.
// DEMO_PACE      multiplier for every viewer-facing wait (default 1; 1.6 is a calm pace).
// DEMO_OUT       where frames and events go (default ../out).
//
// Record a local build only. A tour signs up users and writes data.
const exampleUrl = "http://127.0.0.1:4173";
const baseURL = process.env.DEMO_BASE_URL ?? exampleUrl;

export default defineConfig({
  fullyParallel: false,
  reporter: [["list"]],
  retries: 0,
  testDir: "./tours",
  testMatch: "**/*.demo.ts",
  timeout: 20 * 60_000,
  use: {
    // A blocked click must fail the take, not hang it until the test timeout.
    actionTimeout: 30_000,
    baseURL,
    // Keep these two in step with `browser.viewport` in video/src/brand/tokens.ts.
    viewport: { height: 900, width: 1440 },
    deviceScaleFactor: 2,
    launchOptions: {
      args: [
        "--hide-scrollbars",
        "--autoplay-policy=no-user-gesture-required",
        // Uncomment for flows that open the camera or microphone:
        // "--use-fake-device-for-media-stream",
        // "--use-fake-ui-for-media-stream",
      ],
    },
    locale: "en-GB",
    timezoneId: "Europe/London",
    screenshot: "only-on-failure",
    trace: "off",
    video: "off",
  },
  webServer: process.env.DEMO_BASE_URL
    ? undefined
    : {
        command: "node example-site/serve.mjs",
        url: exampleUrl,
        reuseExistingServer: true,
      },
  workers: 1,
});
