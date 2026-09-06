# Workers for Platforms configuration

## Namespace and dispatcher

```bash
wrangler dispatch-namespace list
wrangler dispatch-namespace get production
wrangler dispatch-namespace create production
```

Create only when absent. Rename/delete are supported commands but affect existing routing and deployments; inspect the exact target before use.

Dispatcher configuration:

```jsonc
{
  "name": "platform-dispatcher",
  "main": "src/index.ts",
  "compatibility_date": "2026-09-05",
  "dispatch_namespaces": [{
    "binding": "DISPATCHER", "namespace": "production", "remote": true,
    "outbound": {
      "service": "platform-outbound",
      "parameters": ["tenant_context"]
    }
  }]
}
```

Omit outbound when it is not used. Pass a validated `tenant_context` via the third argument of `DISPATCHER.get` when configured. Add the platform's actual routing-store binding separately; do not invent a KV ID from a tenant name.

`remote: true` allows local dispatch code to invoke deployed user Workers; it uses real account resources. For offline tests, mock the dispatcher. Generate matching types with `wrangler types`.

## User Worker assets

This is a separate project/configuration from the dispatcher:

```jsonc
{
  "name": "customer-site",
  "main": "src/index.js",
  "compatibility_date": "2026-09-05",
  "assets": { "directory": "public", "binding": "ASSETS" }
}
```

```bash
wrangler deploy --name customer-site --dispatch-namespace production
```

The `dispatch_namespaces` binding does not deploy a Worker into that namespace; the deploy flag chooses the upload destination. See [api.md](api.md) for programmatic multipart/asset deployment.

## Isolation and limits

Retain untrusted mode for customer code. Each Worker has isolated cache behavior; the Cache API is not universally disabled. Trusted mode exposes `request.cf` and shared-zone caches and requires platform-controlled code. Use the official namespace update procedure and redeploy existing Workers when changing mode.

Set per-invocation `cpuMs` and `subRequests` in dispatch options. Handle thrown errors without assuming every error has a `.message`, and distinguish platform budget failures from client rate limiting. Test the actual error contract before mapping a string to an HTTP status.

## Tags and bindings

Up to eight tags per script can support inventory and cleanup. Tags are selection metadata, not authorization. Inspect all matches before a bulk delete and use the exact documented endpoint/filter shape.

Provision each resource first, then use its returned ID/name in the upload metadata. Supported binding types evolve; refer to the current multipart metadata documentation instead of a fixed “29 types” list. `keep_bindings` preserves the specified types and needs deliberate ownership of the full deployment state.

[Isolation](https://developers.cloudflare.com/cloudflare-for-platforms/workers-for-platforms/reference/worker-isolation/) · [Local development](https://developers.cloudflare.com/cloudflare-for-platforms/workers-for-platforms/reference/local-development/) · [Tags](https://developers.cloudflare.com/cloudflare-for-platforms/workers-for-platforms/configuration/tags/)
