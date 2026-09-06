# Vectorize configuration

```bash
wrangler vectorize create documents --dimensions=768 --metric=cosine
wrangler vectorize create-metadata-index documents --property-name=category --type=string
wrangler vectorize create-metadata-index documents --property-name=updated --type=number
```

```jsonc
{
  "name": "document-search",
  "main": "src/index.ts",
  "compatibility_date": "2026-09-05",
  "ai": { "binding": "AI", "remote": true },
  "vectorize": [
    { "binding": "VECTORIZE", "index_name": "documents", "remote": true }
  ]
}
```

```bash
wrangler types
wrangler dev
```

Local Worker execution can connect to remote AI/Vectorize bindings; those calls use real account resources. Use mocks for offline tests. Declare bindings again for named environments instead of assuming inheritance.

For HTTP/CLI ingestion use valid NDJSON: one complete vector object per line, with exactly the index's number of numeric values. Ellipses are explanatory notation, never valid vectors. Keep generated files within the HTTP payload and vector-count limits. Inspect `wrangler vectorize --help` and the relevant subcommand help for the installed CLI before using ID-list or mutation options.

Index dimensions and metric are design choices, not query-time options. Build a new index and migrate/re-embed if they need to change. Create metadata indexes before ingestion and plan re-insertion of existing records when adding indexes.

[Wrangler commands](https://developers.cloudflare.com/vectorize/reference/wrangler-commands/) · [Bindings](https://developers.cloudflare.com/workers/local-development/bindings-per-env/)
