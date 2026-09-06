# Multi-tenant dispatch patterns

## Trusted hostname routing with plan limits

Provision the hostname-to-Worker mapping through the authorized control plane.
Match the full registered hostname; splitting off its first label can route an
unrelated domain to another customer's Worker.

```typescript
type Env = { DISPATCHER: DispatchNamespace; ROUTING_KV: KVNamespace };
const plans = new Map([
  ['enterprise', { cpuMs: 50, subRequests: 50 }],
  ['pro', { cpuMs: 20, subRequests: 20 }],
  ['free', { cpuMs: 10, subRequests: 5 }],
]);
function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const hostname = new URL(request.url).hostname;
    const route: unknown = await env.ROUTING_KV.get(`hostname:${hostname}`, 'json');
    if (!isRecord(route) || typeof route.workerName !== 'string' || !route.workerName) {
      return new Response('Hostname not configured', { status: 404 });
    }
    const limits = typeof route.plan === 'string' ? plans.get(route.plan) : undefined;
    if (!limits) return new Response('Routing configuration unavailable', { status: 503 });
    try {
      return await env.DISPATCHER.get(route.workerName, {}, { limits }).fetch(request);
    } catch (error) {
      if (error instanceof Error && error.message.startsWith('Worker not found')) {
        return new Response('Worker not found', { status: 404 });
      }
      throw error;
    }
  }
};
```

The limit values are illustrative product tiers, not billing calculations or
platform maxima. KV is eventually consistent; use an authoritative store for
access revocations or entitlements requiring immediate consistency. Apply the
application's authentication/authorization before dispatch where the site or
function is private.

## Resource and hostname setup

Bind each tenant to provisioned resources using their actual returned IDs.
Use separate resources when the data-isolation requirements call for them; shared
resources need a tested tenant partitioning scheme. Tags label resources but do
not enforce authorization.

For vanity domains, configure Cloudflare for SaaS custom hostnames, the fallback
origin, DNS, and the dispatch Worker route. A zone's `*/*` route is the documented
pattern for supported orange-to-orange cases, but it does not bypass hostname
onboarding or DNS requirements. Verify one standard and one customer-proxied
hostname. Custom hostnames do not have to be subdomains of the platform's domain.

## Upload generated code

This control-plane function performs a deployment when invoked. Validate the
customer's ownership and the intended namespace before calling it. Keep user code
in untrusted mode unless the platform controls and trusts every script.

```typescript
export async function deployGeneratedCode(
  apiToken: string, accountId: string, namespace: string, name: string, code: string,
): Promise<void> {
  if (![apiToken, accountId, namespace, name].every(value => value.trim())) {
    throw new Error('Missing deployment configuration');
  }
  const form = new FormData();
  form.set('metadata', new Blob([JSON.stringify({
    main_module: 'index.mjs', tags: ['ai-generated'],
  })], { type: 'application/json' }));
  form.set('index.mjs', new File([code], 'index.mjs', {
    type: 'application/javascript+module',
  }));
  const url = `https://api.cloudflare.com/client/v4/accounts/${encodeURIComponent(accountId)}`
    + `/workers/dispatch/namespaces/${encodeURIComponent(namespace)}/scripts/${encodeURIComponent(name)}`;
  const response = await fetch(url, {
    method: 'PUT', headers: { Authorization: `Bearer ${apiToken}` }, body: form,
    signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new Error(`Worker upload failed (HTTP ${response.status})`);
  const result: unknown = await response.json();
  if (result === null || typeof result !== 'object'
      || !('success' in result) || result.success !== true) {
    throw new Error('Worker upload failed');
  }
}
```

Let fetch generate the multipart Content-Type boundary. This uses the documented
REST format because an SDK 7.1.0 transport fixture emitted `application/javascript`
with multipart bytes and nested metadata fields; its typecheck alone did not
prove a valid upload. Recheck a newer SDK's actual request before adopting it.
An upload timeout is ambiguous: inspect the script's current state before retrying.

For updates, include the existing bindings and required script settings explicitly;
see [gotchas.md](./gotchas.md). For assets, keep the completion JWT server-side and
attach it only to the selected tenant's script. Use tenant-specific hashing when
cross-script deduplication would violate isolation requirements.

## Observability and staged rollout

Collect dispatch/user-Worker outcomes with the configured Logpush or Tail Worker
facilities. A dispatch Worker logging setting alone does not prove every user
script's logs were exported. Test the expected stream before relying on it.

Use Analytics Engine for scoped usage events and query the account's available
GraphQL schema for supported namespace/script dimensions. Do not paste a guessed
GraphQL metric name or undeclared variable into a billing query. Reconcile sampled
metrics appropriately and keep billing identifiers under platform control.

User-script gradual deployments are not supported. For a staged rollout, deploy
separate script names and select them through trusted routing configuration, with
a rollback plan. Verify isolation, unknown host, stale mapping, missing Worker,
and custom CPU/subrequest limits before launch.

Sources: [Workers for Platforms](https://developers.cloudflare.com/cloudflare-for-platforms/workers-for-platforms/),
[custom hostnames](https://developers.cloudflare.com/cloudflare-for-platforms/workers-for-platforms/configuration/hostname-routing/).
