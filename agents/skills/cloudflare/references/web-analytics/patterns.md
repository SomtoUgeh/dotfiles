# Web Analytics analysis patterns

## Investigate Core Web Vitals

Use the dashboard's metric dimensions and element diagnostics to identify affected routes, devices, and cohorts before changing code. LCP should be at most 2.5 seconds, INP at most 200 ms, and CLS at most 0.1 at the recommended percentile. Diagnose field data alongside a reproducible local trace.

- For LCP images, set dimensions and consider appropriate preload/fetch priority; avoid lazy-loading the measured hero.
- For CLS, reserve layout space for images, ads, and asynchronously loaded content.
- For INP, reduce long tasks and expensive synchronous work. Debouncing or yielding helps only when it addresses the measured cause.

## Reports and multiple sites

Use the GraphQL API for programmatic aggregate extraction. Discover account-accessible RUM dataset names, filters, retention windows, and sampling fields through the schema/settings. Bound time windows and paginate or partition according to the selected dataset. Check both HTTP errors and GraphQL `errors`; do not call an incomplete query a complete report.

Keep beacon pageviews distinct from edge HTTP requests. Cache hits, assets, bots, blockers, delivery losses, and navigation semantics make them different counts. Report the source, period, sampling, and known omissions; do not apply an invented fixed ad-blocker correction percentage.

## Product limitations

The FAQ currently states no custom event or UTM query-parameter tracking. Use another appropriate event source for funnels or user-level workflows. Web Analytics does support GraphQL access and notifications; do not reject an integration solely because an old reference called it dashboard-only.

[Data FAQ](https://developers.cloudflare.com/web-analytics/faq/) · [GraphQL discovery](https://developers.cloudflare.com/analytics/graphql-api/features/discovery/) · [Notifications](https://developers.cloudflare.com/web-analytics/get-started/notifications/)
