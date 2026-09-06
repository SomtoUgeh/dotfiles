# Cloudflare WAF

WAF custom rules, rate limiting, and managed rulesets protect eligible proxied zone traffic. Configure them through the dashboard, Rulesets API, or infrastructure provider. A Worker binding does not deploy WAF rules, and a workers.dev endpoint does not inherit a customer's zone configuration.

Within the security request phases, the relevant order is custom rules → rate limiting → managed rules → Super Bot Fight Mode. A terminating action prevents later phases from running; non-terminating actions can continue. Account rules run before zone rules within a phase.

Attack scores run from 1 (likely malicious) to 99 (likely clean), with 100 meaning unscored. An example mitigation expression is `cf.waf.score lt 20`, subject to plan availability and observed false positives. Blocking high scores reverses the intended policy. Business plans may expose attack-score class rather than the numeric Enterprise field.

| Task | Reference |
|---|---|
| SDK operations and rule shapes | [api.md](api.md) |
| Token and Terraform configuration | [configuration.md](configuration.md) |
| Managed rules, throttling, exceptions | [patterns.md](patterns.md) |
| Ordering, replacement, limits | [gotchas.md](gotchas.md) |

Discover the managed rulesets available to the account/zone. Cloudflare Managed and OWASP Core are distinct from the Free Managed Ruleset. The old Exposed Credentials Check managed ruleset is deprecated; use the current leaked credentials detection documentation for new integrations.

[WAF overview](https://developers.cloudflare.com/waf/) · [Attack score](https://developers.cloudflare.com/waf/detections/attack-score/) · [Execution order](https://developers.cloudflare.com/waf/feature-interoperability/)
