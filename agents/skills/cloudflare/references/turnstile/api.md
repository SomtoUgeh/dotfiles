# Turnstile API boundaries

## Server verification

POST to `https://challenges.cloudflare.com/turnstile/v0/siteverify` with server-only `secret` and the submitted `response` token. Optional fields include `remoteip` and a UUID `idempotency_key` for retrying the same verification request.

Use the [shared verifier](../../../turnstile-spin/templates/verify-turnstile.ts) and [implementation workflow](../../../turnstile-spin/SKILL.md). Validate HTTP status and the JSON response, require `success: true`, and verify the expected hostname and action for this endpoint. Treat missing configuration, malformed responses, transport errors, token expiry, and duplicates as verification failures. Business operations happen only after verification succeeds.

Do not trust forwarded IP headers from arbitrary clients. Set `remoteip` only when the deployment's trusted proxy provides it. `cdata` is caller-controlled context, not authorization. Log error codes and internal correlation IDs rather than tokens, secrets, or complete verification bodies.

## Browser API

Load `https://challenges.cloudflare.com/turnstile/v0/api.js` directly. For explicit rendering, define the named onload callback before loading the async script with `?onload=callbackName&render=explicit`. Render only after that callback fires. Retain each widget ID for `getResponse`, `reset`, and `remove` operations; do not assume there is only one widget.

Use success, error, expiration, and timeout callbacks to update form state. Get a fresh token for each protected submission; reset consumed tokens on successful submissions as well as recoverable failures when the form remains mounted.

## Widget management

Account API tokens manage sitekeys and allowed hostnames; they are separate from Siteverify secrets. Discover existing widgets before creating one and preserve unrelated widget settings when updating. The shared skill's scripts implement this workflow.

[Siteverify contract](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/) · [Client rendering](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/)
