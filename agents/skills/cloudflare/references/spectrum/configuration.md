# Spectrum Configuration

## Public Origin

Terraform Cloudflare provider 5.x uses nested object attributes:

```hcl
resource "cloudflare_spectrum_application" "ssh" {
  zone_id = var.zone_id
  protocol = "tcp/22"
  dns = { type = "CNAME", name = "ssh.example.com" }
  origin_direct = ["tcp://192.0.2.1:22"]
  traffic_type = "direct"
  tls = "off"
  proxy_protocol = "off"
  ip_firewall = true
}
```

Replace the documentation IP with a reachable origin. DNS origins use `origin_dns = { name = "origin.example.com" }` and `origin_port = "22"`; use the provider's declared field type. Keep origin DNS unproxied for direct TCP origins to avoid an unsupported double-proxy path.

## Private Origins

Private addresses are not reachable merely because they appear in `origin_direct`. The [current configuration reference](https://developers.cloudflare.com/spectrum/reference/configuration-options/#virtual-network-origin) documents `virtual_network_id`: use an existing routed virtual network, one direct IP origin, one port, TCP/UDP, and `proxy_protocol = "off"`. Verify plan availability and configured routes. A raw `<tunnel-id>.cfargotunnel.com` hostname is not a valid arbitrary TCP origin. Private Network Load Balancing is another supported topology; see its current guide before configuring pools.

## TLS and Application Protocols

- `off` means TLS passthrough, not unencrypted application traffic. SSH/RDP and database/SMTP protocol encryption can still operate end-to-end.
- `flexible` terminates immediate TLS at the edge and forwards plaintext to origin.
- `full` uses TLS to origin without verifying its certificate.
- `strict` verifies origin TLS when immediate TLS termination is suitable.

Spectrum does not understand STARTTLS or upgrade protocol negotiation. Use passthrough for PostgreSQL SSL negotiation, MySQL negotiation, and SMTP STARTTLS unless you have a specifically designed TLS-wrapped service. Do not set `strict` blindly on ports 5432, 3306, or 587. Use application-native encryption and authentication.

## Client IP and Access Rules

Enable Proxy Protocol only when the immediate origin listener explicitly parses it. Stock OpenSSH does not parse a PROXY header. A compatible HAProxy/nginx front proxy can consume it before forwarding to SSH, but this does not magically expose the original IP to unmodified sshd.

`ip_firewall` applies supported IP Access rules (allow/block by IP, CIDR, ASN, or country). WAF custom rules do not inspect arbitrary Spectrum TCP/UDP traffic. Edge IPv4/IPv6 connectivity is independent of the origin address family; a dual-stack edge can proxy to an IPv4 origin.

## Port Ranges

The number of edge and origin ports must match. Direct origin example: `protocol = "tcp/1000-2000"`, `origin_direct = ["tcp://192.0.2.1:3000-4000"]`. For DNS origins use `origin_port = "3000-4000"`. Virtual-network direct origins do not support ranges.

For load balancing use a configured load balancer hostname as `origin_dns`; define account IDs, monitors, origin pools, default pools, and fallback pool with the current provider schema. A TCP health check only proves a listener accepts connections; database failover also requires primary-role correctness.

[API](api.md) · [Patterns](patterns.md) · [Troubleshooting](gotchas.md)
