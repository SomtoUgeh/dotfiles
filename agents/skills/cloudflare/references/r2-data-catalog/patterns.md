# R2 Data Catalog Patterns

Code templates with PyIceberg (lightweight, no JVM) and PySpark (full Iceberg ecosystem). For per-engine config (DuckDB, Trino, Snowflake, StarRocks) and partitioning/maintenance best practices, pull `https://developers.cloudflare.com/r2-data-catalog/config-examples/` and `.../table-maintenance/`.

| Need | Tool |
|------|------|
| Catalog ops, append/scan, small-medium loads | PyIceberg |
| Batch ETL, INSERT INTO SELECT, DELETE/MERGE, write-back, >1 TB maintenance | PySpark |
| Pure SQL analytics (no writes) | [R2 SQL](../r2-sql/) |

## PyIceberg: Connect, Create, Load

```python
import os, pyarrow as pa
from pyiceberg.catalog.rest import RestCatalog

catalog = RestCatalog(
    name="r2",
    warehouse=os.environ["R2_WAREHOUSE"],   # {ACCOUNT_ID}_{BUCKET}
    uri=os.environ["R2_CATALOG_URI"],       # https://catalog.cloudflarestorage.com/{ACCOUNT_ID}/{BUCKET}
    token=os.environ["R2_TOKEN"],
)
catalog.create_namespace_if_not_exists("analytics")

schema = pa.schema([("id", pa.int64()), ("name", pa.string()), ("amount", pa.float64())])
table = catalog.create_table(("analytics", "events"), schema=schema)
table.append(pa.table({"id": [1, 2], "name": ["a", "b"], "amount": [80.0, 92.5]}))
print(table.scan().to_arrow().to_pandas())
```

## PyIceberg: Partitioned Time-Series Table

```python
from pyiceberg.schema import Schema
from pyiceberg.types import NestedField, TimestampType, StringType
from pyiceberg.partitioning import PartitionSpec, PartitionField
from pyiceberg.transforms import DayTransform

schema = Schema(
    NestedField(1, "timestamp", TimestampType(), required=True),
    NestedField(2, "level", StringType(), required=True),
    NestedField(3, "message", StringType(), required=False),
)
spec = PartitionSpec(PartitionField(source_id=1, field_id=1000, transform=DayTransform(), name="day"))
catalog.create_namespace_if_not_exists("logs")
table = catalog.create_table(("logs", "app_logs"), schema=schema, partition_spec=spec)
errors = table.scan(row_filter="level = 'ERROR' AND timestamp >= '2026-09-01T00:00:00'").to_pandas()
# The timestamp predicate enables pruning on the day partition.
```

## PySpark Session

Version-specific Spark 3.5/Scala 2.12 example using Iceberg 1.6.1. Match artifacts to your installed engine; 1.6.1 is not a service requirement. Cross-check current `config-examples/spark-python/`. This session uses vended credentials; configure a separate maintenance session with S3A credentials if orphan cleanup needs them.

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("R2DataCatalog") \
    .config('spark.jars.packages',
        'org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.6.1,'
        'org.apache.iceberg:iceberg-aws-bundle:1.6.1,'
        'org.apache.hadoop:hadoop-aws:3.3.4,'
        'com.amazonaws:aws-java-sdk-bundle:1.12.262') \
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.r2dc", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.r2dc.type", "rest") \
    .config("spark.sql.catalog.r2dc.uri", CATALOG_URI) \
    .config("spark.sql.catalog.r2dc.warehouse", WAREHOUSE) \
    .config("spark.sql.catalog.r2dc.token", TOKEN) \
    .config("spark.sql.catalog.r2dc.header.X-Iceberg-Access-Delegation", "vended-credentials") \
    .config("spark.sql.catalog.r2dc.s3.remote-signing-enabled", "false") \
    .config("spark.sql.defaultCatalog", "r2dc") \
    .getOrCreate()
spark.sql("USE r2dc")
```

> `X-Iceberg-Access-Delegation: vended-credentials` is required; `s3.remote-signing-enabled` must be `false`. First startup ~30–60s for JAR downloads (cached after).

## PySpark: Batch ETL

```python
spark.sql("CREATE NAMESPACE IF NOT EXISTS my_ns")
spark.sql("""
CREATE TABLE IF NOT EXISTS my_ns.events (
    __ingest_ts TIMESTAMP, event_id STRING, category STRING, amount DOUBLE
) PARTITIONED BY (days(__ingest_ts))
""")

# Parse CSV values using the destination schema instead of appending all strings.
spark.read.schema(spark.table("my_ns.events").schema).option("header", "true").csv("data.csv").writeTo("my_ns.events").append()
spark.read.parquet("data.parquet").writeTo("my_ns.events").append()
spark.sql("INSERT INTO my_ns.target SELECT col1, col2 FROM my_ns.source WHERE col1 > 0")
spark.sql("DELETE FROM my_ns.events WHERE amount < 0")
```

> Partition large tables (`PARTITIONED BY (days(__ingest_ts))`). Unpartitioned works for small datasets (<1000 files) but degrades at scale.

## Concurrent Writes with Retry (PyIceberg)

```python
from pyiceberg.exceptions import CommitFailedException
import time

def append_with_retry(table, data, max_retries=3):
    if max_retries < 1: raise ValueError("max_retries must be positive")
    for attempt in range(max_retries):
        try:
            table.append(data); return
        except CommitFailedException:
            if attempt == max_retries - 1: raise
            time.sleep(2 ** attempt)
            table.refresh()
```

Optimistic locking: concurrent commits to the same table may conflict; different-partition writes still update shared table metadata and may conflict. Retry only known failed commits; an uncertain network result needs reconciliation to avoid duplicate appends.

## Connecting Any Iceberg Engine

Engines connect with the Iceberg REST catalog config — Catalog URI `https://catalog.cloudflarestorage.com/{ACCOUNT_ID}/{BUCKET}`, warehouse `{ACCOUNT_ID}_{BUCKET}`, your token, and header `X-Iceberg-Access-Delegation: vended-credentials`. Copy-paste configs per engine: `config-examples/`.

## See Also

- [api.md](api.md) · [gotchas.md](gotchas.md) · [pipelines/patterns.md](../pipelines/patterns.md) · [r2-sql/patterns.md](../r2-sql/patterns.md)
