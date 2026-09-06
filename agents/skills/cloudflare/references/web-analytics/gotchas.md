# Web Analytics troubleshooting

- **No data:** inspect the script request and POST beacon request, CSP/CORS errors, configured hostname, consent state, blockers, and eventual dashboard ingestion. Do not assume an exact five-minute SLA.
- **Automatic injection missing:** check proxied status, valid HTML, collection rules, and `Cache-Control: no-transform`. Manual installation may be appropriate without removing the header.
- **CSP blocks transmission:** script-src permits script loading; connect-src permits reporting. Automatic reporting uses same-origin `/cdn-cgi/rum`, manual reporting uses `cloudflareinsights.com`.
- **Duplicate pageviews:** keep exactly one beacon per document. Do not combine automatic injection, a framework plugin, and a manual snippet.
- **SPA navigation missing:** tracking is on by default. Check `spa: false`, browser API support, routing behavior, and delivery on navigation/page hide. Do not reload the beacon on each route.
- **405 from `/cdn-cgi/rum`:** the collection endpoint expects beacon POSTs. Do not build custom ingestion clients or health checks that treat a GET rejection as service failure.
- **API/report mismatch:** Web Analytics supports GraphQL aggregate queries. Discover the RUM dataset rather than substituting edge HTTP counts, and account for sampling and time windows.
- **Site limit reached:** current non-proxied limit is 10; proxied site count is unlimited, but dashboard aggregate selection caps at 1000 sites.
- **Consent withdrawn:** deleting a script tag alone cannot unload running code. Apply the application's consent lifecycle deliberately.

[Official FAQ](https://developers.cloudflare.com/web-analytics/faq/) · [Limits](https://developers.cloudflare.com/web-analytics/limits/)
