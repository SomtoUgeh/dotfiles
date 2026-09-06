# Zaraz troubleshooting

| Symptom | Check |
| --- | --- |
| `zaraz` missing | Script injection/manual loader, blockers, CSP, execution timing |
| Event not routed | Event name, trigger match, tool action, consent purpose, credentials |
| Consent setter fails | `set` takes an object; `setAll` takes a boolean; use real purpose IDs |
| Consent listener never fires | Listen for `zarazConsentChoicesUpdated` on document |
| API used too early | Check `consent.APIReady` or wait for `zarazConsentAPIReady` |
| Debug mode does not open | Call `zaraz.debug(key)` with the dashboard key |
| Previous user's identity remains | `set` defaults to persistent storage; remove keys with undefined |
| Duplicate SPA events | Choose automatic SPA support or manual routing events |
| Context location is wrong | Use original supplied system context, not the enricher Worker's request metadata |
| Save unexpectedly goes live | Real-time is the default workflow; use Preview & Publish for staged review |

For consent testing, use the actual UI or documented API in an isolated test
browser. Do not guess a cookie name and delete production preferences. The
standard consent cookie is `cf_consent`, but administrators may customize it.

Inspect the browser request, Zaraz debug output, and the provider's diagnostics.
Awaiting `track` does not guarantee downstream attribution. Use current provider
limits and expected delivery timing rather than fixed universal payload/count
limits. Server-side tracking is supported by the HTTP Events API; Zaraz is not
an authentication service.

Sources: [Consent API](https://developers.cloudflare.com/zaraz/consent-management/api/),
[settings](https://developers.cloudflare.com/zaraz/reference/settings/),
[HTTP Events API](https://developers.cloudflare.com/zaraz/http-events-api/).
