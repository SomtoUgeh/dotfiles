# R2 Data Catalog API Reference

Two APIs: the **control-plane REST API** (Cloudflare-specific) and the **Iceberg REST catalog API** (standard, used via PyIceberg/PySpark). For PyIceberg method details pull `https://py.iceberg.apache.org/`; for engine configs see `https://developers.cloudflare.com/r2-data-catalog/config-examples/`.

## Control-Plane REST API

Base: `https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/r2-catalog/{BUCKET}`
Auth: `Authorization: Bearer $API_TOKEN`

| Operation | Method | Path |
|-----------|--------|------|
| Get catalog details | GET | base URL |
| Enable / disable | POST | `/enable` · `/disable` |
| Store compaction credential | POST | `/credential` |
| List namespaces | GET | `/namespaces` |
| List tables | GET | `/namespaces/{ns}/tables` |
| Get/update maintenance config | GET/POST | `/maintenance-configs` and `/namespaces/{ns}/tables/{table}/maintenance-configs` |

List endpoints accept `?return_uuids=true`, `?return_details=true`, `?parent={ns}`, and pagination. **Nested namespaces use `%1F` (Unit Separator)**, not `/` or `.`: `/namespaces/parent%1Fchild/tables`.

```bash
# Catalog details (status, maintenance_config, credential_status)
curl -s "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/r2-catalog/$BUCKET" \
  -H "Authorization: Bearer $API_TOKEN"

# Store token for compaction (pure-API setups)
curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/r2-catalog/$BUCKET/credential" \
  -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" \
  -d '{"token": "'$API_TOKEN'"}'

# Update maintenance config (all fields optional; table-level overrides catalog-level)
curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/r2-catalog/$BUCKET/maintenance-configs" \
  -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" \
  -d '{"compaction": {"state": "enabled", "target_size_mb": "256"},
       "snapshot_expiration": {"state": "enabled", "min_snapshots_to_keep": 10, "max_snapshot_age": "7d"}}'
```

### Get Table (metadata introspection)

Load table metadata through the standard Iceberg catalog client: `table = catalog.load_table(("namespace", "table"))`. Inspect `table.schema()`, `table.spec()`, and `table.snapshots()`. Do not assume a control-plane response is a complete Iceberg snapshot history; use the current API schema before relying on undocumented fields.

### Error Format

```json
{"success": false, "errors": [{"code": 10000, "message": "Authentication error"}]}
```

Standard HTTP codes (401 auth, 403 perms, 404 not enabled/found, 409 conflict).

## Iceberg REST Catalog API (via PyIceberg)

Standard [Iceberg REST Catalog](https://github.com/apache/iceberg/blob/main/open-api/rest-catalog-open-api.yaml). Base: `https://catalog.cloudflarestorage.com/{ACCOUNT_ID}/{BUCKET}`. The `/config` route needs `?warehouse={WAREHOUSE}`.

```python
from pyiceberg.catalog.rest import RestCatalog
catalog = RestCatalog(name="r2", warehouse=WAREHOUSE, uri=CATALOG_URI, token=TOKEN)
```

Common operations (see PyIceberg docs for full signatures):

```python
catalog.create_namespace_if_not_exists("logs")
catalog.list_tables("logs")
table = catalog.create_table(("logs", "events"), schema=schema)   # pyiceberg.schema.Schema
table = catalog.load_table(("logs", "events"))
table.append(pyarrow_table)          # also .overwrite(...)
table.scan(row_filter="id > 100").to_pandas()
```

Schema evolution example (import LongType from pyiceberg.types):
```python
with table.update_schema() as u:
    u.add_column("user_id", LongType(), doc="User ID")
    u.rename_column("msg", "message")
```

Time-travel:
```python
snapshots = table.snapshots()
if len(snapshots) < 2:
    raise ValueError("No previous retained snapshot")
previous = snapshots[-2]
result = table.scan(snapshot_id=previous.snapshot_id).to_arrow()
# For a timestamp, resolve an applicable retained snapshot first;
# Table.scan does not accept as_of_timestamp.
```

## Manual Maintenance (PySpark)

Prefer automatic maintenance (control-plane API/wrangler). For manual control or very large tables, use Spark procedures (`rewrite_data_files`, `rewrite_manifests`, `expire_snapshots`, `remove_orphan_files`). See `https://developers.cloudflare.com/r2-data-catalog/table-maintenance/`.

```python
spark.sql("CALL r2dc.system.rewrite_data_files(table => 'ns.tbl')")
# Orphan removal REQUIRES S3 credentials (vended creds fail with NoAuthWithAWSException)
spark.sql("CALL r2dc.system.remove_orphan_files(table => 'ns.tbl', older_than => TIMESTAMP '2026-02-28 00:00:00')")
```

## See Also

- [configuration.md](configuration.md) · [patterns.md](patterns.md) · [gotchas.md](gotchas.md)
