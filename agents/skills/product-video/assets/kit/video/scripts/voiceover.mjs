#!/usr/bin/env node
// Generate per-scene voiceover with ElevenLabs, cached by text hash, and verify every clip.
//
//   node scripts/voiceover.mjs <video> [--voice <voiceId>] [--variant <name>] [--model <id>]
//        [--only a,b] [--force] [--dry-run] [--no-verify]
//
// Reads src/script/<video>.ts (data-only TypeScript, loaded with Node's type stripping) and
// voice.config.json. Writes public/voiceover/<video>[--<variant>]/<sceneId>.wav and a
// manifest.json that the composition uses to find fresh audio. Unchanged passages (same
// text, voice, model, settings) are skipped.
//
// Each scene's passage is one self-contained request: no `next_text`, so the voice lands the
// last sentence instead of trailing off as if more were coming. Every clip is then transcribed
// (Scribe) and compared with the script; a clip that drops, adds or mangles words, or says a
// configured name wrongly, is generated again with another seed.
//
// Exit codes: 0 all clips verified, 1 error, 2 one or more clips could not be verified.
// API key: $ELEVENLABS_API_KEY, else the file named by $ELEVENLABS_API_KEY_FILE.

import { createHash } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

import { loadConfig, loadScript, makeText, projectRoot, readApiKey, transcribe } from "./lib/shared.mjs";

const OUTPUT_FORMATS = ["mp3_44100_192", "mp3_44100_128"];
const BASE_SEED = 1729;
const MAX_ATTEMPTS = 4;
const SAMPLE_RATE = 44100;

// Mastering. A voice model can read faster than a product video needs, and some models have
// no speed setting. So: lengthen the pauses the voice already makes at punctuation (found
// with the API's character timings), slow the whole clip slightly without changing pitch,
// and bring every clip to the same loudness. Override any value in voice.config.json
// under "master".
const MASTER_DEFAULTS = {
  /** Playback tempo for every clip (1 = as generated). */
  tempo: 0.92,
  /** A take that still reads faster than this is slowed further, down to minTempo. */
  maxWpm: 156,
  minTempo: 0.84,
  targetLufs: -17,
  /** Seconds of silence added at each kind of pause. */
  sentence: 0.3,
  clause: 0.2,
  comma: 0.1,
  /** A pause is only lengthened where the audio really is quiet (RMS, full scale = 1). */
  quietRms: 0.02,
};

/** v3 and v4 take stability and similarity only; v2 also takes style, speed and speaker boost. */
const settingsFor = (model, overrides) => {
  const base = { stability: 0.6, similarity_boost: 0.8, ...overrides };
  if (model.startsWith("eleven_v4") || model.startsWith("eleven_v3")) {
    return { stability: base.stability, similarity_boost: base.similarity_boost };
  }
  return { style: 0, use_speaker_boost: true, speed: 0.94, ...base };
};

const USAGE =
  "Usage: node scripts/voiceover.mjs <video> [--voice <voiceId>] [--variant <name>] [--model <id>] [--only a,b] [--force] [--dry-run] [--no-verify]";

const parseArgs = (argv) => {
  const args = {
    video: null,
    voice: null,
    variant: null,
    model: null,
    only: null,
    force: false,
    dryRun: false,
    verify: true,
  };
  const value = (i) => {
    const v = argv[i];
    if (v === undefined || v.startsWith("--")) throw new Error(`${argv[i - 1]} needs a value\n${USAGE}`);
    return v;
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--voice") args.voice = value(++i);
    else if (a === "--variant") args.variant = value(++i);
    else if (a === "--model") args.model = value(++i);
    else if (a === "--only") args.only = new Set(value(++i).split(","));
    else if (a === "--force") args.force = true;
    else if (a === "--dry-run") args.dryRun = true;
    else if (a === "--no-verify") args.verify = false;
    else if (!a.startsWith("--") && !args.video) args.video = a;
    else throw new Error(`Unknown argument: ${a}\n${USAGE}`);
  }
  if (!args.video) throw new Error(USAGE);
  if (args.variant && !/^[a-z0-9-]+$/.test(args.variant)) {
    throw new Error("--variant takes lower-case letters, digits and hyphens");
  }
  return args;
};

let formatIndex = 0;

const synthesize = async ({ apiKey, voiceId, model, text, settings, seed }) => {
  for (;;) {
    const format = OUTPUT_FORMATS[formatIndex];
    const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}/with-timestamps?output_format=${format}`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "xi-api-key": apiKey, "Content-Type": "application/json" },
      body: JSON.stringify({ text, model_id: model, voice_settings: settings, seed }),
    });
    if (res.ok) {
      const json = await res.json();
      return {
        audio: Buffer.from(json.audio_base64, "base64"),
        alignment: json.alignment ?? null,
        format,
      };
    }
    const body = await res.text();
    // The higher bitrate needs a higher plan tier; fall back once, for the rest of the run.
    if (formatIndex < OUTPUT_FORMATS.length - 1 && /output_format|subscription|tier/i.test(body)) {
      formatIndex += 1;
      continue;
    }
    throw new Error(`ElevenLabs ${res.status}: ${body.slice(0, 500)}`);
  }
};

const rms = (pcm, from, to) => {
  let sum = 0;
  for (let i = from; i < to; i++) sum += (pcm[i] / 32768) ** 2;
  return Math.sqrt(sum / Math.max(1, to - from));
};

/** Where the voice pauses at punctuation: [{ at: sample index, add: seconds }]. */
const pausePoints = (pcm, alignment, m) => {
  if (!alignment) return [];
  const chars = alignment.characters;
  const starts = alignment.character_start_times_seconds;
  const ends = alignment.character_end_times_seconds;
  const frame = Math.round(0.02 * SAMPLE_RATE);
  const points = [];
  for (let i = 0; i < chars.length - 1; i++) {
    const c = chars[i];
    const add =
      c === "." || c === "?" || c === "!" ? m.sentence
      : c === ":" || c === ";" ? m.clause
      : c === "," ? m.comma
      : 0;
    if (!add || !/\s/.test(chars[i + 1])) continue;
    let j = i + 1;
    while (j < chars.length && /\s/.test(chars[j])) j++;
    if (j >= chars.length) continue;
    const from = Math.max(0, Math.round((ends[i] - 0.04) * SAMPLE_RATE));
    const to = Math.min(pcm.length - frame, Math.round((starts[j] + 0.04) * SAMPLE_RATE));
    // The quietest 20 ms inside the gap is where the silence goes.
    let best = -1;
    let bestRms = Infinity;
    for (let at = from; at <= to; at += Math.round(frame / 4)) {
      const level = rms(pcm, at, at + frame);
      if (level < bestRms) {
        bestRms = level;
        best = at + Math.round(frame / 2);
      }
    }
    if (best >= 0 && bestRms < m.quietRms) points.push({ at: best, add });
  }
  return points;
};

/**
 * Raw mp3 from the API → mastered wav: longer pauses at punctuation, the tempo, and a static
 * gain to the target loudness (static, so the level does not pump). Returns the number of
 * pauses lengthened.
 */
const master = (mp3Path, alignment, wavPath, wordCount, m) => {
  const decoded = execFileSync(
    "ffmpeg",
    ["-hide_banner", "-loglevel", "error", "-i", mp3Path, "-f", "s16le", "-ac", "1", "-ar", String(SAMPLE_RATE), "-"],
    { maxBuffer: 1 << 28 },
  );
  const pcm = new Int16Array(decoded.buffer, decoded.byteOffset, Math.floor(decoded.length / 2));
  const points = pausePoints(pcm, alignment, m).sort((a, b) => a.at - b.at);
  const fade = Math.round(0.006 * SAMPLE_RATE);
  const extra = points.reduce((n, p) => n + Math.round(p.add * SAMPLE_RATE), 0);
  const tail = Math.round(0.2 * SAMPLE_RATE);
  const out = new Int16Array(pcm.length + extra + tail);
  let read = 0;
  let write = 0;
  for (const p of points) {
    out.set(pcm.subarray(read, p.at), write);
    write += p.at - read;
    // Fade to silence, hold, fade back in, so the splice cannot click.
    for (let k = 0; k < fade && write - 1 - k >= 0; k++) out[write - 1 - k] = (out[write - 1 - k] * k) / fade;
    write += Math.round(p.add * SAMPLE_RATE);
    read = p.at;
    for (let k = 0; k < fade && read + k < pcm.length; k++) pcm[read + k] = (pcm[read + k] * k) / fade;
  }
  out.set(pcm.subarray(read), write);
  const edited = Buffer.from(out.buffer, out.byteOffset, out.byteLength);
  // Takes vary in pace. Even them out so no passage races ahead of the others.
  const wpmAtTempo = (wordCount / (out.length / SAMPLE_RATE / m.tempo)) * 60;
  const tempo = wpmAtTempo > m.maxWpm ? Math.max(m.minTempo, (m.tempo * m.maxWpm) / wpmAtTempo) : m.tempo;
  const input = ["-f", "s16le", "-ar", String(SAMPLE_RATE), "-ac", "1", "-i", "pipe:0"];
  const probe = spawnSync(
    "ffmpeg",
    ["-hide_banner", "-nostats", ...input, "-af", `atempo=${tempo.toFixed(4)},loudnorm=print_format=json`, "-f", "null", "-"],
    { input: edited, encoding: "buffer", maxBuffer: 1 << 28 },
  ).stderr.toString();
  const measured = Number(/"input_i"\s*:\s*"(-?[0-9.]+)"/.exec(probe)?.[1]);
  const peak = Number(/"input_tp"\s*:\s*"(-?[0-9.]+)"/.exec(probe)?.[1]);
  if (!Number.isFinite(measured)) throw new Error(`Could not measure loudness of ${mp3Path}`);
  // Never push the true peak above -1.5 dBTP.
  const gain = Math.min(m.targetLufs - measured, Number.isFinite(peak) ? -1.5 - peak : 0);
  const done = spawnSync(
    "ffmpeg",
    ["-hide_banner", "-loglevel", "error", "-y", ...input,
      "-af", `atempo=${tempo.toFixed(4)},volume=${gain.toFixed(2)}dB`,
      "-ar", "48000", "-ac", "1", "-c:a", "pcm_s16le", wavPath],
    { input: edited, maxBuffer: 1 << 28 },
  );
  if (done.status !== 0) throw new Error(`ffmpeg failed for ${wavPath}: ${done.stderr}`);
  return points.length;
};

const audioSeconds = (file) =>
  Number(
    execFileSync("ffprobe", [
      "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file,
    ]).toString(),
  );

const main = async () => {
  const args = parseArgs(process.argv.slice(2));
  const script = await loadScript(args.video);
  const config = await loadConfig();
  const { spoken, tokens, mismatch } = makeText(config);

  const voiceId = args.voice ?? script.voice?.voiceId ?? config.voiceId;
  if (!voiceId) {
    throw new Error('No voice: set "voiceId" in voice.config.json, or pass --voice <voiceId>');
  }
  const model = args.model ?? script.voice?.model ?? config.model;
  if (!model) throw new Error('No model: set "model" in voice.config.json, or pass --model <id>');
  const settings = settingsFor(model, { ...config.settings, ...script.voice?.settings });
  const m = { ...MASTER_DEFAULTS, ...config.master };
  // Changing a mastering value re-masters the saved takes; it never calls the API.
  const masterKey = createHash("sha256").update(JSON.stringify(m)).digest("hex").slice(0, 8);

  const hashLine = (text) =>
    createHash("sha256")
      .update(JSON.stringify({ say: spoken(text), voiceId, model, settings }))
      .digest("hex")
      .slice(0, 16);

  const folderName = args.variant ? `${script.id}--${args.variant}` : script.id;
  const outDir = path.join(projectRoot, "public", "voiceover", folderName);
  const manifestPath = path.join(outDir, "manifest.json");
  const manifest = existsSync(manifestPath)
    ? JSON.parse(await readFile(manifestPath, "utf8"))
    : { scenes: {} };
  const saveManifest = () =>
    writeFile(manifestPath, JSON.stringify({ ...manifest, voiceId, model }, null, 2));

  const voiced = script.scenes.filter((s) => typeof s.voice === "string" && s.voice.trim());
  const known = new Set(voiced.map((s) => s.id));
  for (const id of args.only ?? []) {
    if (!known.has(id)) throw new Error(`--only: "${id}" is not a voiced scene of ${script.id}`);
  }

  const todo = [];
  let cachedCount = 0;
  let remastered = 0;
  for (const scene of voiced) {
    const text = scene.voice.trim();
    const hash = hashLine(text);
    const file = `${scene.id}.wav`;
    const cached = manifest.scenes[scene.id];
    const rawPath = path.join(outDir, `${scene.id}.raw.mp3`);
    const alignPath = path.join(outDir, `${scene.id}.align.json`);
    const haveTake = cached?.hash === hash && existsSync(rawPath) && existsSync(alignPath);
    const selected = !args.only || args.only.has(scene.id);
    // A saved take that failed verification is not finished work: try it again.
    const retry = selected && (args.force || (args.verify && cached?.verified === false));
    if (haveTake && !retry) {
      // Same take; only the mastering settings changed, so no API call is needed.
      if (cached.master !== masterKey || !existsSync(path.join(outDir, file))) {
        if (!args.dryRun) {
          const wordCount = tokens(text).length;
          const pauses = master(rawPath, JSON.parse(await readFile(alignPath, "utf8")), path.join(outDir, file), wordCount, m);
          const seconds = audioSeconds(path.join(outDir, file));
          Object.assign(cached, {
            file, master: masterKey, pauses, seconds: +seconds.toFixed(3),
            wpm: Math.round((wordCount / seconds) * 60),
          });
        }
        remastered++;
      }
      cachedCount++;
      continue;
    }
    // Earlier attempts on the same text used the first seeds; continue after them.
    const priorAttempts = cached?.hash === hash ? (cached.attempts ?? 0) : 0;
    if (selected) todo.push({ scene, text, hash, file, priorAttempts });
  }
  if (remastered > 0 && !args.dryRun) {
    await saveManifest();
    console.log(`  remastered ${remastered} clip(s) from saved takes`);
  } else if (remastered > 0) {
    console.log(`  would remaster ${remastered} clip(s) from saved takes`);
  }

  // Drop entries for scenes that no longer exist or lost their voice line.
  for (const id of Object.keys(manifest.scenes)) {
    if (!known.has(id)) delete manifest.scenes[id];
  }

  const chars = todo.reduce((n, t) => n + spoken(t.text).length, 0);
  console.log(
    `${script.id} → public/voiceover/${folderName} [${model}]: ${todo.length} to generate (${chars} chars), ${cachedCount} cached`,
  );
  if (args.dryRun || todo.length === 0) {
    for (const t of todo) console.log(`  would generate ${t.scene.id}: ${spoken(t.text)}`);
    if (!args.dryRun && existsSync(outDir)) await saveManifest();
    return;
  }

  const apiKey = await readApiKey();
  await mkdir(outDir, { recursive: true });
  const failed = [];
  for (const t of todo) {
    let best = null;
    for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
      const take = await synthesize({
        apiKey, voiceId, model, settings, text: spoken(t.text),
        seed: BASE_SEED + (t.priorAttempts + attempt) * 101,
      });
      const heard = args.verify ? ((await transcribe({ apiKey, audio: take.audio })).text ?? "") : "";
      const problem = args.verify ? mismatch(t.text, heard) : null;
      best = { ...take, heard, problem, attempt };
      if (!problem) break;
      console.log(`  … ${t.scene.id} attempt ${attempt + 1}: ${problem}\n      heard: ${heard}`);
    }
    const target = path.join(outDir, t.file);
    const raw = path.join(outDir, `${t.scene.id}.raw.mp3`);
    await writeFile(raw, best.audio);
    await writeFile(path.join(outDir, `${t.scene.id}.align.json`), JSON.stringify(best.alignment));
    const wordCount = tokens(t.text).length;
    const pauses = master(raw, best.alignment, target, wordCount, m);
    const seconds = audioSeconds(target);
    manifest.scenes[t.scene.id] = {
      hash: t.hash,
      text: t.text,
      file: t.file,
      seconds: +seconds.toFixed(3),
      wpm: Math.round((wordCount / seconds) * 60),
      master: masterKey,
      pauses,
      verified: args.verify ? best.problem === null : null,
      problem: best.problem ?? undefined,
      heard: best.problem ? best.heard : undefined,
      attempts: t.priorAttempts + best.attempt + 1,
      format: best.format,
      generatedAt: new Date().toISOString(),
    };
    // Write after each passage so an interrupted run keeps what it paid for.
    await saveManifest();
    if (best.problem) failed.push(t.scene.id);
    console.log(
      `  ${best.problem ? "✗" : "✓"} ${t.scene.id} (${spoken(t.text).length} chars, ${seconds.toFixed(1)}s, ${manifest.scenes[t.scene.id].wpm} wpm${best.attempt ? `, attempt ${best.attempt + 1}` : ""})`,
    );
  }
  if (failed.length > 0) {
    console.error(`UNVERIFIED: ${failed.join(", ")}`);
    process.exit(2);
  }
};

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
