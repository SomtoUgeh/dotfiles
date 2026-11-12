# Recording

The `capture/` folder records the real app with Playwright and writes one clip per test.
Chromium only: the recorder uses the Chrome DevTools Protocol.

## Why a custom recorder

Playwright's built-in video cannot remove waits, and its picture is too soft for zooms.
The recorder in `capture/recorder.ts` does three things instead:

- It saves a JPEG frame at 2x scale in a loop, each with a timestamp.
- It logs each action with the bounding box of its target. The edit draws the cursor and
  aims the camera from these events. Screenshots do not contain the mouse pointer.
- It logs the ranges that the viewer must not see. The assembler removes them.

## Settings

`capture/playwright.config.ts` holds the settings. Keep these values:

| Setting | Value | Reason |
| --- | --- | --- |
| `viewport` | 1440×900 | The edit draws the footage at this size. Change both sides together (`browser.viewport` in `video/src/brand/tokens.ts`). |
| `deviceScaleFactor` | 2 | Sharp picture when the camera zooms. |
| `workers` / `retries` | 1 / 0 | One take at a time. A retry would record over a good clip. |
| `actionTimeout` | 30 s | A blocked click fails the take. It does not hang it. |
| `video` / `trace` | off | They slow the page and are not used. |
| `locale`, `timezoneId` | fixed | Dates and formats are the same on each computer. |
| `--hide-scrollbars` | on | Scrollbars look different on each system. |

Environment variables:

| Variable | Default | Meaning |
| --- | --- | --- |
| `DEMO_BASE_URL` | the example site | The app to record. Use a local build. |
| `DEMO_PACE` | `1` | Multiplier for each viewer-facing wait and typing delay. Use `1.6` for narrated videos. |
| `DEMO_OUT` | `../out` | Where frames, events and assembled clips go. |

## Recorder methods

```ts
const rec = await Recorder.start(page, "tenant-01-signup"); // lower-case, digits, hyphens
```

| Method | What the viewer sees |
| --- | --- |
| `rec.beat(id)` | Nothing. It names a moment. Scenes are cut at beats. |
| `rec.pause(ms)` | The screen stays still, so the viewer can read it. |
| `rec.click(locator, { after })` | The pointer moves to the target, clicks, then waits. |
| `rec.type(locator, text, { delay })` | The text appears one character at a time. |
| `rec.fill(locator, text)` | A long value appears at once. |
| `rec.select(locator, value)` | An option is selected in a native `<select>`. |
| `rec.hover(locator, { after })` | The pointer points at something. The camera can zoom to it. |
| `rec.scroll(dy)` | A smooth scroll. |
| `rec.offAir(async () => { … })` | Nothing. The time inside is cut from the clip. |
| `rec.stop()` | Ends the clip and logs the final beat `end`. |

All times are in milliseconds before `DEMO_PACE` is applied.

## Rules for a tour

1. One test records one clip. Use `test.describe.configure({ mode: "serial" })`.
2. Open the page and wait until it is ready before `Recorder.start`.
3. Put a beat at each point where the narration changes subject. Add more beats than you
   think you need. A beat costs nothing, and a missing beat means a new recording.
4. Put a `pause` after each new screen. The narrator needs time to describe it. If a
   scene later shows a frozen frame, the pause was too short.
5. Wrap each wait that a viewer must not watch in `offAir`: seeding data, uploads, slow
   loads, email delivery. The recorder comes back on air only when it has a frame of the
   finished state.
6. Use believable people, addresses and numbers. The narration names them.
7. Each test starts with a new browser context. Pass ids between tests through a small
   JSON file, and sign in again at the start of each test.
8. Reset the test data before each full run. A second run on used data shows different
   screens.

## Tours that need the app's test helpers

A real product tour usually needs the app's helpers for sign-in, seeding and test email.
In that case:

1. Copy `capture/recorder.ts` into the app's end-to-end test folder.
2. Add a Playwright config there with the settings from the table above, and with the
   app's own `globalSetup` and environment.
3. Set `DEMO_OUT` to the absolute path of the kit's `out` folder, so that
   `capture/assemble.mjs` and the edit find the clips.

## Camera and microphone screens

Chromium's fake camera shows a test pattern. For a screen that opens the camera, replace
`navigator.mediaDevices.getUserMedia` in `context.addInitScript` with a function that
returns `canvas.captureStream(30)`. Draw a photo on the canvas with a slow drift so that
it looks hand-held. Serve the photo with `context.route` from the app's own origin, so
that the canvas stays readable. Grant the `camera` permission in the context options and
enable the two `--use-fake-…-for-media-stream` flags in the config. Use only photos that
you may publish.

## Assemble

```sh
cd capture
node assemble.mjs              # every recorded clip
node assemble.mjs <clip...>    # named clips only
```

Each clip gives `out/mp4/<clip>.mp4` (30 fps, h264) and `out/mp4/<clip>.json`. A shortened example:

```json
{ "clip": "example-01-signup", "duration": 17.8, "fps": 25.2,
  "events": [ { "t": 0, "type": "beat", "id": "form" },
              { "t": 1.9, "type": "type", "box": { "x": 460, "y": 262, "width": 520, "height": 52 } },
              { "t": 11.1, "type": "url", "url": "http://127.0.0.1:4173/welcome" } ] }
```

Times are seconds on the cut timeline. The edit reads only these two files.

## Failures

| Symptom | Cause | Action |
| --- | --- | --- |
| `no "end" beat` from the assembler | The tour is still running, or it failed before `rec.stop()`. | Wait for the run to end. Fix the tour and record the clip again. |
| The picture freezes after a page change | A capture stalled during the navigation. | The kit's recorder drops the stalled capture. If you copied an older recorder, copy the current one. |
| A clip shows a spinner or a long wait | The wait is on air. | Move it into `offAir` and record again. |
| Frame rate below 15 fps | The page is heavy or the computer is busy. | Close other work. Do not run two recordings at once. |
| The second run shows other screens | Test data from the first run. | Reset the data and record again. |
| A click times out | The locator is wrong, or an overlay covers the target. | Fix the tour. Do not raise the timeout. |
