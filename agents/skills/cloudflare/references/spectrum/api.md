# Spectrum API

REST resources: `GET/POST /zones/{zone_id}/spectrum/apps`, then `GET/PUT/DELETE /zones/{zone_id}/spectrum/apps/{app_id}`. Updates use a complete configuration; they are not partial TLS patches.

## TypeScript SDK

Checked against `cloudflare` 7.1.0. Keep credentials server-side.

```typescript
import Cloudflare from 'cloudflare';
import type { AppCreateParams } from 'cloudflare/resources/spectrum/apps';
const client = new Cloudflare({ apiToken: process.env.CLOUDFLARE_API_TOKEN });
const config = {
  zone_id: zoneId,
  protocol: 'tcp/22',
  dns: { type: 'CNAME', name: 'ssh.example.com' },
  origin_direct: ['tcp://192.0.2.1:22'],
  traffic_type: 'direct',
  ip_firewall: true,
  proxy_protocol: 'off',
  tls: 'off',
} satisfies AppCreateParams;
const app = await client.spectrum.apps.create(config);
const details = await client.spectrum.apps.get(app.id, { zone_id: zoneId });
await client.spectrum.apps.update(app.id, config);
for await (const existing of client.spectrum.apps.list({ zone_id: zoneId })) console.log(existing.id);
// When intentionally removing the application:
await client.spectrum.apps.delete(app.id, { zone_id: zoneId });
```

`origin_direct` contains IP-based origin URLs. For a resolvable hostname use `origin_dns: {name}` and `origin_port`. A port range is a string like `"3000-4000"`, not `{start,end}`. Static edge IP and virtual network configurations have additional constraints; use the generated SDK types and current [configuration reference](https://developers.cloudflare.com/spectrum/reference/configuration-options/).

## Analytics

```typescript
const analytics = await client.spectrum.analytics.events.summaries.get({
  zone_id: zoneId,
  metrics: ['bytesIngress', 'bytesEgress', 'durationAvg'],
  dimensions: ['appID'],
  since: new Date(Date.now() - 3600000).toISOString(),
});
```

Event summary metrics include `count` (events), byte totals, and `durationAvg`/`durationMedian`/percentiles in milliseconds. Do not treat event count as unique connections without an appropriate event filter. Aggregate-current and event-summary endpoints have different schemas.

Use current official SDK documentation for Python/Go rather than translating old Go v0 functions or passing every path parameter inside a JavaScript object.

[Configuration](configuration.md) · [Patterns](patterns.md) · [Troubleshooting](gotchas.md)
