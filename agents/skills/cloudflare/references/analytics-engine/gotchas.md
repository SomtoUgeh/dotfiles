# Analytics Engine Gotchas

## Sampling

Sampling may occur at ingestion and query time. Each returned row's `_sample_interval` supplies its weight. Estimate event counts with `SUM(_sample_interval)`, metric totals with `SUM(double1 * _sample_interval)`, means with the weighted sum divided by total weight, and quantiles with `quantileExactWeighted(0.95)(double1, _sample_interval)`. A sampled estimate is not an exact accounting ledger.

Do not aggregate in module memory or flush when `Date.now() % 1000 === 0`: isolates can disappear, requests need not arrive on an exact millisecond, and the buffer is not durable. Use direct writes or a durable aggregation design.

## Writes

`writeDataPoint()` returns void. Input validation can throw synchronously, and successful return does not acknowledge durable ingestion. Validate dimensions and sizes; decide whether analytics failures should affect the user request. There is no general promise that all points below a fixed write rate are retained.

The limits are 20 blobs totaling 16 KB, 20 doubles, and one index of up to 96 bytes. Check [current limits](https://developers.cloudflare.com/analytics/analytics-engine/limits/) for other quotas.

## Queries and identity

A Worker can query the HTTP SQL API with a token stored in a secret. Authenticate the caller and enforce tenant scope server-side; do not accept arbitrary SQL or reveal the token. Use a non-secret customer ID as the sampling index, never a raw API key. The index can be filtered and grouped.

Always constrain time ranges and use weighted aggregates. Check dataset name, ingestion state, and source timestamps when results are empty. The service timestamp is assigned at write time; store an event timestamp separately if needed.

Sources: [sampling](https://developers.cloudflare.com/analytics/analytics-engine/sampling/), [SQL functions](https://developers.cloudflare.com/analytics/analytics-engine/sql-reference/aggregate-functions/).

Sampling reference: [Analytics Engine sampling](https://developers.cloudflare.com/analytics/analytics-engine/sampling/).
