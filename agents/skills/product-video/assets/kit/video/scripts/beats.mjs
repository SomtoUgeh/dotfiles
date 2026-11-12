#!/usr/bin/env node
// Print every beat of every clip with its length, so narration can be sized to the footage.
//   node scripts/beats.mjs [prefix]
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
const dir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "public", "clips");
const prefix = process.argv[2] ?? "";
for (const f of readdirSync(dir).filter((n) => n.endsWith(".json") && n.startsWith(prefix)).sort()) {
  const clip = JSON.parse(readFileSync(path.join(dir, f), "utf8"));
  const beats = clip.events.filter((e) => e.type === "beat").sort((a, b) => a.t - b.t);
  const row = beats.slice(0, -1).map((b, i) => `${b.id} ${(beats[i + 1].t - b.t).toFixed(1)}`);
  console.log(`${clip.clip} (${clip.duration.toFixed(0)}s): ${row.join(" | ")}`);
}
