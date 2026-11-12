#!/usr/bin/env node
// Render one or more videos to out/<video>.mp4 (1920x1080, 30 fps, h264 + aac).
//
//   node scripts/render.mjs <video...> [--allow-silent]
//
// Before it renders, it copies new clips into public/clips and checks that every voiced
// scene has fresh, verified audio. A video with a missing or unverified passage is not
// rendered unless --allow-silent is given (useful for a picture-only draft).

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdir, readFile } from "node:fs/promises";
import path from "node:path";

import { loadScript, projectRoot } from "./lib/shared.mjs";

const args = process.argv.slice(2);
const allowSilent = args.includes("--allow-silent");
const videos = args.filter((a) => !a.startsWith("--"));
if (videos.length === 0) {
  console.error("Usage: node scripts/render.mjs <video...> [--allow-silent]");
  process.exit(1);
}

const run = (command, commandArgs) => {
  const result = spawnSync(command, commandArgs, { cwd: projectRoot, stdio: "inherit" });
  if (result.status !== 0) {
    console.error(`${command} ${commandArgs.join(" ")} failed (exit ${result.status ?? result.signal})`);
    process.exit(result.status ?? 1);
  }
};

const problems = [];
for (const video of videos) {
  const script = await loadScript(video);
  const manifestPath = path.join(projectRoot, "public", "voiceover", video, "manifest.json");
  const manifest = existsSync(manifestPath) ? JSON.parse(await readFile(manifestPath, "utf8")) : { scenes: {} };
  for (const scene of script.scenes) {
    const text = scene.voice?.trim();
    if (!text) continue;
    const entry = manifest.scenes[scene.id];
    if (!entry || entry.text !== text) problems.push(`${video}/${scene.id}: no audio for the current text`);
    else if (entry.verified === false) problems.push(`${video}/${scene.id}: audio not verified (${entry.problem})`);
  }
}
if (problems.length > 0) {
  console.error(`${allowSilent ? "Warning" : "Not rendered"}:\n  ${problems.join("\n  ")}`);
  if (!allowSilent) {
    console.error("Run npm run voiceover -- <video>, or pass --allow-silent for a draft.");
    process.exit(2);
  }
}

run(process.execPath, [path.join(projectRoot, "scripts", "sync-clips.mjs")]);
await mkdir(path.join(projectRoot, "out"), { recursive: true });
for (const video of videos) {
  run("npx", ["--no-install", "remotion", "render", video, `out/${video}.mp4`, "--codec=h264", "--crf=18"]);
  console.log(`rendered out/${video}.mp4`);
}
