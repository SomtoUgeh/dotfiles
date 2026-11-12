// Run with: npm test   (node --test scripts/lib/)
import assert from "node:assert/strict";
import { mkdtemp, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

import { findPassages, loadConfig, makeText } from "./shared.mjs";

const base = { voiceId: "", model: "", settings: {}, pronunciations: [], spellings: [], master: {} };
const withName = {
  ...base,
  pronunciations: [
    { written: "Erivault", spoken: "Eri-Vault", heard: ["(e|i|ai|ae|a)r+[aeiy]{1,2} ?v(au|aw|o)lts?"] },
  ],
};

test("spoken() applies the pronunciation and leaves other text alone", () => {
  const { spoken } = makeText(withName);
  assert.equal(spoken("Erivault keeps the record."), "Eri-Vault keeps the record.");
  assert.equal(makeText(base).spoken("Erivault keeps the record."), "Erivault keeps the record.");
});

test("a correct take passes, with digits, hyphens and US spelling", () => {
  const { mismatch } = makeText(base);
  assert.equal(
    mismatch(
      "She confirms the email with a six-digit code. The colour is right for all twenty-two rooms.",
      "She confirms the email with a 6 digit code. The color is right for all 22 rooms.",
    ),
    null,
  );
});

test("a take that drops the ending fails", () => {
  const { mismatch } = makeText(base);
  assert.match(
    mismatch("She selects the button, and the workspace is ready.", "She selects the button, and the workspace"),
    /difference|ending differs/,
  );
});

test("a take with many wrong words fails", () => {
  const { mismatch } = makeText(base);
  assert.match(mismatch("Maya enters her name and her work email.", "Maya writes a note for the team now."), /difference/);
});

test("the name is accepted in the spellings the transcriber uses for the right sound", () => {
  const { mismatch } = makeText(withName);
  for (const heard of ["Ari Vault", "Arivault", "Airevault", "Irie Vault", "Erevolt"]) {
    assert.equal(mismatch("Erivault keeps the record.", `${heard} keeps the record.`), null, heard);
  }
});

test("the name said wrongly fails, even when the other words match", () => {
  const { mismatch } = makeText(withName);
  for (const heard of ["Airvault", "Every Vault", "Erivo"]) {
    assert.match(mismatch("Erivault keeps the record.", `${heard} keeps the record.`), /said wrongly/, heard);
  }
});

test("findPassages finds passages in order and reports a missing one without hiding the next", () => {
  const { tokens } = makeText(base);
  const passages = [
    { id: "a", tokens: tokens("This short tour shows how a new customer creates a workspace.") },
    { id: "b", tokens: tokens("Maya enters her name and her work email.") },
    { id: "c", tokens: tokens("She selects the button, and the workspace is ready.") },
  ];
  const transcript = tokens(
    "This short tour shows how a new customer creates a workspace. She selects the button, and the workspace is ready.",
  );
  const result = findPassages(passages, transcript);
  assert.deepEqual(result.map((r) => r.ok), [true, false, true]);
});

test("loadConfig rejects an invalid pattern and names the entry", async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), "voice-config-"));
  const file = path.join(dir, "voice.config.json");
  await writeFile(file, JSON.stringify({ pronunciations: [{ written: "Acme", spoken: "Ak-mee", heard: ["("] }] }));
  await assert.rejects(loadConfig(file), /pronunciations\[0\]\.heard has an invalid pattern/);
  await writeFile(file, JSON.stringify({ pronunciations: [{ written: "Acme" }] }));
  await assert.rejects(loadConfig(file), /pronunciations\[0\]\.spoken is required/);
});

test("loadConfig gives defaults when the file is missing", async () => {
  const config = await loadConfig(path.join(os.tmpdir(), "no-such-voice-config.json"));
  assert.deepEqual(config.pronunciations, []);
  assert.equal(config.voiceId, "");
});
