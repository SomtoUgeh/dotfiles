# API Shield Patterns

## Progressive enforcement

Observe violations first where the plan supports logging. Compare representative valid traffic with rejected cases, then enable blocking on a bounded endpoint set. Keep application authorization checks active throughout. Browser challenges are generally inappropriate for machine API clients.

## GraphQL query protection

The fields below measure parsed query structure. query_size counts query fields; it is not a byte-size threshold. Choose limits from actual legitimate traffic and require successful parsing:

```wirefilter
(http.host eq "api.example.com" and
 cf.api_gateway.graphql.parsed_successfully and
 (cf.api_gateway.graphql.query_depth gt 10 or cf.api_gateway.graphql.query_size gt 100))
```

This custom rule may use a block action. It does not replace server-side complexity, authorization, and request-body limits. See [GraphQL protection](https://developers.cloudflare.com/api-shield/security/graphql-protection/api/).

## Rate limiting and sequences

Count a verified user identifier when the subscribed rate-limiting product supports that characteristic. A shared tier claim alone groups every user in that tier into one counter. Investigate sequence and volumetric abuse in the product analytics; do not invent cf.api_gateway.volumetric_abuse_detected or use a stale threat_score threshold as an API authorization policy.

## BOLA and authentication posture

Use endpoint risk labels to prioritize investigation. Test cross-user and cross-tenant access with authorized test accounts. Fix object-level checks at the origin. Schema validation, JWT signature validation, and risk labels each cover different failure modes; none guarantees prevention of the OWASP API Top 10 on its own.

For unknown endpoints, configure and test the documented fallthrough policy against the complete endpoint inventory, including health checks and preflight paths.
