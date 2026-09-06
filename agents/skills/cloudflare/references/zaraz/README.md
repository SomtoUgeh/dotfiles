# Cloudflare Zaraz

Zaraz manages third-party integrations with much of their work performed at the
edge. It still loads client JavaScript and some integrations need browser-side
work. Measure performance; do not promise zero browser overhead.

Use Zaraz for supported analytics/marketing tools, event routing, and configured
consent purposes. Use a Worker or Managed Component when custom processing is
needed. Server-to-server events are also supported through the
[HTTP Events API](https://developers.cloudflare.com/zaraz/http-events-api/).

```javascript
// Run after Zaraz is loaded. Match this event name to the configured action.
zaraz.track('button_click', { button_id: 'cta' });
// Scope is explicit; the default scope would persist in localStorage.
zaraz.set('plan', 'premium', { scope: 'page' });
```

Configure the tool, firing trigger/action, and consent purpose before expecting
an event to reach the provider. Tool setup does not by itself establish privacy
or legal compliance; implement the product's chosen data and consent policy.

| Task | Reference |
| --- | --- |
| Tracking, data scope, consent methods | [api.md](./api.md) |
| Dashboard, SPA, loading, publication | [configuration.md](./configuration.md) |
| Identity, commerce, context enrichment | [patterns.md](./patterns.md) |
| Missing events or stale identity | [gotchas.md](./gotchas.md) |

Sources: [Zaraz](https://developers.cloudflare.com/zaraz/),
[Web API](https://developers.cloudflare.com/zaraz/web-api/).
