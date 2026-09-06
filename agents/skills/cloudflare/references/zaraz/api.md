# Zaraz Web API

## Tracking and data scope

```javascript
await zaraz.track('button_click', { button_id: 'cta', value: 1 });
zaraz.set('plan', 'premium', { scope: 'page' });
zaraz.set('plan', undefined); // Removes this key from all scopes.
```

`track(eventName, properties?)` is asynchronous and can be awaited. Use a flat
properties object and configure a matching trigger/action. Completion of the
call is not evidence that a third-party provider accepted the event.

`set(key, value, options?)` takes a key/value pair, not an object of pairs.
Scope is `page`, `session`, or `persist`; `persist` is the default and uses
localStorage. Set every identity field to `undefined` when it must be cleared.

Sources: [track](https://developers.cloudflare.com/zaraz/web-api/track/),
[set](https://developers.cloudflare.com/zaraz/web-api/set/).

## E-commerce

```javascript
zaraz.ecommerce('Order Completed', {
  order_id: 'ORD-789', total: 99.98, currency: 'USD',
  products: [{ product_id: 'SKU123', name: 'Widget', quantity: 2, price: 49.99 }],
});
```

Enable e-commerce in Zaraz settings and each supported tool. Follow that tool's
payload limits and required fields. This maps supported commerce events; it does
not make arbitrary events compatible with every tool.
See [commerce event definitions](https://developers.cloudflare.com/zaraz/web-api/ecommerce/).

## Consent

Use the configured purpose IDs, not assumed names such as `marketing`. Apply
choices only in response to the actual user's consent selection.

```javascript
// Call from the application's consent UI after the API is ready.
function applyPurposeChoice(purposeId, allowed) {
  if (!zaraz.consent?.APIReady) return false;
  zaraz.consent.set({ [purposeId]: allowed });
  return true;
}

function showConsentModal() {
  if (zaraz.consent?.APIReady) zaraz.consent.modal = true;
  else document.addEventListener('zarazConsentAPIReady', () => {
    zaraz.consent.modal = true;
  }, { once: true });
}

document.addEventListener('zarazConsentChoicesUpdated', () => {
  const choices = zaraz.consent.getAll();
  // Synchronize the application's consent UI from choices.
});
```

| Method/property | Contract |
| --- | --- |
| `get(id)` | Boolean choice, or undefined for an unknown purpose |
| `getAll()` | Object keyed by configured purpose ID |
| `set({ [id]: boolean })` | Set selected purposes |
| `setAll(boolean)` | Set every purpose to the same choice |
| `purposes` | Read-only configured purpose metadata |
| `APIReady` | Readiness flag |
| `modal` | Read/write visibility |

Events are dispatched on `document`; there is no consent object's
`addEventListener('consentChanged', ...)` API. For checkbox and queued pageview
methods, follow the [Consent API](https://developers.cloudflare.com/zaraz/consent-management/api/).

## Debug and context

```javascript
zaraz.debug('YOUR_DEBUG_KEY'); // Dashboard debug key; developer console only.
zaraz.debug(); // Disable debug mode.
```

`debug` is a function, not a boolean. Do not rely on undocumented `zaraz.tools`,
`getCookie`, or `readCookie` methods. Read configured context variables through
the dashboard: event properties use `{{ client.value }}`, cookies use
`system.cookies`, and user agent fields live under `system.device.user-agent`.

Sources: [debug](https://developers.cloudflare.com/zaraz/web-api/debug-mode/),
[context](https://developers.cloudflare.com/zaraz/reference/context/).
