// Shared helpers for the video scripts: project paths, script and config loading, the
// ElevenLabs key and transcription call, and the text comparison used to verify speech.

import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

const STT_MODEL = "scribe_v2";

/** Loads src/script/<video>.ts (data-only TypeScript; Node strips the types). */
export const loadScript = async (video) => {
  const file = path.join(projectRoot, "src", "script", `${video}.ts`);
  if (!existsSync(file)) throw new Error(`No script at ${path.relative(projectRoot, file)}`);
  const mod = await import(pathToFileURL(file).href);
  const script = Object.values(mod).find(
    (v) => v && typeof v === "object" && Array.isArray(v.scenes) && v.id === video,
  );
  if (!script) throw new Error(`${video}.ts must export a script object with id "${video}"`);
  return script;
};

const isStringArray = (v) => Array.isArray(v) && v.every((x) => typeof x === "string");

/** Reads and validates voice.config.json. A missing file gives the defaults. */
export const loadConfig = async (file = path.join(projectRoot, "voice.config.json")) => {
  const raw = existsSync(file) ? JSON.parse(await readFile(file, "utf8")) : {};
  const fail = (message) => {
    throw new Error(`${path.basename(file)}: ${message}`);
  };
  const config = {
    voiceId: raw.voiceId ?? "",
    model: raw.model ?? "",
    settings: raw.settings ?? {},
    pronunciations: raw.pronunciations ?? [],
    spellings: raw.spellings ?? [],
    master: raw.master ?? {},
  };
  if (typeof config.voiceId !== "string") fail("voiceId must be a string");
  if (typeof config.model !== "string") fail("model must be a string");
  if (!Array.isArray(config.pronunciations)) fail("pronunciations must be an array");
  config.pronunciations.forEach((p, i) => {
    if (typeof p?.written !== "string" || !p.written.trim()) fail(`pronunciations[${i}].written is required`);
    if (typeof p.spoken !== "string" || !p.spoken.trim()) fail(`pronunciations[${i}].spoken is required`);
    if (p.heard !== undefined && !isStringArray(p.heard)) fail(`pronunciations[${i}].heard must be an array of strings`);
    for (const source of p.heard ?? []) {
      try {
        new RegExp(source);
      } catch (err) {
        fail(`pronunciations[${i}].heard has an invalid pattern "${source}": ${err.message}`);
      }
    }
  });
  if (!Array.isArray(config.spellings) || !config.spellings.every((s) => isStringArray(s) && s.length === 2)) {
    fail('spellings must be an array of ["pattern", "replacement"] pairs');
  }
  for (const [source] of config.spellings) {
    try {
      new RegExp(source);
    } catch (err) {
      fail(`spellings has an invalid pattern "${source}": ${err.message}`);
    }
  }
  return config;
};

/**
 * The ElevenLabs key: $ELEVENLABS_API_KEY, else the file named by $ELEVENLABS_API_KEY_FILE.
 * The key is never printed or written anywhere.
 */
export const readApiKey = async () => {
  if (process.env.ELEVENLABS_API_KEY?.trim()) return process.env.ELEVENLABS_API_KEY.trim();
  const file = process.env.ELEVENLABS_API_KEY_FILE;
  if (!file) {
    throw new Error("No ElevenLabs key: set ELEVENLABS_API_KEY, or ELEVENLABS_API_KEY_FILE to a file that holds it");
  }
  const key = (await readFile(file, "utf8")).trim();
  if (!key) throw new Error("The ElevenLabs key file is empty");
  return key;
};

/** Speech to text with Scribe. Returns the response JSON (`text`, `words`, …). */
export const transcribe = async ({ apiKey, audio, filename = "clip.mp3" }) => {
  const form = new FormData();
  form.set("model_id", STT_MODEL);
  form.set("language_code", "en");
  form.set("file", new Blob([audio]), filename);
  const res = await fetch("https://api.elevenlabs.io/v1/speech-to-text", {
    method: "POST",
    headers: { "xi-api-key": apiKey },
    body: form,
  });
  if (!res.ok) throw new Error(`Scribe ${res.status}: ${(await res.text()).slice(0, 300)}`);
  return res.json();
};

// ---- text comparison ------------------------------------------------------------------------

// Words that a transcriber spells in more than one way. Both sides are folded to one form.
const SPELLING = [
  [/\bmoldy\b/g, "mouldy"],
  [/\bcolor/g, "colour"],
  [/\borganiz/g, "organis"],
  [/\brecogniz/g, "recognis"],
  [/\bcenter\b/g, "centre"],
  [/\backnowledgement/g, "acknowledgment"],
  [/\bok\b/g, "okay"],
  [/\baround\b/g, "round"],
  [/\bhome ?page\b/g, "homepage"],
  [/\bcheck ?out\b/g, "checkout"],
  [/\bcheck ?in\b/g, "checkin"],
  [/\bmove ?in\b/g, "movein"],
  [/\bsign ?off\b/g, "signoff"],
  [/\bsign ?up\b/g, "signup"],
  [/\bset ?up\b/g, "setup"],
  [/\blog ?in\b/g, "login"],
];

const ONES = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"];
const TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"];
/** The transcriber writes "22" where the script says "twenty-two". */
const numberWords = (digits) => {
  const n = Number(digits);
  if (n < 20) return ONES[n];
  if (n < 100) return `${TENS[Math.floor(n / 10)]}${n % 10 ? ` ${ONES[n % 10]}` : ""}`;
  return digits;
};

const escapeRegExp = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

export const editDistance = (a, b) => {
  const row = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    let prev = row[0];
    row[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const keep = row[j];
      row[j] = Math.min(row[j] + 1, row[j - 1] + 1, prev + (a[i - 1] === b[j - 1] ? 0 : 1));
      prev = keep;
    }
  }
  return row[b.length];
};

/**
 * Text functions for one config.
 * - spoken(text): what is sent to the voice model (pronunciations applied).
 * - tokens(text): lower-case words with numbers, spellings and names folded, for comparison.
 * - mismatch(script, heard): null when the audio says the script, otherwise a short reason.
 */
export const makeText = (config) => {
  const extraSpellings = config.spellings.map(([from, to]) => [new RegExp(from, "g"), to]);

  const normalise = (text) => {
    let t = text
      .replace(/\b\d{1,2}\b/g, numberWords)
      .toLowerCase()
      .replace(/\[[^\]]*\]/g, " ")
      .replace(/[’']/g, "")
      .replace(/-/g, " ")
      .replace(/[^a-z0-9 ]+/g, " ")
      .replace(/\s+/g, " ")
      .trim();
    for (const [from, to] of [...SPELLING, ...extraSpellings]) t = t.replace(from, to);
    return t;
  };

  const names = config.pronunciations.map((p) => {
    const token = p.written.toLowerCase().replace(/[^a-z0-9]+/g, "");
    if (!token) throw new Error(`Pronunciation "${p.written}" needs at least one letter or digit`);
    // The written form (as the comparison sees it), the spoken form, and each way the
    // transcriber is known to spell the correct sound.
    const forms = [escapeRegExp(normalise(p.written)), escapeRegExp(normalise(p.spoken)), ...(p.heard ?? [])];
    return {
      written: p.written,
      token,
      say: [new RegExp(`\\b${escapeRegExp(p.written)}\\b`, "g"), p.spoken],
      fold: new RegExp(`\\b(?:${forms.join("|")})\\b`, "g"),
    };
  });

  const spoken = (text) => names.reduce((t, n) => t.replace(n.say[0], n.say[1]), text);

  const tokens = (text) => {
    let t = normalise(text);
    for (const n of names) t = t.replace(n.fold, n.token);
    return t.split(" ").filter(Boolean);
  };

  const count = (list, token) => list.filter((w) => w === token).length;

  /** How often each configured name occurs in a token list: [{ written, count }]. */
  const nameCounts = (list) => names.map((n) => ({ written: n.written, count: count(list, n.token) }));

  const mismatch = (scriptText, heardText) => {
    const want = tokens(scriptText);
    const heard = tokens(heardText);
    for (const n of names) {
      const wanted = count(want, n.token);
      const got = count(heard, n.token);
      if (got < wanted) return `"${n.written}" said wrongly (${got}/${wanted})`;
    }
    const distance = editDistance(want, heard);
    const allowed = Math.floor(want.length / 14);
    if (distance > allowed) return `${distance} word difference(s), ${allowed} allowed`;
    const tail = want.slice(-3).join(" ");
    if (heard.slice(-3).join(" ") !== tail) return `ending differs: wanted "${tail}"`;
    return null;
  };

  return { spoken, tokens, nameCounts, mismatch };
};

/**
 * Finds each passage in a transcript of the whole video, in order. Returns, per passage,
 * the words that were not heard. A passage fails when more than one word in 14 is missing.
 */
export const findPassages = (passages, transcriptTokens) => {
  let pos = 0;
  return passages.map(({ id, tokens }) => {
    // Jump to where the passage starts, so one missing passage does not hide the next ones.
    let at = pos;
    const lead = tokens.slice(0, 3).join(" ");
    for (let j = pos; j <= transcriptTokens.length - 3; j++) {
      if (transcriptTokens.slice(j, j + 3).join(" ") === lead) {
        at = j;
        break;
      }
    }
    const missing = [];
    for (const word of tokens) {
      let found = -1;
      for (let j = at; j < Math.min(transcriptTokens.length, at + 8); j++) {
        if (transcriptTokens[j] === word) {
          found = j;
          break;
        }
      }
      if (found < 0) missing.push(word);
      else at = found + 1;
    }
    const ok = missing.length <= Math.floor(tokens.length / 14);
    // A passage that was not heard must not use up the words of the passages after it.
    if (ok) pos = at;
    return { id, missing, ok };
  });
};
