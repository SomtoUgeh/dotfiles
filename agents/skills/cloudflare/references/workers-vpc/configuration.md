# VPC configuration

Create or select the requested private-network connection using the
[official Tunnel setup](https://developers.cloudflare.com/workers-vpc/configuration/tunnel/).
Verify the connector can resolve and reach the destination. A public DNS CNAME
alone does not establish VPC connectivity.

## Fixed HTTP service

Register a VPC Service with its real Tunnel ID, destination host/IP, service type,
and HTTP/HTTPS ports. Configure certificate verification for the origin. Creating
services requires Connectivity Directory Admin; binding an existing service
requires Connectivity Directory Bind or Admin.

Merge this into the existing Wrangler configuration using the returned service ID:

```jsonc
{
  "vpc_services": [
    { "binding": "PRIVATE_API", "service_id": "<SERVICE_ID>", "remote": true }
  ]
}
```

## Network access

Choose one network target per binding. A Tunnel binding requires Connectivity
Directory Admin:

```jsonc
{
  "vpc_networks": [
    { "binding": "PRIVATE_VPC", "tunnel_id": "<TUNNEL_UUID>", "remote": true }
  ]
}
```

For account-wide Mesh/WAN connectivity, use `network_id: "cf1:network"` in place
of `tunnel_id`. The account needs an active on-ramp and routes to the target;
WAN deployments also need the documented return route for Cloudflare source IPs.
This broader scope is a deliberate choice, not an automatic fallback.

## Development and deployment

- Use the project's installed Wrangler and run `wrangler types` after changing
  bindings. Keep the project's compatibility date unless an upgrade is intended.
- These binding arrays are not inherited by named environments; configure each
  selected environment explicitly.
- `remote: true` makes local development contact the real private service. Use a
  test destination or local application-level substitute for isolated tests.
- Keep credentials in server secrets. Destination hostnames are configuration,
  not proof that callers are authorized.
- Validate the exact route, DNS, protocol, origin TLS, and a harmless request
  before reporting connectivity. A dry run verifies configuration only.

Sources: [VPC Services](https://developers.cloudflare.com/workers-vpc/configuration/vpc-services/),
[VPC Networks](https://developers.cloudflare.com/workers-vpc/configuration/vpc-networks/).
