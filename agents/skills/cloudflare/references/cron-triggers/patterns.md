# Cron Triggers Patterns

## API Data Sync

```typescript
export default {
  async scheduled(controller, env, ctx) {
    const response = await fetch("https://api.example.com/data", {headers: { "Authorization": `Bearer ${env.API_KEY}` }});
    if (!response.ok) throw new Error(`API error: ${response.status}`);
    ctx.waitUntil(env.MY_KV.put("cached_data", JSON.stringify(await response.json()), {expirationTtl: 3600}));
  },
};
```

## Database Cleanup

```typescript
export default {
  async scheduled(controller, env, ctx) {
    const result = await env.DB.prepare('DELETE FROM sessions WHERE expires_at < ?').bind(new Date().toISOString()).run();
    console.log(`Deleted ${result.meta.changes} expired sessions`);
    // Use supported D1 maintenance operations; VACUUM is not a portable D1 query.
  },
};
```

## Report Generation

```typescript
export default {
  async scheduled(controller, env, ctx) {
    const startOfWeek = new Date(); startOfWeek.setDate(startOfWeek.getDate() - 7);
    const { results } = await env.DB.prepare(`SELECT date, revenue, orders FROM daily_stats WHERE date >= ? ORDER BY date`).bind(startOfWeek.toISOString().slice(0, 10)).all<{ date: string; revenue: number; orders: number }>();
    const report = {period: "weekly", totalRevenue: results.reduce((sum, d) => sum + d.revenue, 0), totalOrders: results.reduce((sum, d) => sum + d.orders, 0), dailyBreakdown: results};
    const reportKey = `reports/weekly-${Date.now()}.json`;
    await env.REPORTS_BUCKET.put(reportKey, JSON.stringify(report));
    ctx.waitUntil(env.SEND_EMAIL.fetch("https://example.com/send", {method: "POST", body: JSON.stringify({to: "team@example.com", subject: "Weekly Report", reportUrl: `https://reports.example.com/${reportKey}`})}));
  },
};
```

## Health Checks

```typescript
export default {
  async scheduled(controller, env, ctx) {
    const services = [{name: "API", url: "https://api.example.com/health"}, {name: "CDN", url: "https://cdn.example.com/health"}];
    const checks = await Promise.all(services.map(async (service) => {
      const start = Date.now();
      try {
        const response = await fetch(service.url, { signal: AbortSignal.timeout(5000) });
        return {name: service.name, status: response.ok ? "up" : "down", responseTime: Date.now() - start};
      } catch (error) {
        return {name: service.name, status: "down", responseTime: Date.now() - start, error: error instanceof Error ? error.message : String(error)};
      }
    }));
    ctx.waitUntil(env.STATUS_KV.put("health_status", JSON.stringify(checks)));
    const failures = checks.filter(c => c.status === "down");
    if (failures.length > 0) ctx.waitUntil(fetch(env.ALERT_WEBHOOK, {method: "POST", body: JSON.stringify({text: `${failures.length} service(s) down: ${failures.map(f => f.name).join(", ")}`})}));
  },
};
```

## Queue integration

Use the producer binding to enqueue work, and a Queue consumer handler to process messages. The Worker Queue binding does not expose `receive()`. A concurrency-limited `Promise.allSettled` over a KV array is not a durable queue and can lose failed items.

```typescript
interface Env { JOBS: Queue<{ scheduledTime: number; cron: string }> }
export default {
  async scheduled(controller, env) {
    await env.JOBS.send({ scheduledTime: controller.scheduledTime, cron: controller.cron });
  }
} satisfies ExportedHandler<Env>;
```

Consumers must validate work, check HTTP responses, and acknowledge only successful processing. External pull consumers use the separate authenticated HTTP pull API.

## Monitoring & Observability

```typescript
export default {
  async scheduled(controller, env, ctx) {
    const startTime = Date.now();
    const meta = { cron: controller.cron, scheduledTime: controller.scheduledTime };
    console.log("[START]", meta);
    try {
      const result = await performTask(env);
      console.log("[SUCCESS]", { ...meta, duration: Date.now() - startTime, count: result.count });
      ctx.waitUntil(env.METRICS.put(`cron:${controller.scheduledTime}`, JSON.stringify({ ...meta, status: "success" }), { expirationTtl: 2592000 }));
    } catch (error) {
      console.error("[ERROR]", { ...meta, duration: Date.now() - startTime, error: error instanceof Error ? error.message : String(error) });
      ctx.waitUntil(fetch(env.ALERT_WEBHOOK, { method: "POST", body: JSON.stringify({ text: `Cron failed: ${controller.cron}`, error: error instanceof Error ? error.message : String(error) }) }));
      throw error;
    }
  },
};
```

**View logs:** `npx wrangler tail` or Dashboard → Workers & Pages → Worker → Logs

## Durable Objects Coordination

```typescript
export default {
  async scheduled(controller, env, ctx) {
    const stub = env.COORDINATOR.get(env.COORDINATOR.idFromName("cron-lock"));
    const acquired = await stub.tryAcquireLock(controller.scheduledTime);
    if (!acquired) {
      controller.noRetry();
      return;
    }
    try {
      await performTask(env);
    } finally {
      await stub.releaseLock();
    }
  },
};
```

## Python Handler

```python
from workers import WorkerEntrypoint

class Default(WorkerEntrypoint):
    async def scheduled(self, controller, env, ctx):
        data = await self.env.MY_KV.get("key")
        self.ctx.waitUntil(self.env.DB.prepare("DELETE FROM logs WHERE created_at < datetime('now', '-7 days')").run())
```

Python entrypoints access bindings and execution context through `self.env` and `self.ctx`. Keep the scheduled arguments for dispatch compatibility; the runtime can pass `None` for `env` and `ctx`.

## Testing Patterns

**Local testing with /cdn-cgi/local/scheduled:**
```bash
# Start dev server
npx wrangler dev

# Test specific cron
curl "http://localhost:8787/cdn-cgi/local/scheduled?cron=*/5+*+*+*+*"

# Test with specific time
curl "http://localhost:8787/cdn-cgi/local/scheduled?cron=0+2+*+*+*&time=1704067200000"
```

**Unit tests:** Use the Workers Vitest integration and its scheduled-controller/execution-context helpers. Test success, background rejection, duplicate scheduled times, and each schedule branch; await `waitOnExecutionContext(ctx)` before assertions.

## See Also

- [README.md](./README.md) - Overview
- [api.md](./api.md) - Handler implementation
- [gotchas.md](./gotchas.md) - Troubleshooting

Current source: [Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/). Local handler tests do not verify hosted scheduling, retries, or global propagation.
