# DDoS Gotchas

## Common Errors

### "False positives blocking legitimate traffic"

**Cause**: Sensitivity too high, wrong action, or missing exceptions
**Solution**:
1. Lower sensitivity for specific rule/category
2. Use `log` action first to validate (Enterprise Advanced)
3. Add exception with custom expression (e.g., allowlist IPs)
4. Query flagged requests via GraphQL Analytics API to identify patterns

### "Attacks getting through"

**Cause**: Sensitivity too low or wrong action
**Solution**: Increase to `default` sensitivity and use `block` action:
```typescript
const config = {
  rules: [{
    expression: "true",
    action: "execute",
    action_parameters: { id: managedRulesetId, overrides: { sensitivity_level: "default", action: "block" } },
  }],
};
```

### "Adaptive rules not working"

**Cause**: Insufficient traffic history (needs 7 days)
**Solution**: Wait for baseline to establish, check dashboard for adaptive rule status

### "Zone override ignored"

**Cause**: Account overrides conflict with zone overrides
**Solution**: Configure at zone level OR remove zone overrides to use account-level

### "Log action not available"

**Cause**: Not on Enterprise Advanced DDoS plan
**Solution**: Inspect the phase and supported actions. Verify against representative traffic in a bounded scope; do not substitute a browser challenge for observation on machine API or network traffic.

### "Rule limit exceeded"

**Cause**: Too many override rules (Free/Pro/Business: 1, Enterprise Advanced: 10)
**Solution**: Combine conditions in single expression using `and`/`or`

### "Cannot override rule"

**Cause**: Rule is read-only
**Solution**: Check API response for read-only indicator, use different rule

### "Cannot disable DDoS protection"

**Cause**: DDoS managed rulesets cannot be fully disabled (always-on protection)
**Solution**: Set `sensitivity_level: "eoff"` for minimal mitigation

### "Expression not allowed"

**Cause**: Custom expressions require Enterprise Advanced plan
**Solution**: Use `expression: "true"` for all traffic, or upgrade plan

### "Managed ruleset not found"

**Cause**: Zone/account doesn't have DDoS managed ruleset, or incorrect phase
**Solution**: Verify ruleset exists via `client.rulesets.list()`, check phase name (`ddos_l7` or `ddos_l4`)

## API Error Codes

| Error Code | Message | Cause | Solution |
|------------|---------|-------|----------|
| 10000 | Authentication error | Invalid/missing API token | Check token has DDoS permissions |
| 81000 | Ruleset validation failed | Invalid rule structure | Verify `action_parameters.id` is managed ruleset ID |
| 81020 | Expression not allowed | Custom expressions on wrong plan | Use `"true"` or upgrade to Enterprise Advanced |
| 81021 | Rule limit exceeded | Too many override rules | Reduce rules or upgrade (Enterprise Advanced: 10) |
| 81022 | Invalid sensitivity level | Wrong sensitivity value | Use: `default`, `medium`, `low`, `eoff` |
| 81023 | Invalid action | Wrong action for plan | Enterprise Advanced only: `log` action |

## Limits

| Resource/Limit | Free/Pro/Business | Enterprise | Enterprise Advanced |
|----------------|-------------------|------------|---------------------|
| Override rules per zone | 1 | 1 | 10 |
| Custom expressions | ✗ | ✗ | ✓ |
| Log action | ✗ | ✗ | ✓ |
| Adaptive DDoS | ✗ | ✓ | ✓ |
| Traffic history required | - | 7 days | 7 days |

## Tuning Strategy

Inspect the affected rule, traffic, phase, and plan before choosing an override. Use observation where supported and appropriate; determine its duration from representative legitimate and attack traffic, not a fixed waiting period. During an active incident, apply the authorized bounded mitigation and verify its effects. Managed Challenge is for compatible browser traffic, not a required stage for every protocol or API. Keep changes narrow and retain the prior configuration for recovery.

## Best Practices

- Test during low-traffic periods
- Use zone-level for per-site tuning
- Reference IP lists for easier management
- Set appropriate alert thresholds (avoid noise)
- Combine with WAF for layered defense
- Avoid over-tuning (keep config simple)

See [patterns.md](./patterns.md) for progressive rollout examples.

Ruleset phase PUT operations replace the entrypoint rules. Fetch the existing configuration, preserve unrelated rules using the current writable request schema, and review the complete resulting payload before applying it. Prefer a targeted rule update where available. Do not submit these fragments as a replacement for an existing production ruleset.
