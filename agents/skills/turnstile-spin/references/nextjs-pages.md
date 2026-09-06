# Next.js (Pages Router)

Copy [verify-turnstile.ts](../templates/verify-turnstile.ts) to `lib/server/verify-turnstile.ts` before using the backend examples. Keep it server-only and preserve the handler's existing inputs and business logic. Configure the exact frontend hostnames for each deployment; production must exclude local-development hosts.

For older Next.js projects using `pages/` rather than `app/`. The widget renders client-side; siteverify lives in the API route.

```tsx title="pages/signup.tsx"
import Script from "next/script";
import { useCallback, useEffect, useRef, useState } from "react";

type TurnstileApi = {
  render: (container: HTMLElement, options: {
    sitekey: string; action: string; callback: (token: string) => void;
    "expired-callback": () => void; "error-callback": () => void;
  }) => string;
  reset: (id: string) => void;
  remove: (id: string) => void;
};
declare global { interface Window { turnstile?: TurnstileApi } }

export default function SignupPage() {
  const container = useRef<HTMLDivElement>(null);
  const widgetId = useRef<string | null>(null);
  const [token, setToken] = useState("");
  const renderWidget = useCallback(() => {
    if (!window.turnstile || !container.current || widgetId.current !== null) return;
    widgetId.current = window.turnstile.render(container.current, {
      sitekey: "YOUR_SITEKEY", action: "signup", callback: setToken,
      "expired-callback": () => setToken(""), "error-callback": () => setToken(""),
    });
  }, []);
  useEffect(() => {
    renderWidget();
    return () => {
      if (widgetId.current !== null) window.turnstile?.remove(widgetId.current);
      widgetId.current = null;
    };
  }, [renderWidget]);
  return <>
    <Script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit" onReady={renderWidget} />
    <form action="/api/signup" method="POST">
      <input name="email" type="email" required />
      <div ref={container} />
      <button type="submit" disabled={!token}>Sign up</button>
    </form>
  </>;
}
```

Explicit rendering supports client navigation and React development remounts. This native form navigates to the API response, so it does not need same-page reset code. If converting to AJAX, reset this widget after each attempt as in the App Router reference.

API route (canonical siteverify):

```ts title="pages/api/signup.ts"
import type { NextApiRequest, NextApiResponse } from "next";
import { verifyTurnstile } from "../../lib/server/verify-turnstile";

const expectedHostnames = new Set(
	(process.env.TURNSTILE_HOSTNAMES ?? "")
		.split(",")
		.map((h) => h.trim())
		.filter(Boolean),
);

export default async function handler(
	req: NextApiRequest,
	res: NextApiResponse,
) {
	if (req.method !== "POST") return res.status(405).end();
	const body: unknown = req.body;
	const token = typeof body === "object" && body !== null && "cf-turnstile-response" in body
		? body["cf-turnstile-response"] : undefined;
	if (expectedHostnames.size === 0) {
		return res.status(403).json({ error: "Verification failed" });
	}

	if (!await verifyTurnstile({
		token: token, secret: process.env.TURNSTILE_SECRET,
		hostnames: process.env.TURNSTILE_HOSTNAMES, action: "signup",
	})) {
		return res.status(403).json({ error: "Verification failed" });
	}
	// process signup
	return res.json({ ok: true });
}
```

`signup` is the stable action for this surface. Preserve an existing custom migration action and compare the returned action to the same value. Siteverify is mandatory for every widget mode, including pre-clearance. Set `TURNSTILE_HOSTNAMES` to the deployment-specific frontend hostnames; a production value must not include `localhost` or `127.0.0.1`.

## Substitutions

| Placeholder         | Replace with                                                         |
| ------------------- | -------------------------------------------------------------------- |
| `YOUR_SITEKEY`      | The widget site key from Step 8                                      |
| `TURNSTILE_SECRET`  | Env-var name. Value is the secret captured in Step 8, kept off disk. |
