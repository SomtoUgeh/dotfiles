# workerd APIs

Use Web APIs and the current [Workers runtime documentation](../workers/), noting that bindings need service implementations in standalone workerd. It does not provision Cloudflare products.

```javascript
export default {
  async fetch(request, env, ctx) {
    return env.API.fetch(request);
  },
  async scheduled(controller, env, ctx) {
    // Handler implementation; standalone workerd needs an event trigger.
  },
};
```

Custom RPC methods are exported through `WorkerEntrypoint`, not arbitrary methods on a plain default object:

```javascript
import { WorkerEntrypoint } from "cloudflare:workers";

export class GreetingService extends WorkerEntrypoint {
  greet(name) { return `Hello, ${name}`; }
}
```

Target `GreetingService` with the service binding's `entrypoint` field and call `env.GREETING.greet("Ada")`. Keep authentication/authorization in the real application; do not use a sample method that always returns a fabricated authenticated user.

TCP connections use `import { connect } from "cloudflare:sockets"`. Close sockets and release stream locks, bound reads, and handle errors. SSE responses need a managed stream producer that closes or aborts; leaving a writer open after one chunk leaves the response hanging.

For Node compatibility, use the current compatibility date/flags and consult the [support matrix](https://developers.cloudflare.com/workers/runtime-apis/nodejs/). `node:fs`, `node:http`, and `node:net` have supported subsets; a blanket “unavailable” list is obsolete. They do not imply unrestricted host filesystem or process access.

Generate types with `wrangler types` when a Wrangler config describes the application. Raw Cap'n Proto configurations need matching runtime types and explicit binding interfaces; Wrangler cannot infer bindings from a Cap'n Proto file. Transpile/bundle TypeScript before embedding it as JavaScript.

```bash
workerd serve config.capnp --socket-addr http=127.0.0.1:3000
workerd test config.capnp 'api:*'
workerd compile --config-only config.capnp > config.bin
```

A scheduled/queue handler export alone is not a scheduler or broker. Arrange the corresponding trigger/service through the embedding environment or use Wrangler's supported development tooling.
