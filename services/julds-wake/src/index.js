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

export default {
  async fetch(req, env) {
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
      if (r.status >= 300) return json({ ...before, error: r.body.message || `resume failed (${r.status})` }, 502);
      return json({ ...(await status(env)), state: "starting" });
    }
    return new Response("Not found", { status: 404 });
  },
};
