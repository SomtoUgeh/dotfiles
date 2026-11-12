#!/usr/bin/env node
// Copy assembled clips (<clip>.mp4 + <clip>.json) into public/clips so Remotion can serve them.
// Source defaults to ../out/mp4 (the capture pipeline's output); override with CLIPS_DIR.
// Only files whose size or mtime changed are copied.

import { copyFile, mkdir, readdir, stat, utimes } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceDir = path.resolve(projectRoot, process.env.CLIPS_DIR ?? "../out/mp4");
const targetDir = path.join(projectRoot, "public", "clips");

const statOrNull = (p) => stat(p).catch(() => null);

await mkdir(targetDir, { recursive: true });
const names = (await readdir(sourceDir)).filter((n) => n.endsWith(".mp4") || n.endsWith(".json"));
let copied = 0;
for (const name of names) {
  const from = path.join(sourceDir, name);
  const to = path.join(targetDir, name);
  const [a, b] = await Promise.all([stat(from), statOrNull(to)]);
  if (b && b.size === a.size && Math.abs(b.mtimeMs - a.mtimeMs) < 1) continue;
  await copyFile(from, to);
  await utimes(to, a.atime, a.mtime);
  copied++;
  console.log(`  ↳ ${name}`);
}
console.log(`clips: ${copied} copied, ${names.length - copied} unchanged (${path.relative(projectRoot, sourceDir)} → public/clips)`);
