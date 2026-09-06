# Web Analytics configuration

Add the site in the Web Analytics dashboard. For a proxied hostname, choose automatic injection, an available regional exclusion, manual installation, or disable collection according to the project's requirements. `Cache-Control: no-transform` prevents automatic modification; use manual installation when that header must remain.

For manual installation, use the snippet supplied for the site:

```html
<script type="module"
  src="https://static.cloudflareinsights.com/beacon.min.js"
  data-cf-beacon='{"token":"YOUR_SITE_TOKEN"}'></script>
```

The site token is public identification, not a server API secret. Hostname checks use the service's documented matching behavior; do not treat them as an authentication boundary. Keep staging and production collection separate or disable collection in non-production builds.

## CSP

Merge into the existing policy:

```text
script-src 'self' https://static.cloudflareinsights.com;
connect-src 'self' https://cloudflareinsights.com;
```

Automatic injection reports to the site's `/cdn-cgi/rum` endpoint (`connect-src 'self'`); manual installation reports to `cloudflareinsights.com`. Preserve other existing script/connect sources and nonce requirements. Do not hardcode an SRI hash for the unversioned manual beacon.

## Rules and data

Rules are available for proxied sites, with current limits Free 0, Pro 5, Business 20, Enterprise 100. Use the dashboard's supported hostname/path collection rules; do not invent a per-rule sample-rate field. Aggregate queries are sampled dynamically; the FAQ documents unsampled storage for seven days and lower-resolution long-term aggregates. These are different from beacon installation rules.

[Setup and CSP FAQ](https://developers.cloudflare.com/web-analytics/faq/) · [Current limits](https://developers.cloudflare.com/web-analytics/limits/)
