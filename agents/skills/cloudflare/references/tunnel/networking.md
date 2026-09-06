# Tunnel networking

## Firewall and protocol

Both tunnel transports use port **7844**:

| Transport | Egress |
|---|---|
| QUIC | UDP 7844 |
| HTTP/2 | TCP 7844 |

Permit the documented regional destinations, normally `region1.v2.argotunnel.com` and `region2.v2.argotunnel.com`. For IP-based or SNI-enforcing firewalls, copy the exact current addresses/hostnames from [Tunnel with firewall](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-with-firewall/). US-region and FedRAMP deployments use different lists. Do not allow the entire `2606:4700::/32` range based on a copied approximation.

TCP 443 supports optional/control-plane operations such as update checks; it is **not** the HTTP/2 data-tunnel fallback. API provisioning and software download hosts have separate requirements. Preserve existing network controls and request only the actual egress paths needed.

## Connectivity checks

```bash
dig SRV _v2-origintunneld._tcp.argotunnel.com
dig region1.v2.argotunnel.com A
dig region2.v2.argotunnel.com AAAA
nc -zv region1.v2.argotunnel.com 7844
# For an authorized existing tunnel, test the selected transport:
cloudflared tunnel --protocol http2 --loglevel debug run my-tunnel
```

A successful TCP probe tests reachability only. UDP `nc` output is not proof of a QUIC handshake. Confirm registered tunnel connections and test a real request through the intended hostname/private route. DNS resolution must work using the network's configured resolver; do not assume opening public port 53 is the right repair.

HTTP proxy variables do not establish that the tunnel data transports can pass through an HTTP CONNECT proxy. Validate the selected cloudflared version and corporate network path; do not install a corporate root CA or bypass TLS verification as a generic workaround for a blocked tunnel port.

## WARP and private routes

Tunnel egress and WARP client egress are separate. Use the [Cloudflare One client firewall requirements](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/warp/deployment/firewall/) for the enrolled client's configured transport; do not assume generic IPsec UDP 500/4500 applies.

For private access, check all of:

1. The replica can reach the exact origin address and port.
2. The CIDR/hostname route points to the intended tunnel and virtual network.
3. The client is enrolled, connected, and its split-tunnel profile includes this traffic.
4. Gateway network policy permits the intended user/device/destination.
5. Private DNS resolves through the correct path when hostnames are used.

`warp-routing.enabled: true` does not configure split tunnels. In exclude mode remove the necessary route from exclusions; in include mode add it to inclusions. Preserve the user's existing mode and unrelated routes.

## Diagnostics and limits

Expose metrics only on the intended local/management interface:

```bash
cloudflared tunnel --metrics 127.0.0.1:9090 run my-tunnel
curl http://127.0.0.1:9090/metrics
```

Check the installed CLI help before requesting JSON output flags. Inspect connector health, origin latency and real request status separately. HTTP request-body limits depend on the public application's plan/path; private network flows and replicas are different limits. Retrieve current limits rather than assuming a universal 100 MB body or 1,000 concurrent connections.
