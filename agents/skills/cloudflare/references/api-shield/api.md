# API Shield APIs

Endpoint inventory and discovery use the [API Gateway API](https://developers.cloudflare.com/api/resources/api_gateway/). Schema Validation uses its current schema validation API. JWT token configuration uses a separate base path, not api_gateway/token_validation.

## Token configuration

Create at POST /zones/{zone_id}/token_validation/config with this body shape. Load real issuer keys into credentials.keys before submission:

```json
{
  "title": "Production identity provider",
  "description": "Validate bearer tokens for this API",
  "token_sources": ["http.request.headers[\"authorization\"][0]"],
  "token_type": "jwt",
  "credentials": { "keys": [] }
}
```

An empty keys array is a placeholder, not a deployable configuration. Each JWK must use a supported algorithm and matching kid. Credentials rotate through PUT /zones/{zone_id}/token_validation/config/{config_id}/credentials; validate issuer response status and JWKS structure before replacing them. Confirm the returned result and messages.

Token validation rules use POST /zones/{zone_id}/token_validation/rules, with title, expression, selector, action (log or block), and enabled. Use the [current selector schema and examples](https://developers.cloudflare.com/api-shield/security/jwt-validation/api/).

## Rules language

In a token validation rule, the expression below requires a valid token; the configured action applies when the policy is NOT satisfied:

```wirefilter
is_jwt_valid("<TOKEN_CONFIGURATION_ID>")
```

is_jwt_valid and is_jwt_present are only supported in token validation rules, not WAF custom rules. Custom rules can access verified claims using:

```wirefilter
lookup_json_string(http.request.jwt.claims["<TOKEN_CONFIGURATION_ID>"][0], "sub")
```

These are Rules language fields, not Worker request.cf properties. A Worker must independently verify its JWT (including issuer and audience), or use a deliberately configured trusted Transform Rule and block every bypass of that trust boundary. Do not read a fabricated request.cf.jwt.payload property.

## mTLS in Workers

```typescript
function hasVerifiedClientCertificate(request: Request<unknown, IncomingRequestCfProperties>): boolean {
  return request.cf?.tlsClientAuth?.certVerified === "SUCCESS";
}
```

A verified chain identifies an accepted certificate; map it to a principal and permissions before returning protected data.

## Risk labels

cf-risk-bola-enumeration, cf-risk-bola-pollution, cf-risk-missing-auth, and cf-risk-mixed-auth are endpoint labels. They are not Boolean fields named cf.api_gateway.cf-risk-*. Inspect labeled endpoint traffic and repair authorization at the origin. Filtering by a label includes all traffic to labeled endpoints, not just suspicious requests. See [endpoint labels](https://developers.cloudflare.com/api-shield/management-and-monitoring/endpoint-labels/).
