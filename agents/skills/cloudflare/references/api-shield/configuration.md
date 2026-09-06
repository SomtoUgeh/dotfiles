# API Shield Configuration

1. Inventory the API and configure session identifiers that represent users. Prefer a validated stable JWT subject; a caller-controlled X-User-ID header is not identity proof.
2. Import a supported OpenAPI schema through current Schema Validation. Review generated endpoints and select observation or enforcement actions deliberately.
3. Configure JWT verification keys and sources, then apply token rules to the intended saved operations. Explicitly decide missing-token behavior and exemptions for login, refresh, and browser OPTIONS requests.
4. Configure client certificates and mTLS policies for partner APIs where required. Test using a certificate issued by a CA trusted for the configured hostname; a newly self-signed certificate does not automatically authenticate.
5. Review events for valid requests, missing/expired/wrong-issuer tokens, schema violations, unknown endpoints, and unauthorized object access before broad enforcement.

## Existing schema migration

Export current schemas and policies, follow the [current schema validation migration instructions](https://developers.cloudflare.com/api-shield/security/schema-validation/), and verify replacement enforcement before retiring old rules. Do not delete every existing rule or clear the CDN cache based on an assumed five-minute propagation requirement.

## Key rotation

Fetch JWKS only from the configured issuer over HTTPS, check HTTP success, validate supported key fields, and preserve valid overlapping keys for in-flight tokens according to the issuer's rotation policy. A failed/empty download must not overwrite working keys. Keep API credentials server-side. See [Cloudflare's rotation Worker guide](https://developers.cloudflare.com/api-shield/security/jwt-validation/jwt-worker/).

For infrastructure as code, use the current [API Shield Terraform reference](https://developers.cloudflare.com/api-shield/reference/terraform/) and installed provider schema. Old cloudflare_api_shield blocks and generic WAF rules using is_jwt_valid are not interchangeable with token validation resources.
