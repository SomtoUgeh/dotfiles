# Final checks

A render that completes is not proof that the video is correct. Check the file itself.

## Commands

```sh
cd video
npm run check -- <video...>          # transcript, loudness, peak, silences
npm run check -- <video> --no-stt    # loudness and silences only; no API key needed
npm run sheet -- <video>             # contact sheets: one frame every 8 s
npm run sheet -- <video> --every 4
```

`check` writes `out/check/<video>-stt.json` and exits with `0` when each passage is
heard, `1` on an error and `2` when a passage or a name is not heard.

## What to check

| Check | Pass | If it fails |
| --- | --- | --- |
| Each passage is in the transcript | `N/N passages present` | A `NOT HEARD` line names the scene. Look at that scene in the timeline: the audio is missing, stale or cut by a too-short scene. |
| Each configured name | heard count is not less than the script count | Listen to that scene. Generate the passage again, or add a `heard` pattern if the sound is right (see [voice.md](voice.md)). |
| True peak | at or below -1.0 dBTP | Lower `targetLufs` in `voice.config.json` and master again. |
| Loudness | the same within 1 LU across the videos of one set | Master again with one `targetLufs` for all. |
| Silences over 3 s | only at chapter cards and at pages that are shown on purpose | Fix the scene in the script (see [edit.md](edit.md)). |
| Contact sheets | cards, captions, zooms and pages look as planned; no blank or half-loaded page; no private data | Fix the tour or the script and render again. |

A `note` line lists single words that the transcriber wrote in another way. It is not a
failure. Add a `spellings` pair if the same word repeats.

Measure loudness on the rendered MP4. A re-encoded copy can show a higher peak than the
file has. The mono narration at -17 LUFS reads about 3 LU louder in the stereo file.

## What a person must check

Tell the user plainly that these checks are not done by the tools:

- The sound of a product name and of unusual words. The transcript shows which words
  were said, not how they sound.
- The tone and accent of the voice for the audience.
- That no real customer data, email address or secret is visible in the footage.

## Report

Give the user, for each video: the file path, the length, the number of passages
present, the loudness and peak, the longest silence, and the checks that a person must
still do. If a check was not run, say so.
