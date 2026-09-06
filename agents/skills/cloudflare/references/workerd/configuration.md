# workerd configuration

## Complete HTTP and service-binding example

`config.capnp`:

```capnp
using Workerd = import "/workerd/workerd.capnp";

const config :Workerd.Config = (
  services = [
    (name = "main", worker = (
      modules = [(name = "main.js", esModule = embed "main.js")],
      compatibilityDate = "2026-09-01",
      bindings = [
        (name = "API", service = "api"),
        (name = "CONFIG", json = "{\"region\":\"test\"}"),
        (name = "API_KEY", fromEnvironment = "APP_API_KEY")
      ]
    )),
    (name = "api", worker = (
      modules = [(name = "api.js", esModule = embed "api.js")],
      compatibilityDate = "2026-09-01"
    ))
  ],
  sockets = [
    (name = "http", address = "127.0.0.1:8080", http = (), service = "main")
  ]
);
```

`main.js`:

```javascript
export default {
  fetch(request, env) { return env.API.fetch(request); },
};
```

`api.js`:

```javascript
export default {
  fetch() { return new Response("API ready"); },
  async test() {
    const response = await this.fetch();
    if (await response.text() !== "API ready") throw new Error("Unexpected response");
  },
};
```

The first module is the entrypoint. Module names may contain paths; imports must resolve to those names, while `embed` paths resolve relative to the config. `fromEnvironment` is null when the variable is absent; validate required secrets before use. Compiled artifacts/config dumps may embed configuration data and must be handled accordingly.

## External HTTPS and network services

These are service entries to add to `services`, then reference through a service binding:

```capnp
(name = "backend", external = (
  address = "api.example.com:443",
  https = (tlsOptions = (trustBrowserCas = true), certificateHost = "api.example.com")
))
```

```capnp
(name = "internet", network = (
  allow = ["public"], tlsOptions = (trustBrowserCas = true)
))
```

Absent an explicit `internet` service, workerd creates one with public networking and uses it for global `fetch`. Override the service or the Worker's `globalOutbound` to constrain access. Network allow/deny lists describe IP ranges and documented classes, not arbitrary hostname allowlists. An external service always sends to its configured backend regardless of the request URL's host.

## Durable Objects

For a Worker exporting `Room`, add the following fields to its Worker configuration:

```capnp
bindings = [(name = "ROOMS", durableObjectNamespace = (className = "Room"))],
durableObjectNamespaces = [(className = "Room", uniqueKey = "example-room-v1")],
durableObjectStorage = (localDisk = "do-storage")
```

Add the named disk service:

```capnp
(name = "do-storage", disk = (path = "./state", writable = true))
```

`localDisk` refers to a **disk service name**, not a filesystem path. Create the directory and keep the namespace unique key stable. Use `inMemory = void` instead of localDisk only for disposable tests. Check the release's experimental requirements for persistent storage.

## Product bindings and remote resources

KV/R2/Queue bindings target services implementing their respective protocols. A generic disk service is not a KV implementation, and a PostgreSQL socket is not an HTTP service. Use Miniflare/Wrangler's supported simulation and remote-binding configuration rather than inventing raw Cap'n Proto `remote` objects or `.envVar()` calls.

Review advanced fields (inheritance, parameter bindings, memory caches, worker loaders, wrapped bindings, crypto keys, TLS sockets) against the installed schema and upstream samples. Inherited workers cannot independently change compatibility settings and may share an isolate. Do not copy incomplete schema fragments as standalone configs.
