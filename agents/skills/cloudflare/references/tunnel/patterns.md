# Tunnel Patterns

## Docker Deployment

### Token-Based (Recommended)
```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: ${TUNNEL_TOKEN}
    restart: unless-stopped
```

### Local Config
```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    volumes:
      - ./config.yml:/etc/cloudflared/config.yml:ro
      - ./credentials.json:/etc/cloudflared/credentials.json:ro
    command: tunnel run
```

## Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
        - tunnel
        - --no-autoupdate
        - run
        env:
        - name: TUNNEL_TOKEN
          valueFrom:
            secretKeyRef:
              name: tunnel-credentials
              key: token
```

## High Availability

```yaml
# Same config on multiple servers
tunnel: <UUID>
credentials-file: /path/to/creds.json

ingress:
  - hostname: app.example.com
    service: http://localhost:8000
  - service: http_status:404
```

Run same config on multiple machines. Cloudflare distributes traffic for availability; replicas do not guarantee an even or geographic load-balancing policy. Long-lived connections (WebSocket, SSH) may drop during updates.

## Use Cases

### Web Application
```yaml
ingress:
  - hostname: myapp.example.com
    service: http://localhost:3000
  - service: http_status:404
```

### SSH Access
```yaml
ingress:
  - hostname: ssh.example.com
    service: ssh://localhost:22
  - service: http_status:404
```

Client: `cloudflared access ssh --hostname ssh.example.com`

### gRPC Service
```yaml
ingress:
  - hostname: grpc.example.com
    service: https://localhost:50051
    originRequest:
      http2Origin: true
  - service: http_status:404
```

## Infrastructure as Code

Preserve the project's pinned Terraform/Pulumi provider and resource ownership. For Terraform v5, use these current shapes; the tunnel is remotely managed and no token is printed:

```hcl
resource "cloudflare_zero_trust_tunnel_cloudflared" "app" {
  account_id = var.account_id
  name       = "app-tunnel"
  config_src = "cloudflare"
}
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "app" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.app.id
  config = {
    ingress = [
      { hostname = "app.example.com", service = "http://localhost:8000" },
      { service = "http_status:404" }
    ]
  }
}
resource "cloudflare_dns_record" "app" {
  zone_id = var.zone_id
  name    = "app.example.com"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.app.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}
```

Retrieve the run token through the dedicated token API into the existing secret mechanism. For Pulumi, use [the maintained Pulumi reference](../pulumi/) and installed provider types; do not reuse v4 `Record`, `value`, `ingressRules` or a nonexistent `tunnel.cname` field with a newer provider.

## Service Installation

### Linux systemd
```bash
cloudflared service install
systemctl start cloudflared && systemctl enable cloudflared
journalctl -u cloudflared -f  # Logs
```

### macOS launchd
```bash
sudo cloudflared service install
sudo launchctl start com.cloudflare.cloudflared
```

Pin a tested cloudflared image version/digest in production rather than relying on mutable `latest`. Environment variables avoid token arguments but still belong to the secret-management boundary. Docker `localhost` means that container; route to a reachable service name when the origin is in another container. Kubernetes replicas must each reach the configured origin.

A public gRPC origin requires HTTPS and `http2Origin: true`; provide trusted origin TLS settings. Service installation changes system state and may require privileges: inspect the installed service paths and credentials first. Do not overwrite another tunnel service.
