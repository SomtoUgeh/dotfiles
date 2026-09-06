# Vanilla HTML

Copy [verify-turnstile.ts](../templates/verify-turnstile.ts) to `the existing server library` before using the backend examples. Keep it server-only and preserve the handler's existing inputs and business logic. Configure the exact frontend hostnames for each deployment; production must exclude local-development hosts.

For static sites or any project without a JS framework. The widget renders client-side; the form submits to whatever backend handles your form (a Node/PHP/Ruby/Go server, a Cloudflare Worker, a Pages Function, a third-party form host that supports server-side hooks, etc.).

```html
<!doctype html>
<html>
	<head>
		<script
			src="https://challenges.cloudflare.com/turnstile/v0/api.js"
			async
			defer
		></script>
	</head>
	<body>
		<form action="/api/subscribe" method="POST">
			<input name="email" type="email" required />
			<div
				class="cf-turnstile"
				data-sitekey="YOUR_SITEKEY"
				data-action="subscribe"
			></div>
			<button type="submit">Subscribe</button>
		</form>
	</body>
</html>
```

When the form submits, the browser includes `cf-turnstile-response` automatically. Your backend reads it and calls canonical siteverify.

## Backend (any language)

Add this to your existing `/api/subscribe` handler before the rest of its logic:

```js
// Fragment inside the existing Node handler; import verifyTurnstile from your server library.
const expectedHostnames = new Set(
	(process.env.TURNSTILE_HOSTNAMES ?? '')
		.split(',')
		.map((h) => h.trim())
		.filter(Boolean),
);
if (expectedHostnames.size === 0) return res.status(403).end();

const token = req.body?.['cf-turnstile-response'];
if (!await verifyTurnstile({
	token: token, secret: process.env.TURNSTILE_SECRET,
	hostnames: process.env.TURNSTILE_HOSTNAMES, action: "subscribe",
})) {
	return res.status(403).json({ error: "Verification failed" });
}
// existing handler logic runs here
```

Equivalent calls in other backend languages (each also compares `result.hostname` to a `TURNSTILE_HOSTNAMES` allowlist):

```ruby
# Standalone Ruby verification helper; call from the existing server handler.
require 'net/http'
require 'uri'
require 'json'
require 'set'

def verify_turnstile(token)
  secret = ENV['TURNSTILE_SECRET']
  hosts = (ENV['TURNSTILE_HOSTNAMES'] || '').split(',').map(&:strip).reject(&:empty?).to_set
  return false unless token.is_a?(String) && token.length.between?(1, 2048)
  return false unless secret.is_a?(String) && !secret.strip.empty? && !hosts.empty?
  uri = URI('https://challenges.cloudflare.com/turnstile/v0/siteverify')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 5
  http.read_timeout = 10
  http.write_timeout = 10
  request = Net::HTTP::Post.new(uri)
  request.set_form_data(secret: secret, response: token)
  response = http.request(request)
  return false unless response.is_a?(Net::HTTPSuccess)
  result = JSON.parse(response.body)
  result.is_a?(Hash) && result['success'] == true && result['action'] == 'subscribe' && hosts.include?(result['hostname'])
rescue StandardError
  # This boundary fails closed for transport, timeout, and malformed responses.
  false
end
```

```python
# Standalone Python helper using requests; call from the existing handler.
import os
import requests

def verify_turnstile(token):
    secret = os.environ.get("TURNSTILE_SECRET", "")
    hosts = {h.strip() for h in os.environ.get("TURNSTILE_HOSTNAMES", "").split(",") if h.strip()}
    if not isinstance(token, str) or not 1 <= len(token) <= 2048 or not secret.strip() or not hosts:
        return False
    try:
        response = requests.post(
            "https://challenges.cloudflare.com/turnstile/v0/siteverify",
            data={"secret": secret, "response": token},
            timeout=(5, 10),
        )
        response.raise_for_status()
        result = response.json()
        return (isinstance(result, dict) and result.get("success") is True
                and result.get("action") == "subscribe" and result.get("hostname") in hosts)
    except (requests.RequestException, ValueError, TypeError):
        return False
```

Keep the existing handler's inputs, business validation, and response format.
Reject the request when verification returns false. Install `requests` through
the project's `uv` workflow only if it is not already present and this integration
is requested. Neither helper replaces auth, authorization, or rate limits.

`subscribe` is the stable action for this surface. Preserve an existing custom migration action and compare the returned action to the same value. Siteverify is mandatory for every widget mode, including pre-clearance. Set `TURNSTILE_HOSTNAMES` to the deployment-specific frontend hostnames; a production value must not include `localhost` or `127.0.0.1`.

## Variant: AJAX submit instead of form action

For an AJAX flow, replace the native form and API script with explicit rendering. Keep this surface's widget ID and reset it in `finally`, which covers network, JSON, validation, and server failures as well as successful same-page completion.

```html
<form id="subscribe-form">
	<input name="email" type="email" required />
	<div id="subscribe-turnstile"></div>
	<button type="submit" disabled>Subscribe</button>
	<p id="subscribe-status" role="status"></p>
</form>
<script>
	let subscribeWidgetId;
	let subscribeToken = "";
	let subscribePending = false;
	const subscribeForm = document.getElementById("subscribe-form");
	const subscribeButton = subscribeForm.querySelector('button[type="submit"]');
	const subscribeStatus = document.getElementById("subscribe-status");
	const updateSubscribeButton = () => {
		subscribeButton.disabled = subscribePending || !subscribeToken;
	};
	const clearSubscribeToken = () => {
		subscribeToken = "";
		updateSubscribeButton();
	};

	window.onSubscribeTurnstileLoad = () => {
		subscribeWidgetId = window.turnstile.render("#subscribe-turnstile", {
			sitekey: "YOUR_SITEKEY",
			action: "subscribe",
			callback: (token) => {
				subscribeToken = token;
				updateSubscribeButton();
			},
			"expired-callback": clearSubscribeToken,
			"error-callback": () => {
				clearSubscribeToken();
				subscribeStatus.textContent = "Verification failed. Please try again.";
			},
		});
	};

	subscribeForm.addEventListener("submit", async (event) => {
		event.preventDefault();
		if (subscribePending || !subscribeToken) return;
		subscribePending = true;
		updateSubscribeButton();
		subscribeStatus.textContent = "Submitting…";
		try {
			const res = await fetch("/api/subscribe", {
				method: "POST",
				body: new FormData(event.currentTarget),
			});
			const json = await res.json();
			if (!res.ok || json === null || typeof json !== "object" || json.ok !== true) {
				throw new Error("Submission failed");
			}
			subscribeStatus.textContent = "Subscribed.";
		} catch {
			subscribeStatus.textContent = "Submission failed. Please verify and try again.";
		} finally {
			subscribePending = false;
			clearSubscribeToken();
			if (subscribeWidgetId !== undefined) {
				window.turnstile.reset(subscribeWidgetId);
			}
		}
	});
</script>
<script
	src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onSubscribeTurnstileLoad&render=explicit"
	async
	defer
></script>
```

## No backend?

If there is no existing server handler, stop before creating a widget and report the missing backend. Selecting or deploying a new backend is a separate user decision. Do not add a Worker or proxy merely to complete this setup.

## Substitutions

| Placeholder         | Replace with                                                         |
| ------------------- | -------------------------------------------------------------------- |
| `YOUR_SITEKEY`      | The widget site key from Step 8                                      |
| `/api/subscribe`    | The path to your existing form-handling endpoint                     |
| `TURNSTILE_SECRET`  | Env-var name. Value is the secret captured in Step 8, kept off disk. |
