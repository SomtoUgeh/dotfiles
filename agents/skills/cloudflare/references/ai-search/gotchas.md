# AI Search Gotchas

- Current bindings use `AiSearchInstance` and `AiSearchNamespace`; legacy `Ai.autorag()` has different methods, filters, and response types. Migrate configuration, requests, and response consumers together.
- Run `wrangler types` after changes. Error interfaces in declarations are not necessarily runtime constructors; do not write `instanceof AutoRAGNotFoundError` unless an actual imported runtime class exists.
- A lower-bound comparison such as `$gte` is not a prefix test. Never remove tenant filters to debug a production request. Reproduce with controlled data and authorized scope.
- Custom metadata filters require matching indexed fields and value types. Confirm timestamp units in the actual indexed schema; JavaScript `Date.now()` is milliseconds.
- Retrieval can return empty results on backend failure by default. Set `return_on_failure: false` when failure must propagate, and handle errors separately from valid empty results.
- Namespace searches may contain per-instance `errors` alongside `chunks`; inspect both before claiming the complete search succeeded.
- Ingestion and indexing are asynchronous. Inspect `stats()`, item/job state, format support, and source permissions before lowering retrieval thresholds.
- The old tables claiming exactly ten instances, 4 MB files, and an immutable six-hour cycle are not a current universal contract. Check [current limits and configuration](https://developers.cloudflare.com/ai-search/) for the selected instance.

See [migration documentation](https://developers.cloudflare.com/ai-search/api/migration/workers-binding/), [configuration.md](configuration.md), and [api.md](api.md).
