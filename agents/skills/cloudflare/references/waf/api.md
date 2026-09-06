# Rulesets API

Current Cloudflare TypeScript SDK uses positional ruleset IDs. Listing is paginated and does not accept a phase filter; filter returned objects locally.

```typescript
import Cloudflare from "cloudflare";

const client = new Cloudflare({ apiToken: process.env.CLOUDFLARE_API_TOKEN });
const zoneId = process.env.ZONE_ID;
if (!zoneId) throw new Error("ZONE_ID is required");
for await (const ruleset of client.rulesets.list({ zone_id: zoneId })) {
  if (ruleset.phase === "http_request_firewall_custom") {
    console.log(ruleset.id, ruleset.name);
  }
}
```

Use `client.rulesets.get(rulesetId, { zone_id: zoneId })` to inspect rules. For an existing phase entrypoint, prefer adding a single rule to replacing the full rules array:

```typescript
await client.rulesets.rules.create(rulesetId, {
  zone_id: zoneId,
  action: "managed_challenge",
  expression: 'starts_with(http.request.uri.path, "/admin/")',
  description: "Challenge the protected admin area",
  enabled: true,
});
```

Only create a zone entrypoint if that phase has none:

```typescript
await client.rulesets.create({
  zone_id: zoneId, kind: "zone", phase: "http_ratelimit",
  name: "API rate limits",
  rules: [{
    action: "block",
    expression: 'http.request.uri.path eq "/api/login" and http.request.method eq "POST"',
    ratelimit: {
      characteristics: ["cf.colo.id", "ip.src"],
      period: 60, requests_per_period: 10, mitigation_timeout: 600,
    },
    enabled: true,
  }],
});
```

`ratelimit` is a sibling of `action_parameters`, not nested inside it. Periods, mitigation times, characteristics, counting expressions, and actions depend on the plan. These example values must be checked against the target zone's entitlement.

For full replacement, use `client.rulesets.update(rulesetId, { zone_id: zoneId, ... })` with the complete intended rules and required ruleset fields. Preserve unrelated rules and IDs and protect against concurrent edits; a get-then-update sequence alone is not atomic. Delete uses `client.rulesets.delete(rulesetId, { zone_id: zoneId })`.

## Expression syntax

Use `starts_with(field, "prefix")` and `ends_with(field, "suffix")` as functions, not infix operators. `matches` is a plan-dependent regex operator. Header presence is an array/string expression, not `not <string>`; for example `not any(http.request.headers["authorization"][*] ne "")` tests absence of a nonempty value, not authentication.

[SDK/API](https://developers.cloudflare.com/api/resources/rulesets/) · [Rate-limit API](https://developers.cloudflare.com/waf/rate-limiting-rules/create-api/) · [Rules language](https://developers.cloudflare.com/ruleset-engine/rules-language/)
