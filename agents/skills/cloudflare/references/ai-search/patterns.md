# AI Search Patterns

## Tenant isolation

Authenticate the request, authorize access, then choose the instance from server-owned tenant configuration. A tenant name supplied directly by the client must never select an arbitrary namespace instance.

```typescript
async function searchAuthorizedInstance(
  namespace: AiSearchNamespace,
  authorizedInstanceName: string,
  query: string
) {
  // The caller resolves this name from the authenticated tenant's stored configuration.
  return namespace.get(authorizedInstanceName).search({
    messages: [{ role: "user", content: query }],
    ai_search_options: { retrieval: { return_on_failure: false } }
  });
}
```

For shared instances, index a tenant metadata field and enforce exact equality server-side on every search and generation request. Test with a known document from another tenant. `folder >= "tenants/a/"` also matches later tenants lexicographically and must not be used for isolation. Cache keys must include tenant identity and all retrieval constraints.

## Retrieval quality

Evaluate a representative query set with known relevant and irrelevant documents. Tune `retrieval.match_threshold`, `max_num_results`, query rewriting, and reranking against measured recall, latency, and cost. Fixed thresholds and latency estimates are not universal guarantees.

Use `return_on_failure: false` where a retrieval outage must be distinguishable from no results. Empty context should result in an explicit no-answer path; instructions in retrieved documents are untrusted content.

## Streaming

Use `chatCompletions({ messages, stream: true })` and return its stream directly as `text/event-stream`; see [api.md](api.md). Do not buffer the stream into JSON or read `response` from it.

## Freshness

Track item/job completion and compare returned item metadata with source revisions. Synchronization cadence and ingestion completion are different from query latency. Use [current item and indexing APIs](https://developers.cloudflare.com/ai-search/) when the application needs to upload or refresh content.
