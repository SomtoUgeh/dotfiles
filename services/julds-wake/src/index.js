// julds-wake: one-tap resume for the boat VMs (julds and the project VMs), gated by Cloudflare Access.
// Opening the page wakes julds (or ?vm=<name>); ?peek only shows state. Each VM has its own Wake button.
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

// VMS: "name:sandbox id" pairs. julds uses BOAT_KEY (julds only); the project VMs use BOAT_KEY_VMS
// (resume + read on those five sandboxes only, key "julds-wake-page-vms").
const vmList = (env) => (env.VMS || `julds:${env.SANDBOX_ID}`).split(",").map((x) => { const [name, id] = x.trim().split(":"); return { name, id }; });
const keyFor = (env, id) => (id === env.SANDBOX_ID ? env.BOAT_KEY : env.BOAT_KEY_VMS);

async function boat(env, id, path = "", init = {}) {
  const r = await fetch(`${BOAT}/${id}${path}`, {
    ...init,
    headers: { authorization: `Bearer ${keyFor(env, id)}`, "content-type": "application/json", "user-agent": "julds-wake/2" },
  });
  const body = await r.json().catch(() => ({}));
  return { status: r.status, body };
}

async function status(env, vm) {
  const { status: code, body } = await boat(env, vm.id);
  const sb = body.sandbox || {};
  let t3 = null;
  // Only julds is reachable from here (T3 Connect); project VMs are on the tailnet only.
  if (vm.id === env.SANDBOX_ID && (sb.state === "idle" || sb.state === "running")) {
    try {
      const r = await fetch(env.T3_RELAY_URL, { headers: { "user-agent": "julds-wake/2" }, signal: AbortSignal.timeout(4000) });
      t3 = r.ok;
    } catch { t3 = false; }
  }
  return { name: vm.name, id: vm.id, ok: code === 200, state: sb.state || "unknown", health: sb.health || null, t3, error: code === 200 ? null : body.message || `boat ${code}` };
}
const allStatus = (env) => Promise.all(vmList(env).map((vm) => status(env, vm)));

async function wakeOne(env, vm, email) {
  const before = await status(env, vm);
  if (!WAKEABLE.includes(before.state)) return before;
  const r = await boat(env, vm.id, "/resume", { method: "POST", body: "{}" });
  console.log(JSON.stringify({ wake: vm.name, by: email, boatStatus: r.status }));
  if (r.status >= 300) {
    await sendAlert(env, `wake failed: ${vm.name}`, `Resume of ${vm.name} (${vm.id}) returned ${r.status}: ${r.body.message || ""}`);
    return { ...before, error: r.body.message || `resume failed (${r.status})` };
  }
  return { ...before, state: "starting" };
}

const PAGE = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-title" content="Wake VMs">
<meta name="theme-color" content="#0b0b0c"><title>Wake VMs</title>
<style>
:root{color-scheme:dark}body{margin:0;min-height:100dvh;display:grid;place-items:center;background:#0b0b0c;color:#eee;font:16px/1.4 -apple-system,system-ui,sans-serif}
main{width:min(380px,90vw)}h1{font-size:22px;margin:0 0 14px;text-align:center}
.row{display:flex;align-items:center;gap:10px;padding:12px 4px;border-bottom:1px solid #222}
.name{font-weight:600;min-width:92px}.label{flex:1;color:#aaa;font-size:14px}
.dot{display:inline-block;width:10px;height:10px;border-radius:50%;background:#666;flex:none}
.on{background:#3ecf6e}.mid{background:#e8b339}.off{background:#e5534b}
button{border:0;border-radius:10px;font-size:15px;font-weight:600;background:#3b6cf6;color:#fff;padding:9px 14px}
button:disabled{opacity:.35}#all{width:100%;margin-top:18px;padding:15px;font-size:17px;border-radius:14px}
small{display:block;margin-top:16px;color:#666;text-align:center}
</style></head><body><main>
<h1>Boat VMs</h1><div id="list"></div>
<button id="all" disabled>Wake all</button>
<small>Project VMs sleep after 30 quiet minutes. T3 on your phone needs Tailscale on.</small>
</main><script>
const WAKEABLE=${JSON.stringify(WAKEABLE)};const peek=new URLSearchParams(location.search).has("peek");
const want=new URLSearchParams(location.search).get("vm");let autoDone=false;
function view(s){let cls="mid",label=s.state;
 if(WAKEABLE.includes(s.state)){cls="off";label="Asleep"}
 else if(["idle","running","ready"].includes(s.state)){cls=s.t3===false?"mid":"on";label=s.t3===null?"Running":(s.t3?"Running · T3 ready":"Running · T3 starting")}
 else if(["starting","resuming","provisioned","cloning"].includes(s.state)){label="Waking…"}
 else if(s.state==="stopping"){label="Going to sleep…"}
 if(s.error)label=s.error;return{cls,label}}
function render(list){const el=document.getElementById("list");el.innerHTML="";let any=false;
 for(const s of list){const v=view(s);const can=WAKEABLE.includes(s.state);any=any||can;
  const row=document.createElement("div");row.className="row";
  row.innerHTML='<span class="dot '+v.cls+'"></span><span class="name"></span><span class="label"></span><button>Wake</button>';
  row.querySelector(".name").textContent=s.name;row.querySelector(".label").textContent=v.label;
  const b=row.querySelector("button");b.disabled=!can;b.onclick=()=>wake(s.name);el.appendChild(row)}
 document.getElementById("all").disabled=!any;return list}
async function poll(){try{const list=render(await (await fetch("status",{cache:"no-store"})).json());
 if(!autoDone&&!peek){autoDone=true;const t=list.find(s=>s.name===(want||"julds"));if(t&&WAKEABLE.includes(t.state))wake(t.name)}}catch(e){}}
async function wake(name){await fetch("wake"+(name?"?vm="+encodeURIComponent(name):""),{method:"POST"});poll()}
document.getElementById("all").onclick=()=>wake("");poll();setInterval(poll,4000);
</script></body></html>`;


// Weekly dated saved snapshot (cron), keeping the newest KEEP_WEEKLY. Uses BOAT_SNAPSHOT_KEY:
// snapshot.read + snapshot.write + sandbox.read on bx_2jd5dd8b only. Works while the VM is stopped.
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
      "", "Check: boat info bx_2jd5dd8b  |  Recover: boat recover bx_2jd5dd8b  |  Status page: https://wake.julds.com/?peek",
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
    if (req.method === "GET" && url.pathname === "/status") return json(await allStatus(env));
    if (req.method === "POST" && url.pathname === "/wake") {
      const origin = req.headers.get("origin");
      if (origin && origin !== url.origin) return json({ error: "bad origin" }, 403);
      // ?vm=<name> wakes one VM; no name wakes every VM that is asleep (spaced out: boat throttles restores).
      const name = url.searchParams.get("vm");
      const targets = vmList(env).filter((vm) => !name || vm.name === name);
      if (!targets.length) return json({ error: "unknown VM" }, 404);
      const out = [];
      for (const vm of targets) {
        out.push(await wakeOne(env, vm, auth.email));
        if (targets.length > 1) await new Promise((r) => setTimeout(r, 1500));
      }
      return json(out, out.some((x) => x.error) ? 502 : 200);
    }
    return new Response("Not found", { status: 404 });
  },
};
