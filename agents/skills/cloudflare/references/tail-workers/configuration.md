# Tail Workers configuration

## Create and attach a consumer

Implement the handler from [api.md](api.md). Configure its `LOG_ENDPOINT` as a variable and `LOG_TOKEN` as a secret. Deploy the consumer before adding it to the producer's deployment:

```jsonc
{
  "name": "producer-worker",
  "tail_consumers": [{ "service": "logging-tail-worker" }]
}
```

This is a fragment of the producer's existing Wrangler configuration. Preserve its entrypoint, date, flags and bindings. An environment-specific producer must attach the intended consumer for that environment; do not accidentally export staging logs into production.

Several consumers can be listed; each attached consumer processes its own invocation. Remove an attachment using `"tail_consumers": []` and deploying that producer change. Existing external log retention is unaffected.

## Validation

1. Type-check the handler with generated Worker types and test its projections against HTTP and non-HTTP trace fixtures.
2. Test downstream HTTP failures, malformed inputs from test fixtures, large/truncated logs, and rejected delivery.
3. For authorized integration testing, deploy the consumer first, attach a staging producer, invoke it, and verify the destination receives the expected safe fields.
4. Verify the tail consumer's own errors and observability. `wrangler tail producer-worker` streams terminal logs; it does not prove a custom consumer delivered data.

Local handler tests do not establish production attachment, permissions, redaction behavior or delivery guarantees. Do not treat Tail Workers as durable audit storage without an explicit ingestion/retention design.

## Limits and billing

Tail Workers are available on Workers Paid and Enterprise and are billed by CPU time, not request count. Sampling in the handler can reduce downstream volume and processing, but it does not prevent the tail invocation. Retrieve current platform limits for the account rather than relying on a copied batch-size, consumer-count or request-size table.

A trace array can contain events from service bindings and dynamic dispatch. Do not assume exactly two records for every Workers for Platforms request. Identify producer identity using available fields such as `scriptName` and `dispatchNamespace`.

[Current guide](https://developers.cloudflare.com/workers/observability/logs/tail-workers/) · [Platform limits](https://developers.cloudflare.com/workers/platform/limits/)
