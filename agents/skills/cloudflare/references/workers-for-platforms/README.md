# Workers for Platforms

Use Workers for Platforms to deploy and invoke customer Workers through a platform-controlled dispatch Worker. It is suitable for programmable applications and multi-tenant hosting. Use regular Workers for your own application code; a full-process sandbox is a different runtime choice.

The platform has a dispatch namespace, a dispatch Worker, user Workers, and optionally an outbound Worker. The dispatcher resolves a trusted routing/tenant record, applies authorization and limits, and invokes `env.DISPATCHER.get(scriptName).fetch(request)`.

Isolation is enabled by default. Untrusted user Workers do not receive `request.cf` and have isolated caches. Do not switch a customer-code namespace to trusted mode merely to obtain geolocation. If trusted mode is needed, the platform must control all code and handle shared-zone cache implications.

User Worker isolation does not partition bindings you deliberately share. Provision and authorize tenant resources and deployment operations explicitly. WfP removes the ordinary script-count ceiling, but CPU, request, asset, binding, and account limits still apply.

| Task | Reference |
|---|---|
| Namespace, dispatcher, limits, assets | [configuration.md](configuration.md) |
| Upload, routing, outbound, asset APIs | [api.md](api.md) |
| Tenant deployment and data architecture | [patterns.md](patterns.md) |
| Limits, errors, isolation caveats | [gotchas.md](gotchas.md) |

For custom domains, combine supported zone routes with Cloudflare for SaaS and a verified hostname-to-tenant registry. Do not derive tenant authorization from the first hostname label or expose an unrestricted `*/*` route without the intended zone context.

[WfP overview](https://developers.cloudflare.com/cloudflare-for-platforms/workers-for-platforms/) · [Isolation](https://developers.cloudflare.com/cloudflare-for-platforms/workers-for-platforms/reference/worker-isolation/) · [Starter example](https://github.com/cloudflare/workers-for-platforms-example)
