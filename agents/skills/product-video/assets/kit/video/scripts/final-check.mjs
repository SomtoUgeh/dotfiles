#!/usr/bin/env node
// Check rendered videos: transcribe the audio of out/<video>.mp4 and compare it with the
// script, then report loudness, true peak and every silent gap longer than 3 s.
//
//   node scripts/final-check.mjs <video...> [--no-stt]
//
// Writes out/check/<video>-stt.json. --no-stt skips the transcript (no API key needed) and
// reports only loudness and silence.
// Exit codes: 0 every passage heard, 1 error, 2 one or more passages not heard.

import { execFileSync, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

import { findPassages, loadConfig, loadScript, makeText, projectRoot, readApiKey, transcribe } from "./lib/shared.mjs";

const args = process.argv.slice(2);
const stt = !args.includes("--no-stt");
const videos = args.filter((a) => !a.startsWith("--"));
if (videos.length === 0) {
  console.error("Usage: node scripts/final-check.mjs <video...> [--no-stt]");
  process.exit(1);
}

const main = async () => {
  const config = await loadConfig();
  const { tokens, nameCounts } = makeText(config);
  const apiKey = stt ? await readApiKey() : null;
  const checkDir = path.join(projectRoot, "out", "check");
  await mkdir(checkDir, { recursive: true });
  let failed = 0;

  for (const video of videos) {
    const script = await loadScript(video);
    const mp4 = path.join(projectRoot, "out", `${video}.mp4`);
    if (!existsSync(mp4)) throw new Error(`No render at out/${video}.mp4`);

    // Measure the rendered file itself. A re-encoded copy can read a higher peak.
    const probe = spawnSync(
      "ffmpeg",
      ["-hide_banner", "-nostats", "-i", mp4, "-vn", "-af", "silencedetect=noise=-45dB:d=3,loudnorm=print_format=json", "-f", "null", "-"],
      { encoding: "utf8", maxBuffer: 1 << 26 },
    ).stderr;
    const gaps = [...probe.matchAll(/silence_end: ([0-9.]+) \| silence_duration: ([0-9.]+)/g)].map(
      (g) => `${(Number(g[1]) - Number(g[2])).toFixed(0)}s+${Number(g[2]).toFixed(1)}`,
    );
    const lufs = /"input_i"\s*:\s*"(-?[0-9.]+)"/.exec(probe)?.[1];
    const peak = /"input_tp"\s*:\s*"(-?[0-9.]+)"/.exec(probe)?.[1];
    if (lufs === undefined) {
      throw new Error(`out/${video}.mp4 has no audio to measure. Was it rendered with --allow-silent?`);
    }
    console.log(`${video}: loudness ${lufs} LUFS, true peak ${peak} dBTP`);
    console.log(`  silences over 3 s (start+length): ${gaps.join("  ") || "none"}`);
    if (!stt) continue;

    const mp3 = path.join(checkDir, `${video}.mp3`);
    execFileSync("ffmpeg", ["-hide_banner", "-loglevel", "error", "-y", "-i", mp4, "-vn", "-ac", "1", "-b:a", "96k", mp3]);
    const json = await transcribe({ apiKey, audio: await readFile(mp3), filename: `${video}.mp3` });
    await writeFile(path.join(checkDir, `${video}-stt.json`), JSON.stringify(json));
    const heard = tokens(json.text ?? "");

    const voiced = script.scenes.filter((s) => typeof s.voice === "string" && s.voice.trim());
    const passages = voiced.map((s) => ({ id: s.id, tokens: tokens(s.voice) }));
    const results = findPassages(passages, heard);
    const bad = results.filter((r) => !r.ok);
    for (const r of results) {
      if (r.missing.length > 0) {
        console.log(`  ${r.ok ? "note" : "NOT HEARD"} ${video}/${r.id}: ${r.missing.join(" ")}`);
      }
    }
    const wanted = nameCounts(passages.flatMap((p) => p.tokens));
    const got = nameCounts(heard);
    for (const [i, name] of wanted.entries()) {
      const ok = got[i].count >= name.count;
      console.log(`  name "${name.written}": ${got[i].count} heard, ${name.count} in the script${ok ? "" : "  <-- said wrongly"}`);
      if (!ok) failed++;
    }
    console.log(`  ${heard.length} words heard; ${passages.length - bad.length}/${passages.length} passages present`);
    failed += bad.length;
  }
  if (failed > 0) process.exit(2);
};

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
