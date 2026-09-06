# Argo Integration Patterns

## Argo and Tiered Cache

Argo optimizes origin-bound network paths; Tiered Cache reduces origin requests. They are separate settings. Measure latency and origin traffic rather than assuming fixed percentage improvements.

```typescript
async function readRoutingSettings(client: Cloudflare, zoneId: string) {
  const [argo, tiered] = await Promise.all([
    client.argo.smartRouting.get({ zone_id: zoneId }),
    client.argo.tieredCaching.get({ zone_id: zoneId }),
  ]);
  return { argo, tiered };
}
```

When authorized to change the settings, update each using its edit method, inspect all outcomes, and read both back. Parallel mutations are not atomic; one can succeed while the other fails. Account for partial success before retrying.

## Spectrum

Verify the Spectrum protocol and plan support separately. Updating an existing application requires the full current writable application payload with argo_smart_routing changed; a one-field PUT can fail or replace other settings. Fetch the app, map supported writable fields, and preserve its origin, protocol, DNS, and security settings. Use the [Spectrum API schema](https://developers.cloudflare.com/api/resources/spectrum/subresources/apps/).

## Verification and cost

Read back enablement and measure real traffic using [Argo Analytics](https://developers.cloudflare.com/argo-smart-routing/analytics/). A setting readback does not measure acceleration. Resolve the analytics dataset against the current schema; do not query an assumed argoBytes field. Compare the actual subscription and metered usage against measured benefits. There is no universal bandwidth threshold for profitability.
