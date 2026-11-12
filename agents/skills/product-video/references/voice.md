# Narration

`video/scripts/voiceover.mjs` generates one audio clip for each voiced scene with the
ElevenLabs API, verifies each clip against the script, and masters the pace and loudness.

```sh
cd video
npm run voiceover -- <video> --dry-run      # shows what it would generate; no API call
npm run voiceover -- <video>                # generate, verify, master
npm run voiceover -- <video> --only intro,signup
npm run voiceover -- <video> --force        # generate again, also when the text is unchanged
```

Other flags: `--voice <voiceId>`, `--model <id>`, `--variant <name>` (a second set of
audio in `public/voiceover/<video>--<name>`), `--no-verify`.

Exit codes: `0` all clips verified, `1` error, `2` one or more clips not verified.

## Key

The tool reads the key from `ELEVENLABS_API_KEY`, or from the file named by
`ELEVENLABS_API_KEY_FILE`. Get the key from the user's secret store. Do not write it into
a file in the project, a command argument, a log or a commit.

## voice.config.json

```json
{
  "voiceId": "<voice id from the ElevenLabs voice library>",
  "model": "eleven_v4",
  "settings": { "stability": 0.6, "similarity_boost": 0.8 },
  "pronunciations": [
    { "written": "Erivault", "spoken": "Eri-Vault",
      "heard": ["(e|i|ai|ae|a)r+[aeiy]{1,2} ?v(au|aw|o)lts?"] }
  ],
  "spellings": [["\\bdoughnut", "donut"]],
  "master": { "tempo": 0.92 }
}
```

- **`voiceId`**: the voice is the user's choice. Ask for it if the user did not name one.
  A script can override it with `voice: { voiceId }`.
- **`model`**: the account decides which models are available. The API error names the
  model when the account cannot use it. `eleven_v3` and `eleven_v4` accept only
  `stability` and `similarity_boost`. Older models also get a speed setting of 0.94.
- **`pronunciations`**: see below.
- **`spellings`**: extra `[pattern, replacement]` pairs for words that the transcriber
  spells in two ways. They apply to both sides of the comparison.
- **`master`**: overrides for the mastering values listed below.

## What the tool does

**Generate.** `POST /v1/text-to-speech/{voice_id}/with-timestamps` with the passage, the
model, the settings and a seed. The response holds the audio and a start and end time
for each character. Each passage is one complete request with no `next_text` or
`previous_text`. With `next_text`, the voice reads a sentence as if more follows and
does not land the ending. Listeners hear that as "the voice stops in the middle of a
sentence".

**Verify.** The tool transcribes each take with `POST /v1/speech-to-text`
(`scribe_v2`) and compares the words with the script. It rejects a take when:

- more than one word in 14 differs (word edit distance),
- the last three words differ, or
- a configured name is not heard correctly.

A rejected take is generated again with another seed, up to four attempts for each run.
When all attempts fail, the last take is saved and marked `verified: false` in the manifest.
The next run tries a failed passage again with new seeds.

**Master.**

1. Find each punctuation mark in the character timings. In the gap after it, find the
   quietest 20 ms and insert silence there: 0.3 s after `.`, `?`, `!`; 0.2 s after `:`
   and `;`; 0.1 s after `,`. A 6 ms fade on each side prevents a click.
2. Slow the clip with ffmpeg `atempo` (default 0.92; pitch does not change).
3. If the clip is still faster than 156 words a minute, slow it more, down to 0.84.
4. Measure loudness, then apply one fixed gain to reach -17 LUFS. Cap the true peak at
   -1.5 dBTP. A fixed gain does not pump.
5. Write a 48 kHz mono WAV.

Mastering values and their `master` keys: `tempo` 0.92, `maxWpm` 156, `minTempo` 0.84,
`targetLufs` -17, `sentence` 0.3, `clause` 0.2, `comma` 0.1, `quietRms` 0.02.

**Cache.** For each scene the tool keeps the raw take (`<id>.raw.mp3`), the timings
(`<id>.align.json`) and the mastered `<id>.wav`. `manifest.json` records the text hash,
length, pace and result. A passage with the same text, voice, model and settings is not
generated again. A change to a mastering value masters the saved takes again and makes
no API call. The manifest is saved after each passage, so an interrupted run keeps what
it paid for.

## Product names

A voice model reads an invented word by its spelling and can get it wrong. The transcriber
also has no fixed spelling for it. A `pronunciations` entry handles both:

- `written`: the name as it appears in the script.
- `spoken`: the spelling that makes the model say it correctly. Find it by trial: try a
  hyphen between syllables first.
- `heard`: patterns (JavaScript regular expressions, lower case, no anchors) for the ways
  the transcriber writes the *correct* sound. The written and spoken forms are accepted
  automatically.

Procedure for a new name:

1. Add the entry with `written` and `spoken` only. Run one passage that contains the name.
2. Read the `heard:` line that the tool prints for a rejected take. Ask a person to
   listen to the raw take once and say if the sound is right.
3. If the sound is right, add a pattern that matches that spelling. If it is wrong, do
   not add a pattern: change `spoken`, or let the tool try other seeds.
4. Keep the patterns narrow. They must reject the wrong sounds that you saw.

Worked example (verified with live calls): written "Erivault" was read as "Erivo". Spoken
"Eri-Vault" gives three syllables. The transcriber then writes "Ari Vault", "Arivault"
or "Airevault", which the pattern above accepts. It rejects "Airvault" (two syllables),
"Every Vault" and "Erivo".

## Failures

| Symptom | Cause | Action |
| --- | --- | --- |
| `No ElevenLabs key` | Neither variable is set. | Get the key from the user's secret store. |
| `ElevenLabs 401` | The key is wrong or revoked. | Ask the user for a valid key. Do not retry. |
| `ElevenLabs 4xx` that names the model or voice | The account cannot use it. | Report it. Ask the user which voice or model to use. Do not select another one without asking. |
| Output falls back to 128 kbps | The plan does not allow 192 kbps. | No action. The tool falls back once and continues. |
| `UNVERIFIED: <ids>` (exit 2) | Four takes of a passage failed. | Read the `heard:` lines. Reword the passage: move the name earlier, split a long sentence, replace a word the model stumbles on. Then run again. |
| Pace above 165 wpm in the manifest | A fast take at the slowest allowed tempo. | Reword the passage into shorter sentences, or lower `minTempo`. Below 0.8 the voice sounds slow-motion. |
| Passage sounds cut at the end | The text ends without a full stop, or it is one clause of a longer sentence. | Make the passage a complete paragraph that ends with a full stop. |

## Limits

- The tool cannot read the credit balance with a key that lacks the `user_read`
  permission. Use `--dry-run` to see the character count before a large run.
- An agent cannot judge a vowel sound by ear. The transcript shows which words were
  said, not how they sound. A person must listen to a product name once.
- Contract checked with live calls on 12 Nov 2026: model `eleven_v4`, `scribe_v2`,
  output `mp3_44100_128`. Check the current ElevenLabs API reference when a call fails
  with a schema error.
