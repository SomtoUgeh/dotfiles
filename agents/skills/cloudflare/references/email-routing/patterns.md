# Email Processing Patterns

Use authenticated routing configuration, verified destinations, and awaited operations for required delivery/storage. KV read-then-write is not an atomic rate limiter or deduplication lock. Use a Durable Object/atomic store when duplicates matter, and account for an uncertain send outcome before retrying. Avoid logging full message bodies or storing attachments under attacker-controlled filenames.

Use the maintained shared Email Service references for executable recipes and current API boundaries:

- [Email Service skill](../../../cloudflare-email-service/SKILL.md) — choose inbound routing, Worker sending, or REST.
- [Routing](../../../cloudflare-email-service/references/routing.md) — MIME parsing, forward/reject/reply, routing and storage.
- [Sending](../../../cloudflare-email-service/references/sending.md) — binding types and send results.
- [REST API](../../../cloudflare-email-service/references/rest-api.md) — account-scoped API and response interpretation.
- [CLI and development](../../../cloudflare-email-service/references/cli-and-mcp.md) — local tests and configured tools.
- [Deliverability](../../../cloudflare-email-service/references/deliverability.md) — authentication and DNS.

Verify MIME libraries against their installed types. Sending, forwarding, or replying successfully in local simulation does not prove real delivery. Await failures, check HTTP status for webhooks, and do not use waitUntil as a way to increase CPU budget.

For routing rule management beyond these recipes, consult the [Email Routing API](https://developers.cloudflare.com/api/resources/email_routing/) before constructing endpoints. Preserve the zone's actual provider-supplied DNS records rather than copying example MX hostnames.
