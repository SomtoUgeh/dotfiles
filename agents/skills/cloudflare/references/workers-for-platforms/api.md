# Workers for Platforms API

## Upload a user Worker

Use account-scoped authorization and correct multipart part names. The metadata part is JSON and the module part name must match `main_module`.

```typescript
export async function uploadUserWorker(
  accountId: string, namespace: string, scriptName: string,
  apiToken: string, source: string,
): Promise<void> {
  if (!accountId || !namespace || !scriptName || !apiToken) {
    throw new Error("Deployment configuration missing");
  }
  const body = new FormData();
  body.set("metadata", new Blob([JSON.stringify({
    main_module: "index.mjs", compatibility_date: "2026-09-05",
  })], { type: "application/json" }));
  body.set("index.mjs", new File([source], "index.mjs", {
    type: "application/javascript+module",
  }));
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${encodeURIComponent(accountId)}/workers/dispatch/namespaces/${encodeURIComponent(namespace)}/scripts/${encodeURIComponent(scriptName)}`,
    { method: "PUT", headers: { Authorization: `Bearer ${apiToken}` }, body,
      signal: AbortSignal.timeout(30000) },
  );
  const payload: unknown = await response.json();
  if (!response.ok || !payload || typeof payload !== "object" ||
      !("success" in payload) || payload.success !== true) {
    throw new Error(`Worker upload failed (${response.status})`);
  }
}
```

Authorize the target namespace/script and enforce source/upload limits in the platform before calling this helper. Let fetch generate the multipart Content-Type boundary. Add bindings/tags/assets to the JSON metadata from validated platform configuration. Do not put JavaScript comments inside a JSON part.

The SDK's typed signature is `scripts.update(scriptName, { account_id, dispatch_namespace, metadata, files })`. In Cloudflare SDK 7.1.0, a transport fixture found incompatible multipart serialization/content-type for this operation. The REST example avoids that specific SDK path; a passing typecheck alone does not prove upload compatibility. Recheck transport when upgrading.

For existing bindings, `keep_bindings` is an array of binding **types**, such as `["kv_namespace", "d1"]`, not a Boolean or a list of binding names. Supply actual provisioned resource IDs. Coordinate the full intended deployment metadata to avoid deleting or leaking bindings.

## Dispatch

Use generated `DispatchNamespace` types rather than redeclaring them. Resolve the complete normalized hostname through your verified routing registry and reject missing/disabled mappings before obtaining a Worker.

```typescript
const scriptName = await env.ROUTING_KV.get(new URL(request.url).hostname);
if (!scriptName) return new Response("Unknown site", { status: 404 });
try {
  const worker = env.DISPATCHER.get(scriptName, {}, {
    limits: { cpuMs: 50, subRequests: 20 },
  });
  return await worker.fetch(request);
} catch (error) {
  if (error instanceof Error && error.message.startsWith("Worker not found")) {
    return new Response("Site unavailable", { status: 404 });
  }
  throw error;
}
```

`await` inside the try is required to catch asynchronous invocation errors. KV is eventually consistent; use a suitable authoritative check for immediate revocation or private authorization. A hostname mapping is sufficient only for deliberately public sites, not private account access.

## Static assets

Create the script's `assets-upload-session` with a manifest of file paths, byte sizes, and consistently generated 32-hex hashes. The returned `buckets` are groups of missing file hashes, not redundant upload URLs. Upload each group to the account's `/workers/assets/upload?base64=true` endpoint using the short-lived upload JWT and hash-named base64 form fields. Once all groups complete, use the returned completion JWT in deployment `assets.jwt`. An already-complete session may return a usable JWT without buckets.

Assets are associated with the namespace and can be shared by equal hashes. Keep JWTs in trusted platform services. Where strict tenant separation is required, incorporate an unambiguous tenant identifier or salt into the hash input. Do not expose an upload token to end users or assume the user Worker boundary makes all assets private.

## Outbound policy

The outbound Worker intercepts user Worker fetches but does not intercept Durable Object or mTLS binding fetches. Enabling it disables user Worker `connect()` access. Bindings can still create other capabilities and require their own policy.

Enforce destinations against the actual subrequest URL: parse it, require an allowed scheme/port, and compare exact hostnames (or deliberate dot-boundary suffixes). A substring check is bypassable. Use manual redirects or revalidate each redirect before adding platform credentials; never forward injected authorization to an unchecked host.

Pass only validated platform context through configured outbound parameters. Confirm the installed/runtime parameter shape before accessing it; the outbound request URL and the original incoming URL are distinct.

[Upload metadata](https://developers.cloudflare.com/workers/configuration/multipart-upload-metadata/) · [Static assets](https://developers.cloudflare.com/cloudflare-for-platforms/workers-for-platforms/configuration/static-assets/) · [Outbound Workers](https://developers.cloudflare.com/cloudflare-for-platforms/workers-for-platforms/configuration/outbound-workers/)
