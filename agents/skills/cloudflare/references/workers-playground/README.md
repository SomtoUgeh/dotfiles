# Workers Playground

The [Playground](https://workers.cloudflare.com/playground) previews Workers
without an account. Production deployment requires authentication and a deployment
review. A successful preview is not a production readiness check.

Use JavaScript ES modules, with JSDoc for editor type information. For dependencies,
TypeScript builds, bindings, and secrets, prefer the project's Wrangler/Vite setup.
Do not put credentials, private code, or customer data in a shareable example.

```javascript
export default {
  fetch() {
    return Response.json({ message: 'Hello' });
  }
};
```

The preview offers browser and HTTP request panels plus a Worker log viewer.
Copy Link creates a shareable URL containing the example; official docs describe
these links as non-expiring. Treat the code as disclosed to anyone with the link.

Officially supported browsers are desktop Chrome and Firefox. The current docs
record Safari's `PreviewRequestFailed` issue; verify the current browser before
troubleshooting application code.

Read [configuration.md](./configuration.md), [api.md](./api.md),
[patterns.md](./patterns.md), and [gotchas.md](./gotchas.md).

Source: [Playground guide](https://developers.cloudflare.com/workers/playground/).
