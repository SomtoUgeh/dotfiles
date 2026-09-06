# Turnstile integration patterns

Use the canonical framework examples:

| Application | Reference |
|---|---|
| Next.js App Router | [nextjs-app.md](../../../turnstile-spin/references/nextjs-app.md) |
| Next.js Pages Router | [nextjs-pages.md](../../../turnstile-spin/references/nextjs-pages.md) |
| SvelteKit | [sveltekit.md](../../../turnstile-spin/references/sveltekit.md) |
| Astro | [astro.md](../../../turnstile-spin/references/astro.md) |
| HTML and server endpoints | [vanilla-html.md](../../../turnstile-spin/references/vanilla-html.md) |
| Hugo | [hugo.md](../../../turnstile-spin/references/hugo.md) |

Use the form's existing submission model. Preserve all business fields and CSRF protection when adding the token. JSON requests need the matching content type and server parser; form submissions should retain FormData semantics. Prevent duplicate in-flight submissions, show errors, and enable retry with a fresh token.

On SPA navigation, mount after the script is ready and remove the widget on unmount. Do not append duplicate script tags on every render. Reset on token expiry and after consumption if the form stays mounted. Verification failure must stop the protected operation and must not be silently swallowed.

A server endpoint still needs application authorization and business validation after Turnstile succeeds. Challenge completion establishes neither account identity nor ownership of the submitted resource.
