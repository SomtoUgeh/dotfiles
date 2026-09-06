# WAF patterns

## Managed protection

Read available managed rulesets and their rule/category IDs. Add an `execute` rule in the managed phase with the discovered ID. Cloudflare Managed uses `efb7b8c949ac4650a09736fc376e9aee`; OWASP Core uses `4814384a9e5d4991b9815dcfc25d2f1f`. Availability varies by plan.

```typescript
await client.rulesets.rules.create(managedEntrypointId, {
  zone_id: zoneId, action: "execute", expression: "true",
  action_parameters: { id: managedRulesetId },
  description: "Apply managed protection", enabled: true,
});
```

Tune false positives using a verified rule/category override with the smallest useful scope. Do not disable WordPress, SQLi, or other categories because an example happens to do so. OWASP anomaly scoring and WAF attack score are different systems; do not invert their thresholds.

## Attack score

Use `cf.waf.score lt 20` as an illustrative threshold only after reviewing account availability and actual false positives. Lower scores indicate attacks. Exclude unscored traffic deliberately when using broader conditions; `100` is not a clean classification.

## Rate limiting

Use the rule shape in [api.md](api.md). `cf.colo.id` plus `ip.src` counts per data center and source IP, not one globally serialized counter. Shared NATs can group legitimate users. Arbitrary cookies, Authorization values, and User-Agent strings are attacker-controlled and can defeat throttling if used as freely variable identity buckets. Use verified identity/plan-supported characteristics and retain a broader abuse limit where necessary.

A counting expression can differ from the mitigation expression. Check what counts, what is blocked, the period, and the mitigation duration as separate choices. Challenges require a compatible browser flow; API clients typically need a non-interactive response.

## Narrow exceptions

`action: "skip"` with `action_parameters: { ruleset: "current" }` skips only remaining rules in that ruleset. `phases: [...]` skips named later phases. The scope is not interchangeable. Keep exceptions tied to verified traffic conditions; a static-looking extension or attacker-controlled header is not a reason to bypass WAF.

[Skip options](https://developers.cloudflare.com/waf/custom-rules/skip/options/) · [Rate-limit parameters](https://developers.cloudflare.com/waf/rate-limiting-rules/parameters/)
