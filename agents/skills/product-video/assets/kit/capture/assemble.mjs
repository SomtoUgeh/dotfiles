#!/usr/bin/env node
// Assemble recorded frames into an MP4 with the off-air ranges cut.
//
//   node assemble.mjs                 every clip in $DEMO_OUT/clips (default ../out/clips)
//   node assemble.mjs <clip...>       only the named clips
//
// Writes $DEMO_OUT/mp4/<clip>.mp4 and <clip>.json (duration, and events on the cut timeline).
// Run it after the tour has ended: a clip without its final "end" beat is refused.
// Exit codes: 0 all clips assembled, 1 one or more clips failed.

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const outRoot = path.resolve(
  process.env.DEMO_OUT ?? path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "out"),
);
const clipsDir = path.join(outRoot, "clips");
const mp4Dir = path.join(outRoot, "mp4");

const assemble = (clip) => {
  const clipDir = path.join(clipsDir, clip);
  if (!existsSync(path.join(clipDir, "frames.jsonl"))) throw new Error(`no recording at ${clipDir}`);
  const lines = (f) =>
    readFileSync(path.join(clipDir, f), "utf-8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l));
  const frames = lines("frames.jsonl");
  const events = lines("events.jsonl");
  const end = events.find((e) => e.type === "beat" && e.id === "end");
  if (!end) throw new Error('no "end" beat: the recording is still running, or the tour failed');
  if (frames.length === 0) throw new Error("no frames were captured");
  const endT = end.t;

  // Off-air ranges are removed, and every later time moves back by the removed length.
  const cuts = [];
  let open = null;
  for (const e of events) {
    if (e.type === "off") open = e.t;
    if (e.type === "on" && open !== null) {
      cuts.push([open, e.t]);
      open = null;
    }
  }
  const inCut = (t) => cuts.some(([a, b]) => t >= a && t < b);
  const remap = (t) => t - cuts.reduce((s, [a, b]) => s + (t <= a ? 0 : Math.min(t, b) - a), 0);

  const kept = frames.filter((f) => !inCut(f.t) && f.t <= endT);
  if (kept.length === 0) throw new Error("every frame is inside an off-air range");
  const framePath = (f) => path.join(clipDir, "frames", `${String(f.i).padStart(6, "0")}.jpg`);
  const list = [];
  for (let i = 0; i < kept.length; i += 1) {
    const nextT = i + 1 < kept.length ? kept[i + 1].t : endT;
    const dur = Math.max(0.001, remap(nextT) - remap(kept[i].t));
    list.push(`file '${framePath(kept[i])}'`, `duration ${dur.toFixed(4)}`);
  }
  // The concat demuxer needs the last file once more to honour its duration.
  list.push(`file '${framePath(kept.at(-1))}'`);
  mkdirSync(mp4Dir, { recursive: true });
  const listPath = path.join(clipDir, "concat.txt");
  writeFileSync(listPath, `${list.join("\n")}\n`);
  const out = path.join(mp4Dir, `${clip}.mp4`);
  execFileSync("ffmpeg", [
    "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", listPath,
    "-vf", "fps=30,format=yuv420p", "-c:v", "libx264", "-preset", "medium", "-crf", "17",
    "-movflags", "+faststart", out,
  ]);
  const t0 = remap(kept[0].t);
  const duration = remap(endT) - t0;
  const mapped = events
    .filter((e) => e.type !== "off" && e.type !== "on" && !inCut(e.t))
    .map((e) => ({ ...e, t: +(remap(e.t) - t0).toFixed(3) }));
  writeFileSync(
    path.join(mp4Dir, `${clip}.json`),
    JSON.stringify({ clip, duration: +duration.toFixed(3), fps: +(kept.length / duration).toFixed(1), events: mapped }, null, 2),
  );
  const beats = mapped.filter((e) => e.type === "beat").map((e) => `${e.id}@${e.t.toFixed(1)}`);
  console.log(
    `${clip}: ${duration.toFixed(1)}s, ${kept.length} frames (${(kept.length / duration).toFixed(1)} fps), cut ${cuts.length} range(s); beats ${beats.join(" ")}`,
  );
};

const named = process.argv.slice(2);
if (!existsSync(clipsDir)) {
  console.error(`No recordings at ${clipsDir}. Record a tour first (npm run record).`);
  process.exit(1);
}
const clips = named.length > 0 ? named : readdirSync(clipsDir).filter((n) => !n.startsWith(".")).sort();
if (clips.length === 0) {
  console.error(`No clips in ${clipsDir}`);
  process.exit(1);
}
let failed = 0;
for (const clip of clips) {
  try {
    assemble(clip);
  } catch (err) {
    failed += 1;
    console.error(`${clip}: FAILED: ${err instanceof Error ? err.message : err}`);
  }
}
process.exit(failed > 0 ? 1 : 0);
