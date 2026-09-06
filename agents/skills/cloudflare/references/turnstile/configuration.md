# Turnstile configuration

Use [turnstile-spin](../../../turnstile-spin/SKILL.md) for provisioning, deployment-specific secrets, and validation.

- Sitekeys are public; secrets remain on the server. Use separate production and development configuration and Cloudflare's documented test key pairs for automated tests.
- Allowed hostnames must match the application. Do not grant an arbitrary wildcard merely to make a local test pass.
- Managed, Non-interactive, and Invisible are widget modes. `size` accepts `normal`, `compact`, or `flexible`, not `invisible`. Normal size is 300×65 px and compact is 150×140 px; reserve layout space appropriately.
- `appearance` (`always`, `execute`, `interaction-only`) and `execution` (`render`, `execute`) are distinct controls. Invisible mode does not promise that automated browsers will always pass.
- Pre-clearance is a separate configuration that can issue a clearance cookie for eligible proxied sites. It does not remove the application's Siteverify requirement.
- Merge the official Turnstile requirements into the existing CSP, including script/frame access to `https://challenges.cloudflare.com`; use the documented nonce approach where appropriate. Do not replace the entire site policy with an example fragment.

For React, Vue, and Svelte, retain an existing maintained wrapper if it suits the project, then verify its installed exports and lifecycle API. Do not transplant an unverified default import or React component into another framework.

[Widget configuration](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/widget-configurations/) · [CSP](https://developers.cloudflare.com/turnstile/reference/content-security-policy/) · [Test keys](https://developers.cloudflare.com/turnstile/troubleshooting/testing/)
