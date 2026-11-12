# Product video kit

A kit and an agent skill that make narrated product walkthrough videos from a real web
app. A script drives the app in a browser and records it. A voice model reads the
narration. A second script builds and checks the video. Nothing is edited by hand, so a
video can be made again when the product changes.

This folder is self-contained. It has no paths or settings from the computer where it
was made.

## What is in this folder

```text
product-video/
  SKILL.md            instructions for an AI agent (the procedure and the rules)
  README.md           this file
  references/         detail for each stage: recording, script, voice, edit, verify
  assets/kit/
    capture/          Playwright recorder, assembler, example tour, example site
    video/            Remotion project, voice tool, timeline report, final checks
```

## Requirements

| Tool | Version | Note |
| --- | --- | --- |
| Node.js | 24 or later | The voice tool loads the TypeScript script files directly. |
| ffmpeg and ffprobe | a current release | Tested with 9.0.2. |
| Chromium | installed by Playwright | `npx playwright install chromium` |
| ElevenLabs API key | — | For narration and for the transcript checks. |
| Disk space | about 2 GB | Dependencies, and about 0.5 GB of frames for each 10 minutes recorded. |

Install the tools on macOS with Homebrew: `brew install node ffmpeg`. On Linux, use the
distribution packages or the official builds, and run
`npx playwright install --with-deps chromium`.

Licences to check before you publish a video:

- **Remotion** needs a company licence for some organisations. Read
  <https://github.com/remotion-dev/remotion/blob/main/LICENSE.md>.
- **ElevenLabs** voices are covered by the plan's terms of use.
- **Fonts, logos and photos**: the kit ships none. Add only files that you may publish.

## Install the skill

Copy this folder into the skills folder of your agent. The folder name must stay
`product-video`.

| Agent | Skills folder |
| --- | --- |
| Claude Code | `~/.claude/skills/` (or `.claude/skills/` in a project) |
| Codex and other agents that use the shared path | `~/.agents/skills/` |
| OpenCode | `~/.config/opencode/skills/` |

Then ask the agent for a product video. A person can also use the kit without an agent:
the sections below are complete.

## Set up

Copy the kit to a durable working folder. Do not work inside the skills folder or in a
temporary folder.

```sh
cp -R <path to this folder>/assets/kit ~/work/my-product-video
cd ~/work/my-product-video

cd capture
npm ci
npx playwright install chromium

cd ../video
npm ci
```

Give the voice tool the key through the environment. Use your secret store; do not put
the key in a project file.

```sh
export ELEVENLABS_API_KEY_FILE=/path/to/a/file/that/holds/the/key
# or: export ELEVENLABS_API_KEY=...
```

## Test the kit

This run records a small example site that ships with the kit, and makes a 48-second
video. It proves that each tool works on this computer. It uses about 500 characters of
ElevenLabs credit.

```sh
# 1. Record and assemble (about 30 seconds)
cd capture
DEMO_PACE=1.6 npx playwright test
node assemble.mjs
#   expect: example-01-signup: about 18s, … cut 1 range(s); beats form@0.0 submit@8.0 dashboard@11.1 end@17.8
#   (times differ by a few tenths of a second on each run)

# 2. Unit tests, types and lint
cd ../video
npm test                 # expect: pass 9, fail 0
npm run lint             # expect: no output after the command lines

# 3. Copy the clip and look at the footage lengths
npm run clips
npm run beats            # expect about: example-01-signup (18s): form 8.0 | submit 3.1 | dashboard 6.8

# 4. Narration: set "voiceId" in voice.config.json first, or pass --voice <id>
npm run voiceover -- example --dry-run     # expect: 6 to generate (514 chars)
npm run voiceover -- example               # expect: six lines that start with ✓

# 5. Timeline, render, checks
npm run timeline         # expect: == example: 6 scenes, about 0:46  /  no flags
npm run render -- example                  # writes out/example.mp4
npm run check -- example # expect: 6/6 passages present, true peak about -1.5 dBTP
npm run sheet -- example # writes out/check/example-sheet-01.jpg, …
```

Without a key, steps 1 to 3 still work, and `npm run render -- example --allow-silent`
gives a picture-only draft.

## Make your own video

The full procedure is in [SKILL.md](SKILL.md). In short:

1. Set the brand in `video/src/brand/tokens.ts` and the voice in
   `video/voice.config.json`.
2. Write tours for your app in `capture/tours/` and record them with
   `DEMO_BASE_URL=<your local app> DEMO_PACE=1.6 npx playwright test`. See
   [references/recording.md](references/recording.md).
3. Write one script for each video in `video/src/script/` and register it in
   `index.ts`. See [references/script.md](references/script.md).
4. Generate the narration, tune the timeline, render and check. See
   [references/voice.md](references/voice.md), [references/edit.md](references/edit.md)
   and [references/verify.md](references/verify.md).

Record a local build with disposable data. A tour signs up users and writes data.

## Commands

| Where | Command | Result |
| --- | --- | --- |
| `capture` | `npx playwright test` | Records each tour in `tours/` to `../out/clips/`. |
| `capture` | `node assemble.mjs [clip...]` | `../out/mp4/<clip>.mp4` and `.json`. |
| `video` | `npm run clips` | Copies new clips into `public/clips`. |
| `video` | `npm run beats [prefix]` | Footage length between beats. |
| `video` | `npm run voiceover -- <video>` | Narration in `public/voiceover/<video>/`. |
| `video` | `npm run timeline` | Scene count, length and flags. |
| `video` | `npm run dev` | Remotion Studio preview. |
| `video` | `npm run render -- <video...>` | `out/<video>.mp4`. |
| `video` | `npm run check -- <video...>` | Transcript comparison, loudness, silences. |
| `video` | `npm run sheet -- <video>` | Contact sheets in `out/check/`. |

## What was tested

Tested on 12 Nov 2026 on macOS (Apple silicon) with Node 24.22.1, Playwright 1.62.1,
Remotion 4.0.539, ffmpeg 9.0.2, ElevenLabs model `eleven_v4` and transcriber
`scribe_v2`:

- The full "Test the kit" run above, in a clean copy of the kit installed from the lock
  files.
- The failure paths: no key, no voice id, unknown script, unknown scene, render with
  missing or unverified audio, a rejected take that is generated again.

Not tested: Linux and Windows, other voice models, other browsers. The method was first
used for a set of four videos with 113 scenes and 27 minutes in total.

## Limits

- The recorder works with Chromium only.
- The edit expects a 1440×900 recording. To change it, change the viewport in
  `capture/playwright.config.ts` and in `video/src/brand/tokens.ts`.
- The tools check which words are said. They cannot judge how a name sounds. A person
  must listen once.
- English narration only: the transcript comparison folds English spellings and numbers.
