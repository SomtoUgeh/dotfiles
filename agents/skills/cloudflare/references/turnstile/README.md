# Cloudflare Turnstile

Turnstile produces a short-lived browser token that the application must verify on its server before accepting the protected operation. Tokens expire after 300 seconds and are single-use. A successful widget callback alone does not authorize a request.

For implementation, use the maintained [turnstile-spin skill](../../../turnstile-spin/SKILL.md), its [server verifier](../../../turnstile-spin/templates/verify-turnstile.ts), and the matching framework reference. This reference covers product configuration and API boundaries without a second copy of those implementations.

| Need | Read |
|---|---|
| Siteverify and token handling | [api.md](api.md) |
| Widget modes, keys, CSP | [configuration.md](configuration.md) |
| Framework integration | [patterns.md](patterns.md) |
| Errors and lifecycle | [gotchas.md](gotchas.md) |

Managed mode can show a checkbox; Non-interactive mode still displays a widget; Invisible mode hides it. Widget mode is configured for the sitekey. `appearance` controls when a visible widget appears, and `execution` controls when verification begins; neither is a substitute for widget mode.

[Official overview](https://developers.cloudflare.com/turnstile/) · [Widget types](https://developers.cloudflare.com/turnstile/concepts/widget/)
