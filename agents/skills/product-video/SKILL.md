---
name: product-video
description: "Make a narrated product walkthrough video from a real web app: a Playwright recording, a scene script, ElevenLabs narration that is transcribed and verified, a Remotion edit, and final checks. Use when asked to make, remake, slow down, lengthen, or revise a product demo, walkthrough, tour, or explainer video of an app."
license: "UNLICENSED"
compatibility: "Needs Node 24 or later, ffmpeg with ffprobe, Chromium through Playwright, and an ElevenLabs API key. Tested on macOS."
---

# Product video

## Purpose

Produce a narrated walkthrough video of a web app from the real product, with no manual
editing. The result is `video/out/<video>.mp4` (1920×1080, 30 fps) and a check report.

The work is a pipeline. Each stage has a tool in [the kit](assets/kit):

1. **Record**: Playwright drives the app at a viewer's pace. A recorder saves frames and
   events.
2. **Assemble**: one MP4 and one event file for each clip, with the waits removed.
3. **Script**: one data file for each video lists the scenes, footage ranges and
   narration.
4. **Voice**: ElevenLabs reads each passage. Each take is transcribed, compared with the
   script, and mastered for pace and loudness.
5. **Edit**: Remotion builds the video from the script. Scene lengths come from the audio
   and the footage.
6. **Check**: the rendered file is transcribed and measured.

To change a video, change the tour or the script and run the stages again.

## Rules

- Record a local build with disposable data. A tour signs up users and writes data.
  Do not point it at a deployed environment unless the user says so for that
  environment.
- Read the ElevenLabs key from the user's secret store through `ELEVENLABS_API_KEY` or
  `ELEVENLABS_API_KEY_FILE`. Do not print it, write it to a project file, or commit it.
- The voice and the model are the user's choice. Ask once if they are not given. Do not
  change them on your own.
- Narration costs credits. Run `--dry-run` first and tell the user the character count
  before the first full run of a new project.
- Keep the working copy of the kit in a durable folder. Do not work in a system
  temporary folder: recordings and paid audio are lost when it is cleaned.
- Do not commit recordings, audio or renders. The kit's `.gitignore` files exclude them.
- Footage plays at recorded speed. To slow a video, record with a higher `DEMO_PACE`.
  Do not change the playback rate.
- Use only fonts, logos and photos that the user may publish.

## Procedure

1. **Set up.** Copy `assets/kit` from this skill's folder to a durable folder for the
   project (default: `product-video/` beside the app repository). Install it and run the
   example as the [README](README.md) describes under "Set up" and "Test the kit". Stop
   and repair the setup if the example does not pass.
2. **Agree the outline.** From the request, list the videos, the audience of each, the
   flows to show and the demo data (people, addresses, numbers). Ask only for what the
   request and the app do not tell you.
3. **Brand.** Set the name, host, logos, fonts and colours in
   `video/src/brand/tokens.ts`. Set `voiceId` and `model` in `video/voice.config.json`.
   Add a `pronunciations` entry for a product name with an unusual spelling. See
   [voice.md](references/voice.md).
4. **Write the tours.** One test records one clip. Follow
   [recording.md](references/recording.md). Run each tour once at `DEMO_PACE=1` to prove
   that it passes.
5. **Record and assemble.** Reset the test data. Record with `DEMO_PACE=1.6`. When the
   run has ended, run `node assemble.mjs` in `capture`, then `npm run clips` in `video`.
   Look at a contact sheet of each clip (`npm run sheet -- ../out/mp4/<clip>.mp4`).
6. **Write the scripts.** Run `npm run beats` for the footage lengths. Write one complete
   paragraph for each scene, sized to its footage. Follow
   [script.md](references/script.md). Register each script in `src/script/index.ts`.
7. **Generate the narration.** `npm run voiceover -- <video> --dry-run`, then without
   `--dry-run`. Reword each passage that stays unverified. See
   [voice.md](references/voice.md).
8. **Tune.** Run `npm run timeline`. Remove each `silent` and `frozen` flag in the
   script, or decide on purpose to keep it. Run the voice tool again for changed
   passages. See [edit.md](references/edit.md).
9. **Render.** `npm run render -- <video...>`.
10. **Check.** `npm run check -- <video...>` and `npm run sheet -- <video>`. Look at each
    contact sheet. Repair and render again until each check in
    [verify.md](references/verify.md) passes.
11. **Deliver.** Copy the final files to the folder the user names, with `ffmpeg -i
    <in> -c copy -movflags +faststart <out>`. Report as [verify.md](references/verify.md)
    describes, including the checks that a person must still do.

For a revision of an existing video, start at the stage that changes: step 4 for new
footage or a new pace, step 6 for new wording, step 3 for a new voice. Later stages
always run again.

## Failure handling

- A stage tool exits with a non-zero code when its result is not usable. Do not go to the
  next stage. Each reference has a failure table for its stage.
- Exit code `2` from `voiceover`, `render` or `check` means a narration problem: a
  passage is missing, stale or not verified. Fix the passage. Do not pass
  `--no-verify` or `--allow-silent` to get a final video.
- If the API rejects the key, the voice or the model, report it and ask the user. Do not
  switch to another voice, model or provider.
- If a tour fails, fix the tour. Do not assemble a clip from a failed run.
- If the same repair fails twice, stop and re-examine the cause before a third attempt.

## Completion

- Each requested video exists at the agreed path, and its length is reported.
- `npm run check` exits with `0` for each video: each passage is present, and each
  configured name is heard.
- `npm run timeline` shows no flag that was not accepted on purpose.
- The contact sheets were looked at.
- The report states what a person must still check: the sound of product names, the
  voice for the audience, and private data in the footage.
- Nothing was committed or published unless the user asked for it.

## Resources

| Resource | Use |
| --- | --- |
| [README.md](README.md) | Requirements, setup on a new computer, the kit self-test, tested versions. |
| [references/recording.md](references/recording.md) | Recorder methods, tour rules, capture settings, assembly. |
| [references/script.md](references/script.md) | Scene format, narration rules, cut points. |
| [references/voice.md](references/voice.md) | Voice tool, config file, verification, mastering, product names. |
| [references/edit.md](references/edit.md) | Brand tokens, timeline report, camera, render. |
| [references/verify.md](references/verify.md) | Final checks, thresholds, the report. |
| [assets/kit](assets/kit) | The tools: `capture/` (recorder, assembler, example tour and site) and `video/` (Remotion project, voice tool, checks). |
