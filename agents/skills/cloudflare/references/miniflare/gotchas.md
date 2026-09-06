# Miniflare troubleshooting

| Symptom | Check |
|---|---|
| `workers` is required | v5 constructor differs from v4; use the [current example](./README.md#quick-start-miniflare-5). |
| TypeScript syntax error | Compile first or run through Wrangler's harness. |
| Missing module | Manifest names, entrypoint, module type, and compiled imports must agree. |
| Port collision | Use `port: 0`; `dispatchFetch` does not remove the server. |
| Missing `request.cf` | Supply a deterministic `cf` fixture; `cf: true` may fetch data. |
| Missing binding | Check the selected Worker name and the installed version's descriptor schema. |
| Missing DO SQL | Configure a SQL-backed exported class, not only its namespace binding. |
| Tests hang | Close sockets/watchers and await cleanup in `finally`. |
| `getDurableObjectStorage` missing | This is not a Miniflare method; use the appropriate harness or Vitest storage helper. |

Match the target project's compatibility date. Upgrading all projects to a fixed date changes their runtime contract and does not diagnose a failure.

Local storage and placement differ from production. Network latency, account quotas, email delivery, remote products, and distributed consistency need separate integration checks. Inspect [supported development bindings](https://developers.cloudflare.com/workers/development-testing/bindings-per-env/) for the chosen mode instead of assuming universal support.

Do not promise unlimited memory or a configurable 30-second CPU limit via `scriptTimeout`; that option is absent. Measure the actual runtime and use production limits for capacity planning.

For existing v4 projects, retain their supported API until a migration is requested; the `latest` package tag can move to another major or prerelease. Check package versions before copying either old or new configuration.
