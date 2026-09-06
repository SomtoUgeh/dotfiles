# Tunnel troubleshooting

A healthy tunnel proves that `cloudflared` connects to Cloudflare. It does not prove the configured origin is listening, trusted by TLS, authorized or reachable from the client.

| Symptom | Check |
|---|---|
| Origin DNS or route failure | Confirm the hostname's DNS record, tunnel UUID, connected replicas and matching ingress rule. Do not attribute every 1016 to a stopped process. |
| HTTPS certificate rejected | Configure the correct `originServerName` and `caPool` for the origin. Keep `noTLSVerify: false`; disabling verification overrides CA validation. |
| Connection timeout | Check origin listening address/port and replica-to-origin connectivity before increasing timeouts. |
| Tunnel will not start | Validate the selected config, confirm credentials exist without printing them, inspect the specific service's logs. |
| HTTP/2 tunnel cannot connect | Allow TCP **7844**, not just 443. QUIC uses UDP 7844. |
| Private address still unreachable | Confirm WARP connection, split-tunnel routing, private route, Gateway policy and origin reachability separately. |

```bash
cloudflared tunnel ingress validate
cloudflared tunnel ingress rule https://app.example.com
cloudflared tunnel info my-tunnel
# Linux service logs, for the intended service:
journalctl -u cloudflared -n 100
```

Do not use `pkill cloudflared` as a default repair: it stops unrelated tunnels on the host. Identify the correct service/replica, update it, and verify another healthy replica before a rolling restart.

## Token rotation

After rotating a remotely managed token, the old token cannot establish new connections. Existing connectors remain active until restarted; there is no general 24-hour grace period. Update the intended replicas and validate them. If a token is compromised, rotation plus explicitly authorized disconnection of existing connectors may be necessary, with the associated interruption. See [token lifecycle](https://developers.cloudflare.com/tunnel/advanced/tunnel-tokens/).

## Limits and availability

The current [Cloudflare One limits](https://developers.cloudflare.com/cloudflare-one/account-limits/) list 1,000 cloudflared tunnels per account and 25 active replicas per tunnel; confirm current account entitlements before sizing. These are not limits of 1,000 client connections or unlimited tunnels. Long-lived sessions may break during updates/failover, so test reconnect behavior.

Replicas provide availability, not a guaranteed even or geographic traffic split. Use the appropriate load-balancing product if traffic steering is required. Keep replicas close to reachable origins, validate their actual configuration, and use controlled supported-version upgrades.

A Tunnel exposes configured services; it does not automatically authenticate their users. Apply Access/Gateway controls where required and keep the origin from accepting an unintended bypass path. Restrict bastion-style reachability to the requested scope.
