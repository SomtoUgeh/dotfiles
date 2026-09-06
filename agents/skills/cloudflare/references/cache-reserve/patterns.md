# Cache Reserve Patterns

## Public immutable assets

Serve genuinely public versioned assets from a dedicated path with correct origin Cache-Control, Content-Length, and validators. Use Cache Rules for eligibility before the origin fetch. Preserve the complete cache key. Never strip Set-Cookie or force public caching on an arbitrary response to make it eligible. Response rewriting after fetch does not retroactively change that fetch's Cache Reserve decision.

```typescript
const publicAssetRule = {
  action: "set_cache_settings",
  expression: '(http.host eq "assets.example.com" and starts_with(http.request.uri.path, "/immutable/"))',
  action_parameters: {
    cache: true,
    cache_reserve: { eligible: true, minimum_file_size: 0 },
  },
};
```

This rule assumes that the origin route serves only public immutable files. Preserve unrelated entrypoint rules when deploying it. Tiered Cache is recommended to reduce Cache Reserve operations; the Workers Cache API does not populate Cache Reserve.

## Cost estimate

Use actual storage and billable operation measurements plus the current contract rates. Estimate avoided origin egress relative to the existing edge/Tiered Cache baseline, not every read. Current published examples round each operation class up to the nearest million; confirm contract billing before relying on this estimate.

```typescript
interface ReserveEstimate {
  storageGBMonths: number;
  classAOperations: number;
  classBOperations: number;
  avoidedOriginGB: number;
  storageRate: number;
  classARatePerMillion: number;
  classBRatePerMillion: number;
  originEgressRate: number;
}
function estimateReserve(input: ReserveEstimate) {
  if (Object.values(input).some(value => !Number.isFinite(value) || value < 0)) {
    throw new RangeError("Estimates must be finite and nonnegative");
  }
  const reserveCost = input.storageGBMonths * input.storageRate
    + Math.ceil(input.classAOperations / 1_000_000) * input.classARatePerMillion
    + Math.ceil(input.classBOperations / 1_000_000) * input.classBRatePerMillion;
  const avoidedOriginCost = input.avoidedOriginGB * input.originEgressRate;
  return {
    reserveCost,
    avoidedOriginCost,
    savings: avoidedOriginCost - reserveCost,
    savingsPercent: avoidedOriginCost === 0 ? null : 100 * (avoidedOriginCost - reserveCost) / avoidedOriginCost,
  };
}
```

The estimate excludes subscriptions, taxes, and other origin charges. Check [pricing and eligibility](https://developers.cloudflare.com/cache/advanced-configuration/cache-reserve/) and verify real cost after rollout.
