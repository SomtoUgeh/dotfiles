# Cloudflare Tunnel API

Use the project's installed `cloudflare` SDK and a scoped API token. Remotely managed Cloudflare Tunnel operations are under `zeroTrust.tunnels.cloudflared`, not directly on `zeroTrust.tunnels`.

## SDK lifecycle

```typescript
import Cloudflare from "cloudflare";

const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
if (!accountId) throw new Error("CLOUDFLARE_ACCOUNT_ID is required");
const cf = new Cloudflare(); // CLOUDFLARE_API_TOKEN from the server environment

// Read-only inventory; automatic pagination.
for await (const tunnel of cf.zeroTrust.tunnels.cloudflared.list({
  account_id: accountId,
  is_deleted: false,
})) {
  console.log(tunnel.id, tunnel.name, tunnel.status);
}

// Creation is a separately authorized infrastructure change.
const created = await cf.zeroTrust.tunnels.cloudflared.create({
  account_id: accountId,
  name: "my-tunnel",
  config_src: "cloudflare",
});
if (!created.id) throw new Error("Create response has no tunnel ID");
const token = await cf.zeroTrust.tunnels.cloudflared.token.get(created.id, {
  account_id: accountId,
});
// Store token in the intended secret manager; never print it.
```

A locally managed tunnel instead uses `config_src: "local"` and a base64-encoded random secret of at least 32 bytes. In Node, import `randomBytes` from `node:crypto`; the Web Crypto `crypto` object has no `randomBytes()` method.

## REST endpoints

All paths below are relative to `https://api.cloudflare.com/client/v4` and require account-scoped authentication. Check both HTTP status and Cloudflare's `success`/`errors` envelope.

| Operation | Method and path |
|---|---|
| List/create Cloudflare tunnels | `GET` / `POST /accounts/{account_id}/cfd_tunnel` |
| Get/delete a tunnel | `GET` / `DELETE /accounts/{account_id}/cfd_tunnel/{tunnel_id}` |
| Update tunnel metadata | `PATCH /accounts/{account_id}/cfd_tunnel/{tunnel_id}` |
| Read/replace remote ingress config | `GET` / `PUT /accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations` |
| Get run token | `GET /accounts/{account_id}/cfd_tunnel/{tunnel_id}/token` |
| Read/clean connector connections | `GET` / `DELETE /accounts/{account_id}/cfd_tunnel/{tunnel_id}/connections` |
| List/create private CIDR routes | `GET` / `POST /accounts/{account_id}/teamnet/routes` |
| Read/delete a private CIDR route | `GET` / `DELETE /accounts/{account_id}/teamnet/routes/{route_id}` |

Remote ingress configuration body:

```json
{
  "config": {
    "ingress": [
      { "hostname": "app.example.com", "service": "http://localhost:8000" },
      { "service": "http_status:404" }
    ]
  }
}
```

`PUT` replaces configuration: read the existing rules and preserve unrelated routes. SDK versions whose generated type requires `hostname` on the final catch-all may need the documented REST body until that schema mismatch is resolved; do not silence it with an unsafe assertion.

Private CIDR route body:

```json
{ "network": "10.20.0.0/16", "tunnel_id": "TUNNEL_UUID" }
```

## DNS is separate

A public hostname uses a zone DNS CNAME pointing to `TUNNEL_UUID.cfargotunnel.com`, plus a matching ingress rule. Create/update it with the DNS records API (`/zones/{zone_id}/dns_records`) or the authorized `cloudflared tunnel route dns` command. The tunnel `connections` endpoint manages active connectors; it does not create or delete DNS routes. Private hostname routes also have their own Zero Trust route API and are not public DNS records.

Deleting a tunnel, a route or connector connections interrupts its users. Inspect the exact account, tunnel and route before executing a requested deletion; avoid deleting all connectors merely to fix one replica.

[Cloudflared API](https://developers.cloudflare.com/api/resources/zero_trust/subresources/tunnels/subresources/cloudflared/) · [Private routes](https://developers.cloudflare.com/api/resources/zero_trust/subresources/networks/subresources/routes/) · [Tunnel tokens](https://developers.cloudflare.com/tunnel/advanced/tunnel-tokens/)
