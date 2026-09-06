# Pipelines Gotchas

Non-obvious failure modes (not well covered by docs). For current limits and error semantics, pull `https://developers.cloudflare.com/pipelines/platform/limits/`.

## Events accepted but never appear (most common)

HTTP 200 / `send()` resolves, but no data in the sink. Causes:

1. **Schema validation failure** — structured streams accept then **silently drop** invalid events during processing. Validate client-side (Zod) and monitor `pipelinesUserErrorsAdaptiveGroups`.
2. **First-flush warm-up** — first data takes **several minutes (measure the actual pipeline)** (warm-up + namespace/table creation) even with `--roll-interval 10`. Use a bounded deadline and report timeout as incomplete.
3. **Roll interval not elapsed** — default 300s.
4. **Silent sink failure** — deleted bucket or expired token. Check `recordsWritten > 0` but `filesWritten = 0`; inspect `failure_reason` via `GET /pipelines/{id}`.

## Immutable schema and pipeline definitions

Stream HTTP enablement, authentication, and CORS can be updated. Schema changes require a new stream; check current management support for pipeline/sink changes before replacing resources. Use version naming (`events_v1`) and keep SQL in version control.

```bash
curl -X DELETE "$BASE_URL/pipelines/{id}" -H "Authorization: Bearer $API_TOKEN"
curl -X DELETE "$BASE_URL/sinks/{id}"     -H "Authorization: Bearer $API_TOKEN"
curl -X DELETE "$BASE_URL/streams/{id}"   -H "Authorization: Bearer $API_TOKEN"
```

## Worker binding undefined (`env.MY_STREAM`)

1. Use the **stream ID**, not pipeline ID, in `wrangler.jsonc`.
2. Binding field is `"stream"` (June 2026); old `"pipeline"` still works.
3. Redeploy after adding the binding.

## REST API field names ≠ CLI flags

`r2_data_catalog` vs `--type r2-data-catalog`, `table_name` vs `--table`, `token` vs `--catalog-token`, and `format` is required in REST but implied in CLI. See [configuration.md](configuration.md#option-c-rest-api-programmatic).

## `wrangler pipelines delete` defaults to "no"

Non-interactive environments answer "no" automatically — use the documented CLI/API only for an already authorized deletion; confirm data is drained first.

## Behavioral Notes

- **`__ingest_ts` auto-added** (TIMESTAMP, day-partitioned). Don't put it in your schema.
- **Sinks can't target existing tables** — the sink creates its own. Use PySpark to write to existing tables.
- **JSON-only input** — no Avro/Protobuf/CSV.
- **Naming:** streams/sinks/pipelines use underscores; buckets use hyphens.
- **Metrics lag 5–10 min** after creation.
- **Pipeline SQL is row-level only** — no GROUP BY/aggregation/window functions (do aggregation in [R2 SQL](../r2-sql/) at query time). CTEs and `UNNEST` are supported.

## Debug Checklist

- [ ] Stream exists: `wrangler pipelines streams list`
- [ ] Pipeline `running` (not `initializing`/`failed`): `GET /pipelines/{id}`, check `failure_reason`
- [ ] SQL matches schema; sink token valid; bucket + catalog exist
- [ ] Worker redeployed; binding uses **stream ID** under `"stream"`
- [ ] Waited ≥5 min (first flush)
- [ ] Sink metrics: `filesWritten > 0`; error metrics show no drops

## See Also

- [configuration.md](configuration.md) · [api.md](api.md) · [patterns.md](patterns.md)
