# workerd runtime

`workerd` is the JavaScript/Wasm runtime underlying Workers. Use Wrangler for normal Worker development and deployment, Miniflare for programmatic local testing, and raw workerd for self-hosting or runtime integration.

The standalone runtime is not a hardened sandbox. Running potentially malicious code requires an appropriate additional security boundary, such as a VM; Cloudflare's hosted service supplies additional isolation layers. Capability bindings also require careful policy: public outbound networking is available by default.

```bash
workerd serve config.capnp
workerd test config.capnp
workerd compile config.capnp > app-server
chmod +x app-server
```

`compile` writes the binary to stdout; it does not accept `-o`. Test filtering uses service/entrypoint patterns, not `--test-only=test.js`.

Use the installed release's Cap'n Proto schema and CLI help. Its release date determines the newest compatibility date it supports; earlier dates remain valid. Pin and test the binary version and compatibility date separately.

| Topic | Reference |
|---|---|
| Services, sockets, bindings, storage | [configuration.md](configuration.md) |
| Handlers, RPC, runtime APIs | [api.md](api.md) |
| Tests, deployment, multi-service use | [patterns.md](patterns.md) |
| Syntax, networking, storage failures | [gotchas.md](gotchas.md) |

Upstream currently tests Linux and macOS on x86-64/arm64 and Windows on x86-64. Verify the specific release's OS dependencies rather than relying on an old beta/stable matrix.

[Upstream README](https://github.com/cloudflare/workerd/blob/main/README.md) · [Configuration schema](https://github.com/cloudflare/workerd/blob/main/src/workerd/server/workerd.capnp) · [Wrangler](../wrangler/) · [Miniflare](../miniflare/)
