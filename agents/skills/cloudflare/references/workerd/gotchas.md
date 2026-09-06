# workerd troubleshooting

- **Cap'n Proto syntax error:** use the installed workerd schema and `workerd compile --config-only config.capnp > config.bin` to parse the whole config. Ellipses, single-quoted JSON strings, invented `logging` fields, and `http = (style = tls)` are not valid substitutes for schema fields.
- **Binding works in Wrangler but not raw workerd:** product bindings need protocol services. Generic disk storage does not implement KV, and remote account credentials are not configured through fictional `remote` objects.
- **Unexpected outbound access:** global fetch exists and gets public Internet access by default. Constrain `internet`/`globalOutbound` deliberately.
- **DO storage path fails:** `durableObjectStorage.localDisk` names a disk service. The filesystem path belongs on that service. Namespace bindings use `(className = "Room")`, not a bare class string.
- **Module missing:** resolve import names against configured module names, and embedded source paths against the config file. Nested module paths are allowed.
- **Secret missing:** an unset `fromEnvironment` binding is null. Validate it, and do not log secret-bearing config or environment dumps.
- **Compatibility date rejected:** use a date no newer than the installed binary supports. It need not equal the release date.
- **Compile/test flag rejected:** compile writes stdout; test uses positional service/entrypoint filters. Inspect `workerd help compile` and `workerd help test`.
- **Lost DO data:** in-memory storage disappears at exit. Persistent storage is local to this runtime; it does not automatically replicate across processes or hosts.
- **Sandbox assumptions:** standalone workerd needs additional containment for potentially malicious code. A service binding does not eliminate every SSRF or runtime risk.

Start from a minimal complete config, reproduce locally, and check the [release schema](https://github.com/cloudflare/workerd/blob/main/src/workerd/server/workerd.capnp) before adding flags or capabilities.
