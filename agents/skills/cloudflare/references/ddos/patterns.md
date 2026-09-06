# DDoS Protection Patterns

## Tune an observed false positive

Find the event's managed rule and current entrypoint configuration. Verify supported overrides for that phase and account plan, narrow the traffic condition, and change the specific rule. Keep a copy of the prior configuration and verify both legitimate and attack traffic after the change. Do not disable an entire protection layer as a generic starting point.

## Layer protections

HTTP DDoS, managed WAF, custom WAF rules, rate limiting, and Bot Management run in distinct phases. Use each product's documented fields and actions; a Bot Management field is not automatically available in an earlier DDoS phase. See [phase order](https://developers.cloudflare.com/ruleset-engine/reference/phases-list/).

Use the current SDK at client.rulesets.phases.get(phase, scope) and client.rulesets.phases.update(phase, payload). A PUT replaces the rules array; merge and review existing writable rules rather than sending a one-rule fragment that removes other protection.

## Alert-driven response

Use authenticated, verified alert delivery with replay protection and a bounded response policy. An unauthenticated /attack-detected Worker endpoint must not change account security settings. KV eventual consistency cannot establish an exact attack count or safely authorize automatic lowering of protection.

## Cache eligible public content

Cache immutable public assets with complete response keys. Ignore a query parameter only after verifying it cannot alter the response. Never drop all query parameters from arbitrary /api/ responses or cache authenticated/user-specific data under a shared key. Retain authorization, cookies, and origin cache policy.

See [API](api.md), [configuration](configuration.md), and [gotchas](gotchas.md).
