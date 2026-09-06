# Patterns

## Secret Rotation

Rotation with overlapping valid keys and versioned naming (`api_key_v1`, `api_key_v2`):

```typescript
interface Env {
  PRIMARY_KEY: { get(): Promise<string> };
  FALLBACK_KEY?: { get(): Promise<string> };
}

async function fetchWithAuth(url: string, key: string) {
  return fetch(url, { headers: { "Authorization": `Bearer ${key}` } });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    let resp = await fetchWithAuth("https://api.example.com", await env.PRIMARY_KEY.get());
    
    // Fallback during rotation
    if (resp.status === 401 && env.FALLBACK_KEY) {
      await resp.body?.cancel();
      resp = await fetchWithAuth("https://api.example.com", await env.FALLBACK_KEY.get());
    }
    
    return resp;
  }
}
```

Workflow: Create `api_key_v2` → add fallback binding → deploy → swap primary → deploy → remove `v1`

## Encryption with KV

```typescript
interface Env {
  CACHE: KVNamespace;
  ENCRYPTION_KEY: { get(): Promise<string> };
}

async function encryptValue(value: string, key: string): Promise<string> {
  const enc = new TextEncoder();
  // Store a randomly generated 256-bit key encoded as base64, not a password.
  const keyBytes = Uint8Array.from(atob(key), character => character.charCodeAt(0));
  if (keyBytes.length !== 32) throw new Error("Expected a 256-bit AES key");
  const keyMaterial = await crypto.subtle.importKey(
    "raw", keyBytes, { name: "AES-GCM" }, false, ["encrypt"]
  );
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv }, keyMaterial, enc.encode(value)
  );
  
  const combined = new Uint8Array(iv.length + encrypted.byteLength);
  combined.set(iv);
  combined.set(new Uint8Array(encrypted), iv.length);
  let binary = "";
  for (const byte of combined) binary += String.fromCharCode(byte);
  return btoa(binary);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const key = await env.ENCRYPTION_KEY.get();
    const encrypted = await encryptValue("sensitive-data", key);
    await env.CACHE.put("user:123:data", encrypted);
    return Response.json({ ok: true });
  }
}
```

## HMAC Signing

```typescript
interface Env {
  HMAC_SECRET: { get(): Promise<string> };
}

async function signRequest(data: string, secret: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(data));
  return btoa(String.fromCharCode(...new Uint8Array(sig)));
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const secret = await env.HMAC_SECRET.get();
    const payload = await request.text();
    const signature = await signRequest(payload, secret);
    return Response.json({ signature });
  }
}
```

## Audit & Monitoring

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext) {
    const startTime = Date.now();
    try {
      const apiKey = await env.API_KEY.get();
      const resp = await fetch("https://api.example.com", {
        headers: { "Authorization": `Bearer ${apiKey}` }
      });
      
      ctx.waitUntil(
        fetch("https://log.example.com/log", {
          method: "POST",
          body: JSON.stringify({
            event: "secret_used",
            secret_name: "API_KEY",
            timestamp: new Date().toISOString(),
            duration_ms: Date.now() - startTime,
            success: resp.ok
          })
        })
      );
      return resp;
    } catch (error) {
      ctx.waitUntil(
        fetch("https://log.example.com/log", {
          method: "POST",
          body: JSON.stringify({
            event: "secret_access_failed",
            secret_name: "API_KEY",
            error: error instanceof Error ? error.message : "Unknown"
          })
        })
      );
      return new Response("Error", { status: 500 });
    }
  }
}
```

## Migration from Worker Secrets

Change `env.SECRET` (direct) to `await env.SECRET.get()` (async).

Steps:
1. Create in Secrets Store: `wrangler secrets-store secret create <store-id> --name API_KEY --scopes workers --remote`
2. Add binding to `wrangler.jsonc`: `{"binding": "API_KEY", "store_id": "abc123", "secret_name": "api_key"}`
3. Update code: `const key = await env.API_KEY.get();`
4. Test staging, deploy
5. Remove old: `wrangler secret delete API_KEY`

## Sharing Across Workers

Same secret, different binding names:

```jsonc
// worker-1: binding="SHARED_DB", secret_name="postgres_url"
// worker-2: binding="DB_CONN", secret_name="postgres_url"
```

## JSON Secret Parsing

Parse into `unknown` and validate the required fields with the project's schema library before building a client. A TypeScript annotation does not validate JSON. Use the database driver's connection options so usernames/passwords are not interpolated into an unescaped URL. Return a connected result only after the connection or health query succeeds.

Keep secret values out of shell history: use Wrangler's prompt or an environment variable piped through `printf '%s' "$VALUE"`. Do not log parsing errors that include secret contents.

## Integration

### Service Bindings

Auth Worker signs JWT with Secrets Store; API Worker verifies via service binding.

See: [workers](../workers/) for service binding patterns.

See: [api.md](./api.md), [gotchas.md](./gotchas.md)
