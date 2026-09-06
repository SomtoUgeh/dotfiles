# Cloudflare Web Analytics

Web Analytics measures client-side visits, page views, and performance with a browser beacon. Core Web Vitals are LCP, INP, and CLS; TTFB is an additional diagnostic, and FID is a legacy metric.

Use automatic injection for eligible proxied sites, or install the dashboard snippet manually. SPA navigation measurement is enabled by default. Do not install both automatic and manual snippets on the same page.

Web Analytics supports programmatic aggregate access through the GraphQL Analytics API. Discover the available RUM datasets and fields for the account before constructing a query; HTTP edge analytics are a different data source. See [GraphQL reference](../graphql-api/) and the [official FAQ](https://developers.cloudflare.com/web-analytics/faq/).

| Task | Reference |
|---|---|
| Site, injection, CSP, token | [configuration.md](configuration.md) |
| Framework placement | [integration.md](integration.md) |
| Performance analysis and reporting | [patterns.md](patterns.md) |
| Missing data, duplicates, SPA behavior | [gotchas.md](gotchas.md) |

The beacon does not use cookies or fingerprinting for cross-site visitor tracking. This design does not by itself settle an application's legal obligations or consent policy. Avoid sensitive data in page paths and do not claim complete traffic coverage: blockers, failed delivery, and sampling affect results.

The current service allows 10 non-proxied sites and does not impose a proxied-site count limit. Dashboard aggregate viewing is limited to 1000 sites at once; query/select subsets for larger portfolios. Data is accessible for six months. Check [current limits](https://developers.cloudflare.com/web-analytics/limits/) before deployment.
