# Cloudflare Observability Skill Reference

**Purpose**: Comprehensive guidance for implementing observability in Cloudflare Workers, covering traces, logs, metrics, and analytics.

**Scope**: Cloudflare Observability features ONLY - Workers Logs, Traces, Analytics Engine, Logpush, Metrics & Analytics, and OpenTelemetry exports.

---

## Decision Tree: Which File to Load?

Use this to route to the correct file without loading all content:

```
├─ "How do I enable/configure X?"           → configuration.md
├─ "What's the API/method/binding for X?"   → api.md
├─ "How do I implement X pattern?"          → patterns.md
│   ├─ Usage tracking/billing               → patterns.md
│   ├─ Error tracking                       → patterns.md
│   ├─ Performance monitoring               → patterns.md
│   ├─ Multi-tenant tracking                → patterns.md
│   ├─ Tail Worker filtering                → patterns.md
│   └─ OpenTelemetry export                 → patterns.md
└─ "Why isn't X working?" / "Limits?"       → gotchas.md
```

## Reading Order

Load files in this order based on task:

| Task Type | Load Order | Reason |
|-----------|------------|--------|
| **Initial setup** | configuration.md → gotchas.md | Setup first, avoid pitfalls |
| **Implement feature** | patterns.md → api.md → gotchas.md | Pattern → API details → edge cases |
| **Debug issue** | gotchas.md → configuration.md | Common issues first |
| **Query data** | api.md → patterns.md | API syntax → query examples |

## Product Overview

### Workers Logs and Traces

Workers Logs stores searchable historical logs; it is distinct from a real-time tail session. As checked on 2026-09-05, the Free plan includes 200,000 events/day with 3-day retention; Paid includes 20 million/month with 7-day retention and $0.60/million additional events. Tracing is free during beta; current docs announce shared logs/traces event pricing from October 1, 2026. Recheck [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/) and [Tracing](https://developers.cloudflare.com/workers/observability/traces/) before estimates.

### Analytics Engine

High-cardinality sampled events queried through SQL. Retention is three months. Current [pricing](https://developers.cloudflare.com/analytics/analytics-engine/pricing/) lists future write/query rates but says usage is not yet billed; do not present those rates as current charges. Both Free and Paid allowances are documented.

### Tail Workers, Logpush and OpenTelemetry

Tail Workers process execution events for custom filtering/export. Workers Trace Events Logpush requires Workers Paid, rather than a Business/Enterprise zone plan. Prefer built-in [OpenTelemetry export](https://developers.cloudflare.com/workers/observability/exporting-opentelemetry-data/) when its destination support meets the need; use Tail Workers for custom processing.

## In This Reference

- **[configuration.md](configuration.md)** - Setup, deployment, configuration (Logs, Traces, Analytics Engine, Tail Workers, Logpush)
- **[api.md](api.md)** - API endpoints, methods, interfaces (GraphQL, SQL, bindings, types)
- **[patterns.md](patterns.md)** - Common patterns, use cases, examples (billing, monitoring, error tracking, exports)
- **[gotchas.md](gotchas.md)** - Troubleshooting, best practices, limitations (common errors, performance gotchas, pricing)

## See Also

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Analytics Engine Docs](https://developers.cloudflare.com/analytics/analytics-engine/)
- [Workers Traces Docs](https://developers.cloudflare.com/workers/observability/traces/)
- [GraphQL Analytics API Reference](../graphql-api/) - Query Workers metrics, HTTP analytics, and 70+ other datasets via GraphQL
