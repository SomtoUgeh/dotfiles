// julds-wake: one-tap resume for the julds boat VM, gated by Cloudflare Access.
// The Worker re-verifies the Access JWT itself and fails closed if ACCESS_AUD is unset.
const BOAT = "https://boat.dev/api/v1/sandboxes";
// boat's API reports a stopped VM as "archived" (the CLI shows "stopped"); treat all of these as wakeable.
const WAKEABLE = ["stopped", "archived", "hibernated", "suspended", "paused"];
let certCache = { at: 0, keys: null };

const b64urlToBytes = (s) => {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(s + "===".slice((s.length + 3) % 4));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
};
const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json", "cache-control": "no-store" } });

async function accessKeys(team) {
  if (certCache.keys && Date.now() - certCache.at < 3600_000) return certCache.keys;
  const r = await fetch(`https://${team}.cloudflareaccess.com/cdn-cgi/access/certs`);
  const { keys } = await r.json();
  certCache = { at: Date.now(), keys };
  return keys;
}

async function verifyAccess(req, env) {
  if (!env.ACCESS_AUD) return { ok: false, why: "ACCESS_AUD not configured" };
  const token = req.headers.get("cf-access-jwt-assertion");
  if (!token) return { ok: false, why: "no Access token" };
  const [h, p, s] = token.split(".");
  if (!h || !p || !s) return { ok: false, why: "malformed token" };
  const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(h)));
  const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(p)));
  const jwk = (await accessKeys(env.ACCESS_TEAM)).find((k) => k.kid === header.kid);
  if (!jwk || header.alg !== "RS256") return { ok: false, why: "unknown signing key" };
  const key = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const valid = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, b64urlToBytes(s), new TextEncoder().encode(`${h}.${p}`));
  if (!valid) return { ok: false, why: "bad signature" };
  const now = Math.floor(Date.now() / 1000);
  const aud = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  if (payload.exp < now) return { ok: false, why: "expired" };
  if (!aud.includes(env.ACCESS_AUD)) return { ok: false, why: "wrong audience" };
  if (payload.iss !== `https://${env.ACCESS_TEAM}.cloudflareaccess.com`) return { ok: false, why: "wrong issuer" };
  const allowed = env.ALLOWED_EMAILS.split(",").map((e) => e.trim().toLowerCase());
  if (!allowed.includes(String(payload.email || "").toLowerCase())) return { ok: false, why: "email not allowed" };
  return { ok: true, email: payload.email };
}

async function boat(env, path = "", init = {}) {
  const r = await fetch(`${BOAT}/${env.SANDBOX_ID}${path}`, {
    ...init,
    headers: { authorization: `Bearer ${env.BOAT_KEY}`, "content-type": "application/json", "user-agent": "julds-wake/1" },
  });
  const body = await r.json().catch(() => ({}));
  return { status: r.status, body };
}

async function status(env) {
  const { status: code, body } = await boat(env);
  const sb = body.sandbox || {};
  let t3 = null;
  if (sb.state === "idle" || sb.state === "running") {
    try {
      const r = await fetch(env.T3_RELAY_URL, { headers: { "user-agent": "julds-wake/1" }, signal: AbortSignal.timeout(4000) });
      t3 = r.ok;
    } catch { t3 = false; }
  }
  return { ok: code === 200, state: sb.state || "unknown", health: sb.health || null, t3, error: code === 200 ? null : body.message || `boat ${code}` };
}

const PAGE = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-title" content="Wake julds">
<meta name="theme-color" content="#0b0b0c"><title>Wake julds</title>
<style>
:root{color-scheme:dark}body{margin:0;min-height:100dvh;display:grid;place-items:center;background:#0b0b0c;color:#eee;font:16px/1.4 -apple-system,system-ui,sans-serif}
main{width:min(360px,88vw);text-align:center}h1{font-size:22px;margin:0 0 4px}p{margin:6px 0;color:#aaa}
.dot{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:8px;background:#666;vertical-align:middle}
.on{background:#3ecf6e}.mid{background:#e8b339}.off{background:#e5534b}
#state{font-size:20px;color:#eee;margin:22px 0 6px}
button{margin-top:22px;width:100%;padding:16px;border:0;border-radius:14px;font-size:18px;font-weight:600;background:#3b6cf6;color:#fff}
button:disabled{opacity:.45}small{display:block;margin-top:18px;color:#666}
</style></head><body><main>
<h1>julds VM</h1><p>boat sandbox bx_gbx664fj</p>
<div id="state"><span class="dot" id="dot"></span><span id="label">Checking…</span></div>
<p id="detail"></p>
<button id="wake" disabled>Wake julds</button>
<small id="who"></small>
</main><script>
const $=id=>document.getElementById(id);let woke=false;const WAKEABLE=${JSON.stringify(WAKEABLE)};
const peek=new URLSearchParams(location.search).has("peek");
function show(s){const st=s.state;let cls="mid",label=st,detail="";
 if(WAKEABLE.includes(st)){cls="off";label="Stopped";detail="Tap Wake to start it."}
 else if(["idle","running","ready"].includes(st)){cls=s.t3?"on":"mid";label=s.t3?"Running · T3 ready":"Running · T3 starting";detail=s.t3?"Open T3 Code.":"Give T3 about a minute."}
 else if(["starting","resuming","provisioned","cloning"].includes(st)){label="Starting…";detail="Usually under 2 minutes."}
 else if(st==="stopping"){label="Stopping…";detail="Wait, then wake it again."}
 if(s.error)detail=s.error;
 $("dot").className="dot "+cls;$("label").textContent=label;$("detail").textContent=detail;
 $("wake").disabled=!WAKEABLE.includes(st);return st}
async function poll(){try{const r=await fetch("status",{cache:"no-store"});const s=await r.json();const st=show(s);
 if(WAKEABLE.includes(st)&&!woke&&!peek){wake()}}catch(e){$("detail").textContent="Could not reach status"}}
async function wake(){woke=true;$("wake").disabled=true;$("label").textContent="Waking…";
 const r=await fetch("wake",{method:"POST"});const s=await r.json();show(s)}
$("wake").onclick=wake;poll();setInterval(poll,4000);
</script></body></html>`;


// Weekly dated saved snapshot (cron), keeping the newest KEEP_WEEKLY. Uses BOAT_SNAPSHOT_KEY:
// snapshot.read + snapshot.write + sandbox.read on bx_gbx664fj only. Works while the VM is stopped.
async function weeklySnapshot(env) {
  const h = { authorization: `Bearer ${env.BOAT_SNAPSHOT_KEY}`, "content-type": "application/json", "user-agent": "julds-wake/1" };
  const prefix = "julds-weekly-";
  const name = prefix + new Date().toISOString().slice(0, 10);
  const save = await fetch("https://boat.dev/api/v1/saved-snapshots", { method: "POST", headers: h, body: JSON.stringify({ sandboxId: env.SANDBOX_ID, name }) });
  console.log(JSON.stringify({ weeklySnapshot: name, status: save.status }));
  if (save.status >= 300) { await sendAlert(env, "weekly snapshot failed", `Saving ${name} returned ${save.status}: ${await save.text()}`); return; }
  const list = await (await fetch("https://boat.dev/api/v1/saved-snapshots", { headers: h })).json().catch(() => ({}));
  const items = (list.named || list.savedSnapshots || list.snapshots || []).map((x) => x.name).filter((n) => n && n.startsWith(prefix) && n !== name).sort();
  const keep = Number(env.KEEP_WEEKLY || 4) - 1;
  for (const old of items.slice(0, Math.max(0, items.length - keep))) {
    const d = await fetch(`https://boat.dev/api/v1/saved-snapshots/${encodeURIComponent(old)}`, { method: "DELETE", headers: h });
    console.log(JSON.stringify({ pruned: old, status: d.status }));
  }
}

// ---- Alerts: boat webhooks (and our own failures) -> email to smugeh@gmail.com via alerts.julds.com ----
const ALERT_EVENTS = ["sandbox.error", "sandbox.degraded", "sandbox.recovered"];
async function sendAlert(env, subject, text) {
  try {
    await env.EMAIL.send({ to: env.ALERT_TO, from: { email: env.ALERT_FROM, name: "julds alerts" }, subject: `[julds] ${subject}`, text });
  } catch (e) { console.log(JSON.stringify({ alertSendFailed: e.code || String(e), subject })); }
}
const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
async function handleBoatWebhook(req, env) {
  const raw = await req.text();
  const id = req.headers.get("x-ascii-delivery") || "";
  const ts = req.headers.get("x-ascii-timestamp") || "";
  const sig = (req.headers.get("x-ascii-signature") || "").replace(/^v1=/, "");
  if (!env.BOAT_WEBHOOK_SECRET || !/^[a-f0-9]{64}$/i.test(sig) || Math.abs(Date.now() / 1000 - Number(ts)) > 300) return new Response("bad signature", { status: 401 });
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(env.BOAT_WEBHOOK_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const expected = hex(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${id}.${ts}.${raw}`)));
  let diff = expected.length ^ sig.length;
  for (let i = 0; i < Math.min(expected.length, sig.length); i++) diff |= expected.charCodeAt(i) ^ sig.toLowerCase().charCodeAt(i);
  if (diff !== 0) return new Response("bad signature", { status: 401 });
  const evt = JSON.parse(raw);
  const sb = evt.data?.sandbox || {};
  console.log(JSON.stringify({ webhook: evt.type, sandbox: sb.id, delivery: id }));
  if (ALERT_EVENTS.includes(evt.type) && (!sb.id || sb.id === env.SANDBOX_ID)) {
    const what = { "sandbox.error": "VM is in error", "sandbox.degraded": "VM is not fully reachable", "sandbox.recovered": "VM recovered" }[evt.type];
    await sendAlert(env, what, [
      `${what} (${evt.type}) at ${evt.createdAt}.`,
      evt.data?.state ? `State: ${evt.data.previousState || "?"} -> ${evt.data.state}` : "",
      evt.data?.reason ? `Reason: ${evt.data.reason}` : "",
      "", "Check: boat info bx_gbx664fj  |  Recover: boat recover bx_gbx664fj  |  Status page: https://wake.julds.com/?peek",
      `Event id: ${evt.id}`,
    ].filter(Boolean).join("\n"));
  }
  return new Response("ok");
}

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(weeklySnapshot(env));
  },
  async fetch(req, env) {
    const u0 = new URL(req.url);
    if (req.method === "POST" && u0.pathname === "/hooks/boat") return handleBoatWebhook(req, env);
    const auth = await verifyAccess(req, env);
    if (!auth.ok) return new Response(`Forbidden: ${auth.why}`, { status: 403 });
    const url = new URL(req.url);
    if (req.method === "GET" && url.pathname === "/") return new Response(PAGE, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" } });
    if (req.method === "GET" && url.pathname === "/status") return json(await status(env));
    if (req.method === "POST" && url.pathname === "/wake") {
      const origin = req.headers.get("origin");
      if (origin && origin !== url.origin) return json({ error: "bad origin" }, 403);
      const before = await status(env);
      if (!WAKEABLE.includes(before.state)) return json(before);
      const r = await boat(env, "/resume", { method: "POST", body: "{}" });
      console.log(JSON.stringify({ wake: true, by: auth.email, boatStatus: r.status }));
      if (r.status >= 300) { await sendAlert(env, "wake failed", `Resume returned ${r.status}: ${r.body.message || ""}`); return json({ ...before, error: r.body.message || `resume failed (${r.status})` }, 502); }
      return json({ ...(await status(env)), state: "starting" });
    }
    return new Response("Not found", { status: 404 });
  },
};
