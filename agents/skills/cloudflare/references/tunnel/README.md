# Cloudflare Tunnel

Secure outbound-only connections between infrastructure and Cloudflare's global network.

## Overview

Cloudflare Tunnel (formerly Argo Tunnel) enables:
- **Outbound-only connections** - No inbound ports; outbound firewall access is still required
- **Public hostname routing** - Expose local services to internet
- **Private network access** - Connect internal networks via WARP
- **Zero Trust integration** - Can be protected by separately configured Access/Gateway policies

**Architecture**: Tunnel (persistent object) → Replica (`cloudflared` process) → Origin services

**Terminology:**
- **Tunnel**: Named persistent object with UUID
- **Replica**: Individual `cloudflared` process connected to tunnel
- **Config Source**: Where ingress rules stored (local file vs Cloudflare dashboard)
- **Connector**: Legacy term for replica

## Quick Start

### Local Config
```bash
# Install cloudflared
brew install cloudflared  # macOS

# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create my-tunnel

# Route DNS
cloudflared tunnel route dns my-tunnel app.example.com

# Run tunnel
cloudflared tunnel run my-tunnel
```

### Dashboard Config (Recommended)
1. **Zero Trust** > **Networks** > **Tunnels** > **Create**
2. Name tunnel, copy token
3. Configure routes in dashboard
4. Supply `TUNNEL_TOKEN` through the existing secret manager and run `cloudflared tunnel --no-autoupdate run`. Do not paste a token into recorded shell commands.

## Decision Tree

**Choose config source:**
```
Need centralized config updates?
├─ Yes → Token-based (dashboard config)
└─ No → Local config file

Multiple environments (dev/staging/prod)?
└─ Either source works; isolate tunnel identity and configuration per environment

Need firewall approval?
└─ See networking.md first
```

## Core Commands

```bash
# Tunnel lifecycle
cloudflared tunnel create <name>
cloudflared tunnel list
cloudflared tunnel info <name>
cloudflared tunnel delete <name>

# DNS routing
cloudflared tunnel route dns <tunnel> <hostname>
cloudflared tunnel route ip show

# Private network
cloudflared tunnel route ip add 10.0.0.0/8 <tunnel>

# Run tunnel
cloudflared tunnel run <name>
```

## Configuration Example

```yaml
# ~/.cloudflared/config.yml
tunnel: 6ff42ae2-765d-4adf-8112-31c55c1551ef
credentials-file: /root/.cloudflared/6ff42ae2-765d-4adf-8112-31c55c1551ef.json

ingress:
  - hostname: app.example.com
    service: http://localhost:8000
  - hostname: api.example.com
    service: https://localhost:8443
    originRequest:
      originServerName: api.example.com
      noTLSVerify: false
  - service: http_status:404
```

## Choose a Reference

Load the file that answers the current task; follow additional references only when needed.

- Firewall rules and connectivity → [networking.md](networking.md)
- Setup, bindings, and deployment configuration → [configuration.md](configuration.md)
- API calls, handlers, and runtime behavior → [api.md](api.md)
- Implementing a specific integration or use case → [patterns.md](patterns.md)
- Diagnosing failures and checking relevant limits → [gotchas.md](gotchas.md)

## In This Reference

- [networking.md](./networking.md) - Firewall rules, ports, connectivity pre-checks
- [configuration.md](./configuration.md) - Config file options, ingress rules, TLS settings
- [api.md](./api.md) - REST API, TypeScript SDK, token-based tunnels
- [patterns.md](./patterns.md) - Docker, Kubernetes, Terraform, HA, use cases
- [gotchas.md](./gotchas.md) - Troubleshooting, limitations, best practices

## See Also

- [workers](../workers/) - Workers with Tunnel integration
- [cloudflare-one](../../../cloudflare-one/SKILL.md) - Zero Trust access policies
- [Cloudflare One Client](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/warp/) - Private network client configuration
