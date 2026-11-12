#!/usr/bin/env node
// Contact sheets for review: one frame every N seconds, 12 frames (4x3) per sheet.
//
//   node scripts/contact-sheet.mjs <video id | path to .mp4> [--every <seconds>]
//
// A video id reads out/<id>.mp4. Sheets go to out/check/<name>-sheet-01.jpg, -02.jpg, …
// Default: one frame every 8 seconds; short files use 12 evenly spaced frames.

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import path from "node:path";

import { projectRoot } from "./lib/shared.mjs";

const args = process.argv.slice(2);
const everyIndex = args.indexOf("--every");
const every = everyIndex >= 0 ? Number(args[everyIndex + 1]) : null;
const target = args.find((a, i) => !a.startsWith("--") && (everyIndex < 0 || i !== everyIndex + 1));
if (!target || (every !== null && !(every > 0))) {
  console.error("Usage: node scripts/contact-sheet.mjs <video id | path to .mp4> [--every <seconds>]");
  process.exit(1);
}
const file = target.endsWith(".mp4") ? path.resolve(target) : path.join(projectRoot, "out", `${target}.mp4`);
if (!existsSync(file)) {
  console.error(`No file at ${file}`);
  process.exit(1);
}
const name = path.basename(file, ".mp4");
const outDir = path.join(projectRoot, "out", "check");
mkdirSync(outDir, { recursive: true });
for (const old of readdirSync(outDir)) {
  if (old.startsWith(`${name}-sheet-`)) rmSync(path.join(outDir, old));
}

const duration = Number(
  execFileSync("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file]).toString(),
);
const step = every ?? Math.min(8, duration / 12);
execFileSync("ffmpeg", [
  "-hide_banner", "-loglevel", "error", "-y", "-i", file,
  "-vf", `fps=1/${step.toFixed(3)},scale=480:-1,tile=4x3`,
  path.join(outDir, `${name}-sheet-%02d.jpg`),
]);
const sheets = readdirSync(outDir).filter((f) => f.startsWith(`${name}-sheet-`)).sort();
console.log(`${name}: ${duration.toFixed(0)}s, one frame every ${step.toFixed(1)}s`);
for (const sheet of sheets) console.log(path.join(outDir, sheet));
