# Astro

Copy [verify-turnstile.ts](../templates/verify-turnstile.ts) to `src/lib/server/verify-turnstile.ts` before using the backend examples. Keep it server-only and preserve the handler's existing inputs and business logic. Configure the exact frontend hostnames for each deployment; production must exclude local-development hosts.

These native-page examples assume full-document navigation. If the project uses ClientRouter, preserve that routing choice and use the component lifecycle pattern below. For Astro projects. The widget renders in a page; siteverify lives in an Astro Action, an API route, or a Pages Function. Astro frontmatter reads the sitekey from env at build time; the secret stays server-only.

```astro title="src/pages/signup.astro"
---
const SITEKEY = import.meta.env.PUBLIC_TURNSTILE_SITEKEY;
---

<html>
	<head>
		<script is:inline
			src="https://challenges.cloudflare.com/turnstile/v0/api.js"
			async
			defer
		></script>
	</head>
	<body>
		<form action="/api/signup" method="POST">
			<input name="email" type="email" required />
			<div
				class="cf-turnstile"
				data-sitekey={SITEKEY}
				data-action="signup"
			/>
			<button type="submit">Sign up</button>
		</form>
	</body>
</html>
```

In your `.env`:

```text
PUBLIC_TURNSTILE_SITEKEY=YOUR_SITEKEY
TURNSTILE_SECRET=YOUR_SECRET
```

The `PUBLIC_` prefix is mandatory for client-exposed variables in Astro. The secret has **no** prefix; it stays server-only.

## API route (canonical siteverify)

This endpoint needs an installed deployment adapter and on-demand rendering. `prerender = false` prevents the route from becoming a static build artifact. See the [Astro rendering guide](https://docs.astro.build/en/guides/on-demand-rendering/).

```ts title="src/pages/api/signup.ts"
import type { APIRoute } from "astro";
import { verifyTurnstile } from "../../lib/server/verify-turnstile";
export const prerender = false;


export const POST: APIRoute = async ({ request }) => {
	let form: FormData;
	try { form = await request.formData(); } catch { return new Response("invalid form", { status: 400 }); }
	const token = form.get("cf-turnstile-response");
	if (typeof token !== "string") {
		return new Response("forbidden", { status: 403 });
	}

	if (!await verifyTurnstile({
		token, secret: import.meta.env.TURNSTILE_SECRET,
		hostnames: import.meta.env.TURNSTILE_HOSTNAMES, action: "signup",
	})) {
		return new Response("forbidden", { status: 403 });
	}

	// process signup
	return Response.json({ ok: true });
};
```

## Variant: Astro Actions

If the project uses Astro Actions, call siteverify from the action:

```ts title="src/actions/index.ts"
import { ActionError, defineAction } from "astro:actions";
import { z } from "astro/zod";
import { verifyTurnstile } from "../lib/server/verify-turnstile";


export const server = {
	signup: defineAction({
		accept: "form",
		input: z.object({
			email: z.email(),
			"cf-turnstile-response": z.string().min(1).max(2048),
		}),
		handler: async (input) => {
			if (!await verifyTurnstile({
				token: input["cf-turnstile-response"], secret: import.meta.env.TURNSTILE_SECRET,
				hostnames: import.meta.env.TURNSTILE_HOSTNAMES, action: "signup",
			})) {
				throw new ActionError({ code: "FORBIDDEN", message: "Verification failed" });
			}
			// process signup
		},
	}),
};
```

`signup` is the stable action for this surface. Preserve an existing custom migration action and compare the returned action to the same value. Siteverify is mandatory for every widget mode, including pre-clearance. Set `TURNSTILE_HOSTNAMES` to the deployment-specific frontend hostnames; a production value must not include `localhost` or `127.0.0.1`.

For a client-side Astro Action, replace the native form and script with an explicit widget. Retain this surface's widget ID and reset it in `finally` after every same-page request completion:

```astro
<turnstile-signup>
  <form>
    <input name="email" type="email" required />
    <div data-turnstile data-sitekey={SITEKEY}></div>
    <p role="alert" data-error></p>
    <button type="submit" disabled>Sign up</button>
  </form>
</turnstile-signup>
<script>
  import { actions } from "astro:actions";
  type TurnstileApi = {
    render(container: HTMLElement, options: {
      sitekey: string; action: string; callback(token: string): void;
      "expired-callback"(): void; "error-callback"(): void;
    }): string;
    reset(id: string): void;
    remove(id: string): void;
  };
  declare global { interface Window { turnstile?: TurnstileApi } }

  class TurnstileSignup extends HTMLElement {
    cleanup?: () => void;
    connectedCallback() {
      this.cleanup?.();
      const form = this.querySelector("form");
      const container = this.querySelector<HTMLElement>("[data-turnstile]");
      const button = this.querySelector("button");
      const error = this.querySelector<HTMLElement>("[data-error]");
      if (!form || !container?.dataset.sitekey || !button || !error) return;
      const sitekey = container.dataset.sitekey;
      let id: string | undefined;
      let token = "";
      let pending = false;
      const setToken = (value: string) => { token = value; button.disabled = pending || !token; };
      const renderWidget = () => {
        if (!this.isConnected || !window.turnstile || id !== undefined) return;
        id = window.turnstile.render(container, {
          sitekey, action: "signup", callback: setToken,
          "expired-callback": () => setToken(""), "error-callback": () => setToken(""),
        });
      };
      let script = document.querySelector<HTMLScriptElement>('script[src^="https://challenges.cloudflare.com/turnstile/v0/api.js"]');
      if (window.turnstile) renderWidget();
      else {
        const needsScript = !script;
        script ??= document.createElement("script");
        script.addEventListener("load", renderWidget);
        if (needsScript) {
          script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
          script.async = true;
          document.head.appendChild(script);
        }
      }
      const submit = async (event: SubmitEvent) => {
        event.preventDefault();
        if (pending || !token) return;
        pending = true;
        button.disabled = true;
        error.textContent = "";
        try {
          const result = await actions.signup(new FormData(form));
          if (result.error) throw result.error;
          // Continue the existing successful submission flow.
        } catch {
          error.textContent = "Submission failed. Please retry.";
        } finally {
          pending = false;
          setToken("");
          if (id !== undefined && this.isConnected) window.turnstile?.reset(id);
        }
      };
      form.addEventListener("submit", submit);
      this.cleanup = () => {
        script?.removeEventListener("load", renderWidget);
        form.removeEventListener("submit", submit);
        if (id !== undefined) window.turnstile?.remove(id);
        id = undefined;
      };
    }
    disconnectedCallback() { this.cleanup?.(); this.cleanup = undefined; }
  }
  if (!customElements.get("turnstile-signup")) customElements.define("turnstile-signup", TurnstileSignup);
</script>
```

## Substitutions

| Placeholder         | Replace with                                                         |
| ------------------- | -------------------------------------------------------------------- |
| `YOUR_SITEKEY`      | The widget site key from Step 8                                      |
| `YOUR_SECRET`       | The secret captured in Step 8. Stays in env, never inlined.          |
