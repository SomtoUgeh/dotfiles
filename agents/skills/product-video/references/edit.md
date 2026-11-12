# Edit and render

`video/` is a Remotion project. One generic composition renders each script. No scene is
edited by hand: change the script, the brand tokens or the tour, then render again.

## Brand

Change `video/src/brand/tokens.ts` first:

| Token | Meaning |
| --- | --- |
| `brand.name` | Text wordmark on the cards when no logo is set. |
| `brand.host` | Host in the address bar. It replaces the recorded local host. |
| `brand.logo`, `brand.logoOnPrimary` | Logo files in `public/brand`, for the light card and the primary-colour cards. |
| `brand.fonts`, `fontFamily` | Font files in `public/fonts` and the font stack. Use only fonts whose licence covers video. |
| `brand.urlScaffold` | Path segments to hide when an id follows them. |
| `color.*` | Card, stage, caption and shadow colours. |
| `captionCharEm` | Average character width of the font. Measure again for a new font, or the camera misjudges the caption width. |

The address bar never shows the local host, the locale prefix, the query string or
opaque ids.

## What the edit does

- **Timeline** (`src/video/timeline.ts`): reads the script, the clip JSON files and the
  voice manifest, measures each audio file, and computes each scene length (see
  [script.md](script.md)). Scenes cross-fade for 0.6 s. It prints one `[timeline]` line
  for each video.
- **Browser frame**: the footage sits in a drawn browser window on a soft stage.
- **Camera** (`src/lib/camera.ts`): with `zoom: "auto"` it groups click, type and hover
  events that are close in time (2.5 s) and space, zooms to fit the group (maximum
  1.45), holds for 1.4 s, and releases on a page change. Hover-only groups zoom to 1.3
  at most. The footage is 2x, so the zoom stays sharp.
- **Cursor** (`src/lib/cursor.ts`): a drawn pointer glides between the logged targets,
  becomes an I-beam on text fields and shows a ripple on clicks.
- **Caption**: sits in a bottom corner, selects the side that covers less of the action,
  and leaves before a click reaches it.
- **Cards**: `intro`, `chapter` and `outro` scenes are title cards.

## Tune the timeline

```sh
cd video
npm run clips        # copy new clips from ../out/mp4 into public/clips
npm run timeline     # scene count, length and flags for each video
```

The report flags two faults:

| Flag | Meaning | Fix in the script |
| --- | --- | --- |
| `silent N s` | More than 3.5 s of the scene has no narration. | Start the scene at a later beat, split it in two, or add a sentence about what the screen shows. |
| `frozen, voice runs N s past footage` | The last frame freezes for more than 3 s. | Set `to` to a later beat or `"end"`, shorten the passage, or record again with a longer pause. |

It also lists each passage with no fresh audio. Run the voice tool for those videos.
Repeat until the report shows `no flags`. A long hold on a page that the narrator
explains in detail is acceptable; decide each remaining flag on purpose.

`npm run timeline -- --strict` exits with `1` when a flag or stale audio remains.

## Preview and render

```sh
npm run dev                         # Remotion Studio: scrub the timeline in a browser
npm run render -- <video...>        # out/<video>.mp4, 1920x1080, 30 fps, h264 + aac
npm run render -- <video> --allow-silent   # picture-only draft
```

`render` refuses to start when a passage has no fresh audio or is not verified. It exits
with `2` and lists the passages.

The first render downloads a headless browser for Remotion. A 5-minute video takes a few
minutes on a laptop.

## Failures

| Symptom | Cause | Action |
| --- | --- | --- |
| `Missing public/clips/<clip>.json` | The clip is not assembled or not copied. | Run `node assemble.mjs` in `capture`, then `npm run clips`. |
| `Clip "…" has no beat "…"` | A typing error in `from` or `to`, or the tour changed. | The error lists the known beats. Correct the script. |
| `Segment … is empty` | `to` is before `from`. | Correct the range. |
| A scene shows the previous page for a moment | The range starts before the page change. | Start at a later beat, or use seconds (see [script.md](script.md)). |
| The camera zooms to the wrong place | Events of two areas are in one group. | Use `zoom: "off"` or a fixed region for that scene. |
| The caption covers the action | Automatic placement had no clear side. | Set `captionPlacement`, or shorten the caption. |
