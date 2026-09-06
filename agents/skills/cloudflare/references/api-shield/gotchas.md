# API Shield Troubleshooting

- JWT failure: verify configured header/cookie, key kid and alg, issuer, audience, expiry and not-before timestamps. Decode locally; do not paste live credentials into a third-party debugger. Use documented validator clock tolerance instead of assuming five minutes.
- Schema false positives: inspect the violation event and compare it with the actual supported OpenAPI schema, media type, and body inspection limits. Confirm the chosen action is active.
- Missing risk labels: check saved endpoints, session identifiers, entitlement, and actual scan results. Do not promise invented request thresholds or training deadlines.
- mTLS failure: verify hostname, certificate chain, expiry, revocation, and trust configuration. A valid certificate still needs application permission checks.
- GraphQL parsing: include parsed_successfully in structural rules, tune thresholds using legitimate traffic, and keep server-side validation.
- Migration gaps: preserve the prior policy until the replacement is configured and verified. CDN cache purges do not validate schema enforcement.

Quotas, schema features, token sources, and plan availability change. Resolve them from the [API Shield documentation](https://developers.cloudflare.com/api-shield/) for the target account; do not infer configuration success from a local syntax check.
