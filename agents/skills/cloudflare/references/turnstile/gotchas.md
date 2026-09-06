# Turnstile troubleshooting

- **Always-failing tests:** pair documented test sitekeys with matching test secrets. Keep test keys out of production.
- **`timeout-or-duplicate`:** tokens expire after 300 seconds and are single-use. Reset the widget and obtain a new token for a new attempt. Use an idempotency key only to retry the same Siteverify request.
- **Widget API undefined:** wait for the loader callback. Register that callback before the async script and remove duplicate loaders.
- **Success callback but rejected operation:** inspect server verification status, expected hostname/action, and the application authorization result separately.
- **Layout shifts:** reserve the correct dimensions; compact is 150×140 px. Non-interactive is visible, while Invisible is a sitekey mode.
- **Missing token:** include `cf-turnstile-response` or the application's explicit token field with every protected request. Preserve the other form fields.
- **CSP failure:** check both script and frame directives and merge requirements into existing policy. Do not add broad `unsafe-inline` simply to silence an error.
- **Leaked context:** redact tokens and secrets; do not treat `cdata` as trusted metadata or take an arbitrary forwarded IP as the visitor address.

Use the shared [verification tests](../../../turnstile-spin/tests/siteverify.test.ts) and [framework references](patterns.md) to check success, malformed/upstream failure, wrong hostname/action, expired token, and retry behavior.
