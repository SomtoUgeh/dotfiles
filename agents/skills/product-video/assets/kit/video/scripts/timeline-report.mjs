#!/usr/bin/env node
// Reads the output of `remotion compositions --log=verbose` on stdin and prints, per video,
// the scene count, the total length and the scenes that need attention:
//   - silent:  more than SILENT_SECONDS of the scene has no narration
//   - frozen:  the narration runs more than FROZEN_SECONDS past the end of the footage
// It also repeats each "[voiceover] … no fresh audio" warning once.
//
//   npm run timeline            (advisory: always exits 0)
//   npm run timeline -- --strict   (exits 1 when a scene is flagged or audio is stale)

const SILENT_SECONDS = 3.5;
const FROZEN_SECONDS = 3;
const VOICE_LEAD_IN = 0.55;
const FPS = 30;

const strict = process.argv.includes("--strict");
let input = "";
for await (const chunk of process.stdin) input += chunk;

const seen = new Set();
const stale = new Set();
let flagged = 0;
for (const line of input.split("\n")) {
  const warning = /\[voiceover\] (\S+): no fresh audio/.exec(line);
  if (warning) stale.add(warning[1]);
  const m = /\[timeline\] (\S+): (.*)/.exec(line);
  if (!m || seen.has(m[1])) continue;
  seen.add(m[1]);
  const rows = m[2].split(" | ");
  const last = /^(\S+)@(\d+)\+(\d+)/.exec(rows.at(-1));
  const total = (Number(last[2]) + Number(last[3])) / FPS;
  const flags = [];
  for (const row of rows) {
    const g = /^(\S+)@\d+\+\d+ ([\d.]+)s voice=([\d.]+|none) spare=([\d.]+)(?: footage=([\d.]+))?/.exec(row);
    if (!g) continue;
    const [, name, , voice, spare, footage] = g;
    if (!footage) continue;
    if (Number(spare) > SILENT_SECONDS) {
      flags.push(`  ${name}: silent ${spare}s (voice ${voice}, footage ${footage})`);
    }
    const over = voice === "none" ? 0 : Number(voice) + VOICE_LEAD_IN - Number(footage);
    if (over > FROZEN_SECONDS) {
      flags.push(`  ${name}: frozen, voice runs ${over.toFixed(1)}s past footage (voice ${voice}, footage ${footage})`);
    }
  }
  flagged += flags.length;
  const minutes = Math.floor(total / 60);
  const seconds = String(Math.floor(total % 60)).padStart(2, "0");
  console.log(`== ${m[1]}: ${rows.length} scenes, ${minutes}:${seconds}`);
  console.log(flags.join("\n") || "  no flags");
}
if (stale.size > 0) {
  console.log(`\nNo fresh audio (run npm run voiceover -- <video>):\n  ${[...stale].join("\n  ")}`);
}
if (seen.size === 0) {
  console.error("No [timeline] lines found. Run: npx remotion compositions --log=verbose");
  process.exit(1);
}
if (strict && (flagged > 0 || stale.size > 0)) process.exit(1);
