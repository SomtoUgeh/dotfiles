# Vectorize gotchas

- **Dimension error:** every stored/query vector must match the index dimensions. Changing embedding models may require re-embedding into a new index.
- **Missing records after mutation:** mutations are asynchronous. Track processing and use bounded visibility checks; fixed sleeps are not proof of completion.
- **Missing metadata:** explicitly request `"all"` for fields outside metadata indexes. `"indexed"` is intentionally narrower.
- **Filter surprises:** filters run before top-K. Index the field with the right type and check nested dot notation, UTF-8 prefix behavior, and documented operators.
- **Tenant overwrite:** namespace is not a separate ID space. Use tenant-qualified IDs, and authorize all `getByIds`, delete, upsert, and backing-store operations.
- **Duplicate insert ignored:** use upsert when replacing an existing ID.
- **Partial ingestion:** preserve per-batch errors and mutation IDs and retry deliberately; do not silently truncate vectors or treat one accepted batch as full completion.

Limits checked against the current documentation; verify again when sizing a deployment:

| Resource | Limit |
|---|---|
| Dimensions | 1536 |
| Vectors per index | 20,000,000 |
| Vector ID | 64 bytes |
| Metadata per vector | 10 KiB |
| Metadata indexes per vector index | 10 |
| Query top-K, no values/metadata | 100 |
| Query top-K with values or metadata | 50 |
| Workers binding batch | 1000 vectors |
| HTTP batch | 5000 vectors, 100 MB payload ceiling |
| Namespaces per index | 1000 Free / 50,000 Paid |

[Current limits](https://developers.cloudflare.com/vectorize/platform/limits/) remains authoritative for plan quotas and changes.
