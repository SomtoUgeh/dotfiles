# Cloudflare Tail Workers

Specialized Workers that consume execution events from producer Workers for logging, debugging, analytics, and observability.

## When to Use This Reference

- Implementing observability/logging for Cloudflare Workers
- Processing Worker execution events, logs, exceptions
- Building custom analytics or error tracking
- Configuring real-time event streaming
- Working with tail handlers or tail consumers

## Core Concepts

### What Are Tail Workers?

Tail Workers automatically process events from producer Workers (the Workers being monitored). They receive:
- HTTP request/response info
- Console logs (`console.log/error/warn/debug`)
- Uncaught exceptions
- Execution outcomes (`ok`, `exception`, `exceededCpu`, etc.)
- Diagnostic channel events

**Key characteristics:**
- Invoked AFTER producer finishes executing
- Events may include service-binding/dynamic-dispatch execution details; verify producer configuration and event coverage instead of assuming every subrequest is included.
- Billed by CPU time, not request count
- Available on Workers Paid and Enterprise tiers

### Alternative: OpenTelemetry Export

**Before using Tail Workers, consider OpenTelemetry:**

For batch exports to observability tools (Sentry, Grafana, Honeycomb):
- OTEL export sends logs/traces in batches (more efficient)
- Built-in integrations with popular platforms
- Compare supported destinations, event coverage, and measured overhead
- Tail Workers are useful when custom filtering, transformation, or delivery is needed.

## Decision Tree

```
Need observability for Workers?
├─ Batch export to known tools (Sentry/Grafana/Honeycomb)?
│  └─ Use OpenTelemetry export (not Tail Workers)
├─ Custom real-time processing needed?
│  ├─ Aggregated metrics?
│  │  └─ Use Tail Worker + Analytics Engine
│  ├─ Error tracking?
│  │  └─ Use Tail Worker + external service
│  ├─ Custom logging/debugging?
│  │  └─ Use Tail Worker + KV/HTTP endpoint
│  └─ Complex event processing?
│     └─ Use Tail Worker + Durable Objects
└─ Quick debugging?
   └─ Use `wrangler tail` (different from Tail Workers)
```

## Choose a Reference

Load the file that answers the current task; follow additional references only when needed.

- Setup, bindings, and deployment configuration → [configuration.md](configuration.md)
- API calls, handlers, and runtime behavior → [api.md](api.md)
- Implementing a specific integration or use case → [patterns.md](patterns.md)
- Diagnosing failures and checking relevant limits → [gotchas.md](gotchas.md)

## Quick Example

```typescript
export default {
  async tail(events, env, ctx) {
    // Send an allowlisted event summary; raw events may contain credentials/PII.
    ctx.waitUntil(
      fetch(env.LOG_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(events.map(event => ({ outcome: event.outcome, scriptName: event.scriptName }))),
      })
    );
  }
};
```

## Related Skills

- **observability** - General Workers observability patterns, OTEL export
- **analytics-engine** - Aggregated metrics storage for tail event data
- **durable-objects** - Stateful event processing, batching tail events
- **logpush** - Alternative for batch log export (non-real-time)
- **workers-for-platforms** - Dynamic dispatch with tail consumers
