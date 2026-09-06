# Spectrum Protocol Patterns

Choose the protocol's actual handshake and origin reachability before configuring Spectrum.

| Protocol | Edge protocol | TLS setting | Origin considerations |
|---|---|---|---|
| SSH | `tcp/22` | `off` | SSH handles encryption. Keep PROXY off for stock sshd. |
| Minecraft Java | `tcp/25565` | `off` | Enable PROXY only with a compatible configured proxy/plugin. Bedrock is not supported. |
| MQTT over immediate TLS | `tcp/8883` | `strict` or passthrough | Use an appropriate edge/origin certificate when terminating TLS. |
| SMTP submission with STARTTLS | `tcp/587` | `off` | SMTP negotiates TLS itself. Spectrum does not upgrade STARTTLS. |
| PostgreSQL | `tcp/5432` | `off` | Require native DB TLS/auth; verify client certificate validation settings. |
| MySQL | `tcp/3306` | `off` | Preserve native handshake; require native DB TLS/auth. |
| RDP | `tcp/3389` | `off` | Preserve RDP security negotiation; restrict access to authorized clients. |

## Example: MQTT with Public DNS Origin

```typescript
await client.spectrum.apps.create({
  zone_id: zoneId,
  protocol: 'tcp/8883',
  dns: { type: 'CNAME', name: 'mqtt.example.com' },
  origin_dns: { name: 'mqtt-origin.example.com' },
  origin_port: 8883,
  traffic_type: 'direct',
  tls: 'strict',
  proxy_protocol: 'off',
  ip_firewall: true,
});
```

The origin name must resolve to a reachable origin with a valid certificate. For private addresses configure virtual-network routing explicitly; an `.internal` name alone does not create connectivity.

## High Availability

Use supported Load Balancing integration with health checks and a fallback pool. For a database, failover must select the writable primary; round-robin among primary/replica addresses is not a safe database failover strategy. For long-lived TCP applications, test existing-connection behavior during an origin failure rather than promising zero downtime.

## SMTP Identity

Spectrum is a TCP proxy, not an outbound mail relay. Its edge IPs do not have reverse DNS entries. Evaluate HELO/EHLO, PTR, MX, source-IP checks, and a PROXY-capable mail listener. Email Routing is a separate forwarding product and is not a general replacement for hosting SMTP submission.

[API](api.md) · [Configuration](configuration.md) · [Gotchas](gotchas.md)
