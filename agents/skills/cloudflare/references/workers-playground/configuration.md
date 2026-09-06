# Playground configuration

Open the [Playground](https://workers.cloudflare.com/playground) and edit the
entry module. It uses the real Workers runtime but provides a limited preview
configuration; a `wrangler.toml` file in an example does not configure the preview.

## Editing and testing

- Use JavaScript ES modules and a fetch handler; add JSDoc when useful.
- Add relative modules through the editor's file support. Do not assume an npm
  package or remote CDN import will be resolved/bundled as in a local build.
- Use the browser preview for routes, and the HTTP panel for methods, headers,
  bodies, and response inspection.
- Inspect Worker `console.log` output in the preview's log viewer. Inspecting the
  surrounding webpage is not a replacement for Worker runtime logs.
- Preview Cache API calls have no effect; test caching with Wrangler or a scoped
  deployed test Worker. See [Cache API](https://developers.cloudflare.com/workers/runtime-apis/cache/).

## Sharing and deployment

Copy Link shares the code. Keep secrets and private data out of it. To deploy,
review the logged-in account, Worker name, code, bindings, routes, and intended
public URL. Deployment follows the user's existing authorization; experimenting
with an example alone does not authorize publishing it.

The destination account's plan and configuration control production limits. Do
not promise a 30-second deployment, automatic Free plan selection, or a particular
city count. Verify deployment and the resulting endpoint after publishing.

## When to use a local project

Use the project's installed Wrangler/Vite setup for dependencies, TypeScript,
bindings, secrets, runtime tests, and reproducible configuration. Wrangler accepts
JSON/JSONC or TOML configuration. Keep the project's selected compatibility date
unless intentionally testing an upgrade.

Source: [official Playground workflow](https://developers.cloudflare.com/workers/playground/).
