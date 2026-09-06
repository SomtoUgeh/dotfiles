# WAF troubleshooting

- **Legitimate traffic blocked by scores:** lower WAF attack scores mean more suspicious traffic. `score gt 40` blocks cleaner traffic and includes unscored 100; review thresholds and plan-specific field availability.
- **Unexpected ordering:** custom rules run before rate limiting, then managed rules, then Super Bot Fight Mode. Non-terminating matches continue; “first match always wins” is incorrect.
- **Rules removed after update:** full ruleset replacement owns the whole list. Prefer a single-rule operation for a single-rule change and coordinate concurrent writers.
- **SDK rejects parameters:** ruleset IDs are positional, list does not accept `phase`, and rate-limit configuration belongs directly on the rule. See [api.md](api.md).
- **Expression parse error:** prefix/suffix operations are functions; do not apply Boolean `not` directly to a string. Quote string literals and check regex entitlement.
- **Skip did not bypass another phase:** `ruleset: "current"` is narrow. Phase skips affect only the explicitly named later phases and supported products. Bot Fight Mode is outside this system and cannot be skipped with custom rules.
- **NAT false positives:** distinguish per-IP/per-colo counters from global per-user quotas. Freely variable headers are not trusted user identities.
- **Managed overrides ignored:** inspect current rule/category IDs and precedence. Never copy unverified override IDs from another ruleset.
- **Log mode unavailable:** actions, numerical attack scores, regex, counts, periods, and rule quotas are plan-dependent. Read [current WAF availability](https://developers.cloudflare.com/waf/) and [rate-limit parameters](https://developers.cloudflare.com/waf/rate-limiting-rules/parameters/) instead of relying on a stale tier table.

Validate scope with representative traffic and review Security Events for actual matches. Do not weaken protection broadly for a speculative performance improvement.
