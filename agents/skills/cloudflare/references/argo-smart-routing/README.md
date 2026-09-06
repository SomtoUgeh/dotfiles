# Cloudflare Argo Smart Routing Skill Reference

## Overview

Cloudflare Argo Smart Routing is a performance optimization service that detects real-time network issues and routes web traffic across the most efficient network path. It continuously monitors network conditions and intelligently routes traffic through the fastest, most reliable routes in Cloudflare's network.

Argo Smart Routing is now offered as part of Smart Shield. Check the target zone subscription and current API/provider version.

## Quick Start

### Enable via cURL
```bash
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/{zone_id}/argo/smart_routing" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value": "on"}'
```

### Enable via TypeScript SDK
```typescript
import Cloudflare from 'cloudflare';

const client = new Cloudflare({ apiToken: process.env.CLOUDFLARE_API_TOKEN });

const result = await client.argo.smartRouting.edit({
  zone_id: 'your-zone-id',
  value: 'on',
});

console.log(`Argo enabled: ${result.value}`);
```

## Core Concepts

### What It Does
- **Intelligent routing**: Detects congestion, outages, packet loss in real-time
- **Global optimization**: Routes traffic over the Cloudflare network
- **Route selection**: Responds to observed network conditions; no fixed failover time is guaranteed.
- **Works with existing setup**: No origin changes required

### Billing Model
- Usage-based: Charged per GB of traffic (excluding DDoS/WAF mitigated traffic)
- Requires billing configuration before enabling
- Available on eligible Argo/Smart Shield subscription plans (check zone eligibility)

### When to Use
- **High-traffic production sites** with global user base
- **Latency-sensitive applications** (APIs, real-time services)
- **Sites behind Cloudflare proxy** (orange-clouded DNS records)
- **Combined with Tiered Cache** for maximum performance gains

### Evaluate before enabling

Measure latency by visitor region, current origin load, and actual subscription costs. Traffic volume alone does not establish a break-even point; no universal 1 TB minimum applies.

## Reading Order by Task

| Your Goal | Start With | Then Read |
|-----------|------------|-----------|
| Enable Argo for first time | Quick Start above → [configuration.md](configuration.md) | [gotchas.md](gotchas.md) |
| Use TypeScript/Python SDK | [api.md](api.md) | [patterns.md](patterns.md) |
| Terraform/IaC setup | [configuration.md](configuration.md) | - |
| Enable for Spectrum TCP app | [patterns.md](patterns.md) → Spectrum section | [api.md](api.md) |
| Troubleshoot enablement issue | [gotchas.md](gotchas.md) | [api.md](api.md) |
| Manage billing/usage | [patterns.md](patterns.md) → Billing section | [gotchas.md](gotchas.md) |

## In This Reference

- **[api.md](api.md)** - API endpoints, SDK methods, error handling, Python/TypeScript examples
- **[configuration.md](configuration.md)** - Terraform setup, environment config, billing configuration
- **[patterns.md](patterns.md)** - Tiered Cache integration, Spectrum TCP apps, billing management, validation patterns
- **[gotchas.md](gotchas.md)** - Common errors, permission issues, limits, best practices

## See Also

- [Cloudflare Argo Smart Routing Docs](https://developers.cloudflare.com/argo-smart-routing/)
- [Cloudflare Smart Shield](https://developers.cloudflare.com/smart-shield/)
- [Spectrum Documentation](https://developers.cloudflare.com/spectrum/)
- [Tiered Cache](https://developers.cloudflare.com/cache/how-to/tiered-cache/)
