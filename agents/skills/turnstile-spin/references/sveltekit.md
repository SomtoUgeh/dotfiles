# SvelteKit

Copy [verify-turnstile.ts](../templates/verify-turnstile.ts) to `src/lib/server/verify-turnstile.ts`. Use the project's existing server adapter, form fields, action, and business logic. Configure `TURNSTILE_SECRET` and `TURNSTILE_HOSTNAMES` in its server environment. Production hostnames must exclude local-development hosts.

The following Svelte 5 component uses explicit rendering, handles script reuse, and removes its widget when unmounted. Declare the browser API in the project's existing `src/app.d.ts`:

```ts
export {};
declare global {
  interface Window {
    turnstile?: {
      render(container: HTMLElement, options: {
        sitekey: string; action: string; callback(token: string): void;
        "expired-callback"(): void; "error-callback"(): void;
      }): string;
      reset(id: string): void;
      remove(id: string): void;
    };
  }
}
```

```svelte title="src/routes/signup/+page.svelte"
<script lang="ts">
  import { enhance } from "$app/forms";
  import { onMount } from "svelte";

  let { form } = $props<{ form: { error?: string; ok?: boolean } | null }>();
  let container: HTMLDivElement;
  let widgetId: string | undefined;
  let token = $state("");
  let pending = $state(false);

  onMount(() => {
    let active = true;
    const render = () => {
      if (!active || !window.turnstile || widgetId !== undefined) return;
      widgetId = window.turnstile.render(container, {
        sitekey: "YOUR_SITEKEY", action: "signup", callback: value => token = value,
        "expired-callback": () => token = "",
        "error-callback": () => token = "",
      });
    };
    let script = document.querySelector<HTMLScriptElement>('script[src^="https://challenges.cloudflare.com/turnstile/v0/api.js"]');
    if (window.turnstile) {
      render();
    } else {
      const needsScript = !script;
      script ??= document.createElement("script");
      script.addEventListener("load", render);
      if (needsScript) {
        script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
        script.async = true;
        document.head.appendChild(script);
      }
    }
    return () => {
      active = false;
      script?.removeEventListener("load", render);
      if (widgetId !== undefined) window.turnstile?.remove(widgetId);
      widgetId = undefined;
    };
  });
</script>

<form method="POST" use:enhance={({ cancel }) => {
  if (!token || pending) { cancel(); return; }
  pending = true;
  return async ({ result, update }) => {
    try { await update(); }
    finally {
      pending = false;
      token = "";
      if (result.type !== "redirect" && widgetId !== undefined) window.turnstile?.reset(widgetId);
    }
  };
}}>
  <input name="email" type="email" required />
  <div bind:this={container}></div>
  {#if form?.error}<p role="alert">{form.error}</p>{/if}
  <button type="submit" disabled={!token || pending}>Sign up</button>
</form>
```

## Form action

`use:enhance` works with a form action, not an arbitrary JSON endpoint. Preserve the existing action's validation and display its failure state in the existing UI.

```ts title="src/routes/signup/+page.server.ts"
import type { Actions } from "./$types";
import { fail } from "@sveltejs/kit";
import { env } from "$env/dynamic/private";
import { verifyTurnstile } from "$lib/server/verify-turnstile";

export const actions: Actions = {
  default: async ({ request }) => {
    let data: FormData;
    try { data = await request.formData(); }
    catch { return fail(400, { error: "Invalid form" }); }
    if (!await verifyTurnstile({
      token: data.get("cf-turnstile-response"), secret: env.TURNSTILE_SECRET,
      hostnames: env.TURNSTILE_HOSTNAMES, action: "signup",
    })) return fail(403, { error: "Verification failed" });
    // Existing signup logic uses the original data, including email.
    return { ok: true };
  },
};
```

## JSON endpoint variant

Use this only when the existing client already submits JSON. Retain its original fields and add the token; reset this surface's widget in `finally` after the request. Set `Content-Type: application/json`. Do not attach `use:enhance` to this endpoint.

```ts title="src/routes/api/signup/+server.ts"
import type { RequestHandler } from "./$types";
import { env } from "$env/dynamic/private";
import { verifyTurnstile } from "$lib/server/verify-turnstile";

export const POST: RequestHandler = async ({ request }) => {
  let body: unknown;
  try { body = await request.json(); }
  catch { return new Response("invalid JSON", { status: 400 }); }
  const token = typeof body === "object" && body !== null && "token" in body ? body.token : undefined;
  if (!await verifyTurnstile({ token, secret: env.TURNSTILE_SECRET,
    hostnames: env.TURNSTILE_HOSTNAMES, action: "signup" })) {
    return new Response("forbidden", { status: 403 });
  }
  // Existing signup logic validates and uses the remaining body fields.
  return Response.json({ ok: true });
};
```

The helper handles Siteverify HTTP, timeout, JSON, action, and hostname failures. Local mock tests cannot prove a live token works: validate an actual submission and replay rejection before reporting end-to-end completion.
