# workerd patterns

## Multi-service applications

Start with the complete two-service example in [configuration.md](configuration.md). Define bindings between named Workers and expose only the intended service through a socket. Use HTTP external services for HTTP backends, a suitable database client for PostgreSQL, and real protocol implementations for KV/R2 bindings.

For environment-specific configuration, use schema-supported parameter/inherited bindings or separate configuration files. Inherited Workers share code and compatibility settings; they are not a new isolation boundary.

## Test the actual service

```javascript
export default {
  async test(controller, env, ctx) {
    const response = await env.API.fetch("https://example.test/health");
    if (response.status !== 200) throw new Error(`Unexpected status ${response.status}`);
    if (await response.text() !== "API ready") throw new Error("Unexpected body");
  },
};
```

Include this module in a configured test Worker with an API service binding, then run `workerd test config.capnp 'tests:*'`. Merely listing a file as a module does not define a test; export a test handler. Use Miniflare or the Workers test pool when the project already uses that harness.

## Package and operate

```bash
workerd compile config.capnp > app-server
chmod +x app-server
./app-server
```

Build for the target OS/architecture. Compiling embeds configuration and modules, not arbitrary runtime disk contents or a distributed storage system. Keep writable storage outside the binary and back it up.

For containers, use a base image compatible with the chosen binary and run under an unprivileged user with only the required filesystem/network access. For systemd, `--socket-fd http=3` requires a matching socket unit; otherwise bind a regular configured address. Test startup, health, shutdown, persistence, and restart behavior.

Use framework builds targeting Workers and the installed framework's entrypoint API. Do not copy outdated `router.handle` examples into modern router versions. Export a standard fetch handler after bundling.

`ctx.waitUntil` extends an event lifetime for a promise; it is not a durable job queue. Use a proper queue/store when work must survive process termination.
