# Routing

Fetch https://developers.cloudflare.com/agents/api-reference/routing/ for complete documentation.

## Default URL Pattern

`/agents/{kebab-class-name}/{instance-name}`

```typescript
import { routeAgentRequest } from "agents";

export default {
  async fetch(req, env) {
    return (await routeAgentRequest(req, env)) ?? new Response("Not found", { status: 404 });
  }
};
```

| Class | URL |
|-------|-----|
| `Counter` | `/agents/counter/user-123` |
| `ChatRoom` | `/agents/chat-room/lobby` |
| `MyAgent` | `/agents/my-agent/default` |

Subpaths after the instance name (e.g. `/agents/my-agent/default/api/data`) route to `onRequest`.

## Custom Routing with `getAgentByName`

```typescript
import { getAgentByName, routeAgentRequest } from "agents";

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname.startsWith("/api/")) {
      const agent = await getAgentByName(env.MyAgent, "singleton");
      return agent.fetch(req);
    }
    return (await routeAgentRequest(req, env)) ?? new Response("Not found", { status: 404 });
  }
};
```

## Options

```typescript
await routeAgentRequest(req, env, {
  cors: true,
  prefix: "api/agents",
  locationHint: "enam",
  jurisdiction: "eu",
  props: { userId: "123" },
  onBeforeConnect: async (req) => { /* auth check */ },
  onBeforeRequest: async (req) => { /* auth check */ }
});
```

`props` are delivered to `onStart(props)` on first access. The server `prefix` has no leading slash.

## Client Side

```tsx
useAgent({
  agent: "MyAgent",
  name: "instance-1",
  host: "https://my-worker.workers.dev",
  basePath: "api/agents/my-agent/instance-1",
  path: "custom-subpath"
});
```

The client `basePath` replaces the complete default route, so include the class and instance. Keep `basePath` and `path` relative (no leading slash).

## Common Mistakes

- Class name `MyAgent` becomes kebab `my-agent` in URLs — match exactly
- "Namespace not found" error = the `class_name` in wrangler doesn't match your exported class
- If `sendIdentityOnConnect: false`, the `ready` promise on the client may never resolve — use state sync instead
