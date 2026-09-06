# Zaraz configuration

## Load and configure

1. Select the intended account and zone in Zaraz.
2. Verify script loading. Auto-injection is enabled by default; if disabled,
   follow [manual loading](https://developers.cloudflare.com/zaraz/advanced/load-zaraz-manually/).
3. Configure the chosen tool with its required identifiers/credentials.
4. Create a trigger matching the event name and attach it to the tool's action.
5. Map the tool to the product's configured consent purpose and test both choices.

A measurement ID is not interchangeable with a provider API secret. Never expose
server credentials in tracking payloads, shared examples, or browser code.

## SPA and pageviews

The **Single Page Application support** setting controls virtual pageviews on URL
changes. Use it with configured pageview actions, or intentionally disable the
automatic behavior and implement manual tracking. Do not enable both paths and
then emit another event on every router change. Test initial load, push/replace
navigation, browser back/forward, and the application's actual hash routing.

If **Automatic Pageview Tracking** is disabled, the documented built-in manual
trigger is `zaraz.track('Pageview')`. Custom event names remain application-defined
and must match their configured triggers.

## Consent and privacy

Create the needed purposes and record their generated IDs. Map tools/actions to
them; verify denied and granted behavior. Use the methods in [api.md](./api.md).
A consent modal is a UI mechanism, not an automatic compliance determination.

Review query-string removal, IP trimming, user-agent cleaning, referrer handling,
and cookie-domain settings. Do not assume anonymization is enabled without
checking the saved configuration.

## Publication and verification

The default **Real-time** workflow publishes changes immediately. Select
**Preview & Publish** when you need to review changes before publication. A
"Save" action in Real-time mode is therefore a production mutation.

Use the dashboard debug key with `zaraz.debug(key)`. Verify the outgoing event,
Zaraz trigger/action, consent decision, and provider reception separately. Disable
debug mode afterward. Observe the provider's current payload limits; do not
invent universal 100KB, 20-purpose, or 1000-request/second limits.

Source: [Zaraz settings](https://developers.cloudflare.com/zaraz/reference/settings/).
