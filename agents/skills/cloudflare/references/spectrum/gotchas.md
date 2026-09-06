# Spectrum Gotchas

- **TCP test passes but app fails:** Spectrum can complete handshakes on an unconfigured edge port and then close them. `nc -zv` alone does not prove traffic reached the origin; test the actual protocol and origin logs.
- **Origin timeout:** verify the listener, routes, permitted Cloudflare traffic, and origin DNS. Spectrum supports CNAME and ADDRESS configurations; do not require every record to be CNAME.
- **Private origin unreachable:** configure the documented virtual-network or private-load-balancer topology; bare RFC1918 addresses and internal hostnames are insufficient.
- **Connection breaks after enabling PROXY:** the immediate listener must parse the chosen PROXY version. Stock sshd and many databases do not. Test passthrough first.
- **TLS fails on database/SMTP port:** native protocol negotiation is not immediate TLS. Use passthrough and enforce encryption in the application. `strict` is not universally required for every protocol.
- **Wrong TLS error diagnosis:** HTTP 525 applies to HTTP/HTTPS applications. Direct TCP origin TLS failure appears as an origin connection failure (521/522); inspect the corresponding event details.
- **Client IPv6 problem:** edge connectivity and origin IP family are independent. Do not disable IPv6 at the edge solely because origin is IPv4-only.
- **Firewall rule has no effect:** Spectrum uses supported IP Access allow/block rules; arbitrary WAF custom rules do not apply to raw TCP/UDP.
- **SMTP rejected:** evaluate source-IP, PTR, HELO/EHLO and MX alignment. Spectrum is not an intermediary mail server.
- **UDP loss:** fragmented UDP packets are dropped. Confirm payload size and current protocol support.

## Limits and Evidence

Consult [protocols per plan](https://developers.cloudflare.com/spectrum/protocols-per-plan/) and [limitations](https://developers.cloudflare.com/spectrum/reference/limitations/) for current availability. Do not assume 10–15 apps or 90+ days of analytics retention. Verify the account's actual entitlement and export events if longer retention is required.

Test a staging hostname using the real protocol, approved and denied client IPs, TLS verification, origin failure, PROXY parsing, and reconnect behavior. SDK/provider checks validate configuration shapes, not hosted routing or plan entitlements.

[API](api.md) · [Patterns](patterns.md) · [Configuration](configuration.md)
