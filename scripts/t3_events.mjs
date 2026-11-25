#!/usr/bin/env node
// t3-events: follow T3 Code's MCP Events (io.modelcontextprotocol/events) on the Mac and wake the
// Aside task that is waiting on a thread, so agents stop sitting in t3_thread_wait.
//
// Each T3 environment keeps its own event feed (milestones from its own threads only), so the
// bridge signs in to every environment it follows, read-only, through the normal MCP OAuth flow
// (dynamic registration + PKCE, like Claude Code's `mcp login`). A sign-in lasts 30 days.
//
//   t3-events login <env> <mcp-url> [--environment-id <id>] [--url-file <path>] [--no-open]
//   t3-events envs                         sign-ins, expiry and last poll per environment
//   t3-events run                          the poller (the LaunchAgent runs this)
//   t3-events once                         one poll of every environment, then exit
//   t3-events watch <env> <threadId> --session <asideSessionId> [--types a,b] [--keep] [--note text]
//   t3-events unwatch <env> <threadId> [--session <id>]
//   t3-events watches
//   t3-events recent [--env e] [--thread t] [--limit n] [--json]
//   t3-events wait <env> <threadId> [--timeout 600] [--types a,b]   exit 0 on event, 1 on timeout
//
// Files: ~/.config/t3-events/{envs.json,tokens/<env>.json}  ~/.local/state/t3-events/{events.jsonl,
// cursors.json,watches.json,status.json,deliveries.jsonl}. Tokens are 0600 and never printed.
import { createServer } from "node:http";
import { createHash, randomBytes } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync, appendFileSync, existsSync, renameSync, chmodSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";

const HOME = homedir();
const CONFIG_DIR = process.env.T3_EVENTS_CONFIG_DIR ?? join(HOME, ".config/t3-events");
const STATE_DIR = process.env.T3_EVENTS_STATE_DIR ?? join(HOME, ".local/state/t3-events");
const TOKENS_DIR = join(CONFIG_DIR, "tokens");
const ENVS_FILE = join(CONFIG_DIR, "envs.json");
const EVENTS_FILE = join(STATE_DIR, "events.jsonl");
const CURSORS_FILE = join(STATE_DIR, "cursors.json");
const WATCHES_FILE = join(STATE_DIR, "watches.json");
const STATUS_FILE = join(STATE_DIR, "status.json");
const DELIVERIES_FILE = join(STATE_DIR, "deliveries.jsonl");
const ASIDE_BIN = process.env.T3_EVENTS_ASIDE_BIN ?? join(HOME, ".local/bin/aside");
const PROTOCOL = "2026-07-28";
const POLL_MS = Number(process.env.T3_EVENTS_POLL_MS ?? 10_000);
const THREAD_TYPES = [
  "thread.run_settled",
  "thread.needs_input",
  "thread.input_resolved",
  "thread.guest_request",
  "thread.guest_request_resolved",
  "pr.watch_wake",
];
const DEFAULT_WATCH_TYPES = ["thread.run_settled", "thread.needs_input", "pr.watch_wake"];

// ---------- small helpers ----------
const ensureDirs = () => {
  for (const d of [CONFIG_DIR, TOKENS_DIR, STATE_DIR]) mkdirSync(d, { recursive: true, mode: 0o700 });
};
const readJson = (file, fallback) => {
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return fallback;
  }
};
const writeJson = (file, value, mode = 0o600) => {
  const tmp = `${file}.${process.pid}.tmp`;
  writeFileSync(tmp, JSON.stringify(value, null, 2) + "\n", { mode });
  renameSync(tmp, file);
};
const log = (...args) => console.error(new Date().toISOString(), ...args);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const b64url = (buf) => buf.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

function parseArgs(argv) {
  const pos = [];
  const flags = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) flags[key] = true;
      else {
        flags[key] = next;
        i++;
      }
    } else pos.push(a);
  }
  return { pos, flags };
}

const envs = () => readJson(ENVS_FILE, {});
const tokenFile = (env) => join(TOKENS_DIR, `${env}.json`);
const loadToken = (env) => readJson(tokenFile(env), null);

// ---------- OAuth sign-in (MCP authorization: RFC 9728 discovery, RFC 7591 registration, PKCE) ----------
async function discover(mcpUrl) {
  const u = new URL(mcpUrl);
  let prm;
  for (const path of [`/.well-known/oauth-protected-resource${u.pathname}`, "/.well-known/oauth-protected-resource"]) {
    const r = await fetch(new URL(path, u.origin));
    if (r.ok) {
      prm = await r.json();
      break;
    }
  }
  if (!prm?.authorization_servers?.length) throw new Error(`no protected-resource metadata at ${u.origin}`);
  const as = new URL(prm.authorization_servers[0]);
  const r = await fetch(new URL(`/.well-known/oauth-authorization-server${as.pathname === "/" ? "" : as.pathname}`, as.origin));
  if (!r.ok) throw new Error(`no authorization-server metadata at ${as.origin} (${r.status})`);
  return { resource: prm.resource ?? mcpUrl, meta: await r.json() };
}

async function login(env, mcpUrl, flags) {
  ensureDirs();
  const { resource, meta } = await discover(mcpUrl);
  const scope = flags.scope ?? "orchestration:read";
  const state = b64url(randomBytes(24));
  const verifier = b64url(randomBytes(48));
  const challenge = b64url(createHash("sha256").update(verifier).digest());

  let resolveCode, rejectCode;
  const codePromise = new Promise((res, rej) => ((resolveCode = res), (rejectCode = rej)));
  const server = createServer((req, res) => {
    const url = new URL(req.url, "http://127.0.0.1");
    if (url.pathname !== "/callback") return res.writeHead(404).end();
    const err = url.searchParams.get("error");
    if (err) {
      res.writeHead(400, { "content-type": "text/plain" }).end(`Sign-in failed: ${err}`);
      return rejectCode(new Error(`authorization failed: ${err} ${url.searchParams.get("error_description") ?? ""}`));
    }
    if (url.searchParams.get("state") !== state) {
      res.writeHead(400).end("State mismatch");
      return rejectCode(new Error("state mismatch"));
    }
    res.writeHead(200, { "content-type": "text/html" }).end("<p>t3-events is signed in. You can close this tab.</p>");
    resolveCode(url.searchParams.get("code"));
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const redirectUri = `http://127.0.0.1:${server.address().port}/callback`;

  const reg = await fetch(meta.registration_endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      client_name: `t3-events on ${process.env.HOST_LABEL ?? "Mac"} (Aside bridge)`,
      redirect_uris: [redirectUri],
      grant_types: ["authorization_code"],
      response_types: ["code"],
      token_endpoint_auth_method: "none",
      scope,
    }),
  });
  if (!reg.ok) throw new Error(`client registration failed: ${reg.status} ${await reg.text()}`);
  const client = await reg.json();

  const auth = new URL(meta.authorization_endpoint);
  for (const [k, v] of Object.entries({
    response_type: "code",
    client_id: client.client_id,
    redirect_uri: redirectUri,
    code_challenge: challenge,
    code_challenge_method: "S256",
    state,
    scope,
    resource,
  }))
    auth.searchParams.set(k, v);

  if (flags["url-file"]) writeFileSync(flags["url-file"], auth.href + "\n", { mode: 0o600 });
  else console.log(`Approve the sign-in for ${env}:\n${auth.href}`);
  if (!flags["no-open"] && !flags["url-file"]) spawn("open", [auth.href], { stdio: "ignore", detached: true }).unref();

  const timeout = setTimeout(() => rejectCode(new Error("timed out waiting for approval (10 min)")), 600_000);
  let code;
  try {
    code = await codePromise;
  } finally {
    clearTimeout(timeout);
    server.close();
  }

  const tr = await fetch(meta.token_endpoint, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      code,
      redirect_uri: redirectUri,
      client_id: client.client_id,
      code_verifier: verifier,
      resource,
    }),
  });
  if (!tr.ok) throw new Error(`token exchange failed: ${tr.status} ${await tr.text()}`);
  const tok = await tr.json();
  const now = Date.now();
  writeJson(tokenFile(env), {
    mcpUrl,
    clientId: client.client_id,
    accessToken: tok.access_token,
    scope: tok.scope ?? scope,
    obtainedAt: new Date(now).toISOString(),
    expiresAt: tok.expires_in ? new Date(now + tok.expires_in * 1000).toISOString() : null,
  });
  const all = envs();
  all[env] = { ...(all[env] ?? {}), url: mcpUrl, ...(flags["environment-id"] ? { environmentId: flags["environment-id"] } : {}) };
  writeJson(ENVS_FILE, all);
  console.log(`Signed in to ${env} (${tok.scope ?? scope}); expires ${tok.expires_in ? new Date(now + tok.expires_in * 1000).toISOString() : "unknown"}.`);
}

// ---------- MCP over streamable HTTP, just enough for events ----------
class McpSession {
  constructor(env, url, token) {
    this.env = env;
    this.url = url;
    this.token = token;
    this.sessionId = undefined;
    this.nextId = 1;
    this.initialized = false;
  }
  async request(method, params, { notify = false } = {}) {
    const headers = {
      "content-type": "application/json",
      accept: "application/json, text/event-stream",
      authorization: `Bearer ${this.token}`,
      "mcp-protocol-version": PROTOCOL,
      // Stateless routing headers: the method, and the tool/event name it targets.
      "mcp-method": method,
    };
    if (typeof params?.name === "string" && /^[\t\x20-\x7e]*$/.test(params.name)) headers["mcp-name"] = params.name;
    if (this.sessionId) headers["mcp-session-id"] = this.sessionId;
    const id = notify ? undefined : this.nextId++;
    // MCP 2026-07-28 is stateless: every request names its protocol version and capabilities.
    params = {
      ...params,
      _meta: {
        ...(params?._meta ?? {}),
        "io.modelcontextprotocol/protocolVersion": PROTOCOL,
        "io.modelcontextprotocol/clientCapabilities": { extensions: { "io.modelcontextprotocol/events": {} } },
        "io.modelcontextprotocol/clientInfo": { name: "t3-events", version: "1" },
      },
    };
    const r = await fetch(this.url, {
      method: "POST",
      headers,
      body: JSON.stringify(notify ? { jsonrpc: "2.0", method, params } : { jsonrpc: "2.0", id, method, params }),
      signal: AbortSignal.timeout(15_000),
    });
    const sid = r.headers.get("mcp-session-id");
    if (sid) this.sessionId = sid;
    if (r.status === 401 || r.status === 403) {
      const e = new Error(`${this.env}: sign-in rejected (${r.status}); run: t3-events login ${this.env} ${this.url}`);
      e.auth = true;
      throw e;
    }
    if (r.status === 404 && this.sessionId) {
      this.sessionId = undefined;
      this.initialized = false;
      throw new Error(`${this.env}: MCP session expired`);
    }
    if (notify) return null;
    const text = await r.text();
    if (!r.ok) throw new Error(`${this.env}: ${method} HTTP ${r.status}: ${text.slice(0, 300)}`);
    let msg;
    if ((r.headers.get("content-type") ?? "").includes("text/event-stream")) {
      for (const line of text.split("\n")) {
        if (!line.startsWith("data:")) continue;
        try {
          const m = JSON.parse(line.slice(5));
          if (m.id === id) msg = m;
        } catch {}
      }
    } else msg = JSON.parse(text);
    if (!msg) throw new Error(`${this.env}: no response to ${method}`);
    if (msg.error) {
      const e = new Error(`${this.env}: ${method}: ${msg.error.message} (${msg.error.code})`);
      e.rpc = msg.error;
      throw e;
    }
    return msg.result;
  }
  async init() {
    // No initialize handshake on the stateless protocol; the metadata travels with each request.
    this.serverVersion = PROTOCOL;
    this.initialized = true;
  }
}

// ---------- polling ----------
const sessions = new Map();
function sessionFor(env) {
  const tok = loadToken(env);
  if (!tok) return null;
  const cfg = envs()[env] ?? {};
  const url = cfg.url ?? tok.mcpUrl;
  let s = sessions.get(env);
  if (!s || s.token !== tok.accessToken || s.url !== url) {
    s = new McpSession(env, url, tok.accessToken);
    sessions.set(env, s);
  }
  return s;
}

const startedAt = Date.now();
// Per-environment back-off: an asleep VM is retried at 30 s, 60 s ... up to 5 min; a T3 too old for
// events (MethodNotFound) every 30 min. Errors are logged when they change, not on every retry.
const backoff = new Map();
const dueNow = (env) => (backoff.get(env)?.until ?? 0) <= Date.now();
function noteFailure(env, e) {
  const prev = backoff.get(env);
  const tooOld = e.rpc?.code === -32601 || /Method not found: events/.test(e.message);
  const delay = tooOld ? 1_800_000 : Math.min((prev?.delay ?? 15_000) * 2, 300_000);
  if (prev?.error !== e.message) log(tooOld ? `${env}: this T3 is too old for MCP Events; update T3 there. Retrying every 30 min.` : e.message);
  backoff.set(env, { delay, until: Date.now() + delay, error: e.message });
}
function noteSuccess(env) {
  if (backoff.get(env)?.error) log(`${env}: reachable again`);
  backoff.delete(env);
}

async function pollEnv(env, cursors, status) {
  if (!dueNow(env)) return [];
  const s = sessionFor(env);
  if (!s) {
    status[env] = { ok: false, error: "not signed in", at: new Date().toISOString() };
    return [];
  }
  const fresh = [];
  try {
    await s.init();
    cursors[env] ??= {};
    for (const type of THREAD_TYPES) {
      let hasMore = true;
      let guard = 0;
      while (hasMore && guard++ < 10) {
        const first = cursors[env][type] === undefined;
        const res = await s.request("events/poll", {
          name: type,
          arguments: {},
          cursor: cursors[env][type] ?? null,
          maxEvents: 200,
          // On the very first poll only take the last hour, so a new install does not replay old turns.
          ...(first ? { maxAgeMs: 3_600_000 } : {}),
        });
        cursors[env][type] = res.cursor ?? cursors[env][type] ?? null;
        hasMore = !!res.hasMore;
        if (res.truncated) log(`${env}: ${type} feed truncated (events were missed while away)`);
        for (const ev of res.events ?? []) {
          fresh.push({
            env,
            environmentId: envs()[env]?.environmentId ?? null,
            name: type,
            eventId: ev.eventId,
            timestamp: ev.timestamp,
            data: ev.data,
            replay: first || Date.parse(ev.timestamp) < startedAt - 60_000,
          });
        }
      }
    }
    status[env] = { ok: true, at: new Date().toISOString(), protocol: s.serverVersion };
    noteSuccess(env);
  } catch (e) {
    s.initialized = false;
    const msg = e.name === "TimeoutError" || /fetch failed|ECONNREFUSED|ENOTFOUND|EHOSTUNREACH/.test(e.message + (e.cause?.code ?? "")) ? `${env}: not reachable (VM asleep or offline)` : e.message;
    status[env] = { ok: false, error: msg, auth: !!e.auth, at: new Date().toISOString() };
    noteFailure(env, { ...e, message: msg, rpc: e.rpc });
  }
  return fresh;
}

function describe(ev, watch) {
  const d = ev.data ?? {};
  const where = `thread ${d.threadId} on the ${ev.env} T3 environment${ev.environmentId ? ` (environmentId ${ev.environmentId})` : ""}`;
  let what;
  switch (ev.name) {
    case "thread.run_settled":
      what = `The T3 ${where} finished its turn: ${d.outcome}.`;
      break;
    case "thread.needs_input":
      what = `The T3 ${where} is waiting for a person: it needs ${d.kind === "approval" ? "an approval" : "an answer to a question"}.`;
      break;
    case "pr.watch_wake":
      what = `A pull request watched by the T3 ${where} changed and woke the thread${d.outcome ? ` (${d.outcome})` : ""}.`;
      break;
    default:
      what = `T3 event ${ev.name} for ${where}.`;
  }
  return [
    `[t3-events] ${what}`,
    watch?.note ? `What you were waiting for: ${watch.note}` : null,
    `Read it with t3_thread_read (threadId ${d.threadId}${ev.environmentId ? `, environmentId ${ev.environmentId}` : ""}) and carry on with the task.`,
  ]
    .filter(Boolean)
    .join("\n");
}

function runAside(args, timeoutMs = 60_000) {
  return new Promise((resolve) => {
    const p = spawn(ASIDE_BIN, args, { stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    let err = "";
    p.stdout.on("data", (d) => (out += d));
    p.stderr.on("data", (d) => (err += d));
    const t = setTimeout(() => p.kill("SIGTERM"), timeoutMs);
    p.on("close", (code) => {
      clearTimeout(t);
      resolve({ code, out: out.slice(-2000), err: err.slice(-2000) });
    });
    p.on("error", (e) => {
      clearTimeout(t);
      resolve({ code: -1, out: "", err: e.message });
    });
  });
}

// Wake an Aside task: queue the note if the task is mid-run, otherwise resume it.
async function wakeAside(sessionId, text) {
  const q = await runAside(["session", "queue", sessionId, text]);
  if (q.code === 0) return { how: "queue", ...q };
  const r = await runAside(["session", "resume", sessionId, text, "--timeout", "15s"]);
  // resume exits 1 when --timeout passes; the session keeps running, which is what we want.
  const ok = r.code === 0 || (r.code === 1 && /timeout|keeps running|stopped waiting/i.test(r.err + r.out));
  return { how: "resume", ok, ...r, queueErr: q.err };
}

async function route(events) {
  const watches = readJson(WATCHES_FILE, []);
  if (!watches.length) return;
  let changed = false;
  for (const ev of events) {
    if (ev.replay) continue;
    const d = ev.data ?? {};
    for (const w of watches) {
      if (w.done || w.env !== ev.env || w.threadId !== d.threadId) continue;
      if (!(w.types ?? DEFAULT_WATCH_TYPES).includes(ev.name)) continue;
      const text = describe(ev, w);
      const res = await wakeAside(w.session, text);
      const delivered = res.how === "queue" || res.ok;
      appendFileSync(DELIVERIES_FILE, JSON.stringify({ at: new Date().toISOString(), session: w.session, env: ev.env, threadId: d.threadId, event: ev.name, eventId: ev.eventId, how: res.how, delivered, code: res.code, err: delivered ? undefined : (res.err || res.queueErr || "").slice(0, 500) }) + "\n", { mode: 0o600 });
      log(`${delivered ? "woke" : "FAILED to wake"} Aside ${w.session} via ${res.how} for ${ev.env}/${d.threadId} ${ev.name}`);
      if (delivered && !w.keep && ev.name === "thread.run_settled") {
        w.done = new Date().toISOString();
        changed = true;
      }
    }
  }
  if (changed) writeJson(WATCHES_FILE, watches.filter((w) => !w.done || Date.now() - Date.parse(w.done) < 86_400_000));
}

async function pollAll() {
  ensureDirs();
  const cursors = readJson(CURSORS_FILE, {});
  const status = readJson(STATUS_FILE, {});
  const all = [];
  // In parallel, so one asleep VM's timeout does not hold up the others.
  for (const evs of await Promise.all(Object.keys(envs()).map((env) => pollEnv(env, cursors, status)))) all.push(...evs);
  const seen = new Set();
  const out = all.filter((e) => (seen.has(e.env + e.eventId) ? false : seen.add(e.env + e.eventId)));
  out.sort((a, b) => Date.parse(a.timestamp) - Date.parse(b.timestamp));
  for (const e of out) appendFileSync(EVENTS_FILE, JSON.stringify(e) + "\n", { mode: 0o600 });
  writeJson(CURSORS_FILE, cursors);
  writeJson(STATUS_FILE, status);
  await route(out);
  return out;
}

function trimEventsFile() {
  try {
    if (!existsSync(EVENTS_FILE) || statSync(EVENTS_FILE).size < 5_000_000) return;
    const lines = readFileSync(EVENTS_FILE, "utf8").trim().split("\n");
    writeFileSync(EVENTS_FILE, lines.slice(-5000).join("\n") + "\n", { mode: 0o600 });
  } catch {}
}

function readEvents() {
  if (!existsSync(EVENTS_FILE)) return [];
  return readFileSync(EVENTS_FILE, "utf8")
    .split("\n")
    .filter(Boolean)
    .map((l) => {
      try {
        return JSON.parse(l);
      } catch {
        return null;
      }
    })
    .filter(Boolean);
}

// ---------- commands ----------
const [cmd, ...rest] = process.argv.slice(2);
const { pos, flags } = parseArgs(rest);

switch (cmd) {
  case "login": {
    const [env, url] = pos;
    if (!env || !url) throw new Error("usage: t3-events login <env> <mcp-url>");
    await login(env, url, flags);
    break;
  }
  case "envs": {
    const status = readJson(STATUS_FILE, {});
    for (const [env, cfg] of Object.entries(envs())) {
      const tok = loadToken(env);
      const st = status[env];
      console.log(
        `${env}\t${cfg.url}\tsigned in: ${tok ? "yes" : "no"}\texpires: ${tok?.expiresAt ?? "-"}\tlast poll: ${st ? `${st.ok ? "ok" : "ERROR " + st.error} at ${st.at}` : "never"}`,
      );
    }
    break;
  }
  case "once": {
    const evs = await pollAll();
    console.log(`${evs.length} new event(s)`);
    for (const e of evs) console.log(`${e.timestamp} ${e.env} ${e.name} ${e.data?.threadId ?? ""} ${e.data?.outcome ?? e.data?.kind ?? ""}${e.replay ? " (catch-up)" : ""}`);
    break;
  }
  case "run": {
    log(`t3-events running; polling every ${POLL_MS / 1000}s`);
    // Exit when this file changes; launchd's KeepAlive starts the new code (about 30 s later).
    const self = new URL(import.meta.url).pathname;
    const bornMtime = statSync(self).mtimeMs;
    let n = 0;
    for (;;) {
      try {
        if (statSync(self).mtimeMs !== bornMtime) {
          log("code changed; exiting so launchd restarts the new version");
          process.exit(0);
        }
      } catch {}
      try {
        await pollAll();
      } catch (e) {
        log("poll error:", e.message);
      }
      if (++n % 360 === 0) trimEventsFile();
      await sleep(POLL_MS);
    }
  }
  case "watch": {
    const [env, threadId] = pos;
    if (!env || !threadId || !flags.session) throw new Error("usage: t3-events watch <env> <threadId> --session <asideSessionId>");
    if (!envs()[env]) throw new Error(`unknown environment ${env}; known: ${Object.keys(envs()).join(", ")}`);
    ensureDirs();
    const watches = readJson(WATCHES_FILE, []).filter((w) => !(w.env === env && w.threadId === threadId && w.session === flags.session));
    watches.push({
      env,
      threadId,
      session: flags.session,
      types: typeof flags.types === "string" ? flags.types.split(",") : DEFAULT_WATCH_TYPES,
      keep: !!flags.keep,
      note: typeof flags.note === "string" ? flags.note : undefined,
      createdAt: new Date().toISOString(),
    });
    writeJson(WATCHES_FILE, watches);
    console.log(`Watching ${env}/${threadId} for Aside task ${flags.session}.`);
    break;
  }
  case "unwatch": {
    const [env, threadId] = pos;
    const watches = readJson(WATCHES_FILE, []);
    const left = watches.filter((w) => !(w.env === env && w.threadId === threadId && (!flags.session || w.session === flags.session)));
    writeJson(WATCHES_FILE, left);
    console.log(`Removed ${watches.length - left.length} watch(es).`);
    break;
  }
  case "watches": {
    for (const w of readJson(WATCHES_FILE, [])) console.log(`${w.done ? "done " : "live "} ${w.env}/${w.threadId} -> ${w.session} [${(w.types ?? []).join(",")}]${w.note ? " " + w.note : ""}`);
    break;
  }
  case "recent": {
    let evs = readEvents();
    if (flags.env) evs = evs.filter((e) => e.env === flags.env);
    if (flags.thread) evs = evs.filter((e) => e.data?.threadId === flags.thread);
    evs = evs.slice(-Number(flags.limit ?? 20));
    if (flags.json) console.log(JSON.stringify(evs, null, 2));
    else for (const e of evs) console.log(`${e.timestamp} ${e.env} ${e.name} ${e.data?.threadId ?? ""} ${e.data?.outcome ?? e.data?.kind ?? e.data?.resolution ?? ""}`);
    break;
  }
  case "wait": {
    const [env, threadId] = pos;
    const types = typeof flags.types === "string" ? flags.types.split(",") : DEFAULT_WATCH_TYPES;
    const deadline = Date.now() + Number(flags.timeout ?? 600) * 1000;
    const since = new Date().toISOString();
    for (;;) {
      const hit = readEvents().find((e) => e.env === env && e.data?.threadId === threadId && types.includes(e.name) && e.timestamp >= since);
      if (hit) {
        console.log(JSON.stringify(hit));
        process.exit(0);
      }
      if (Date.now() > deadline) {
        console.error("timed out");
        process.exit(1);
      }
      await sleep(2000);
    }
  }
  default:
    console.log(readFileSync(new URL(import.meta.url), "utf8").split("\n").slice(1, 20).join("\n").replace(/^\/\/ ?/gm, ""));
}
