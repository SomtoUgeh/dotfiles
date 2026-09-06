# Workers VPC

Workers VPC connects Workers to private services through a configured Cloudflare
Tunnel, Mesh, or WAN route. It remains beta; verify the installed Wrangler schema
and current [product docs](https://developers.cloudflare.com/workers-vpc/) before setup.

| Requirement | Choice |
| --- | --- |
| One known private HTTP host/port | VPC Service binding |
| Multiple private destinations or raw TCP | VPC Network binding |
| Private PostgreSQL/MySQL | TCP VPC Service through [Hyperdrive](../hyperdrive/) |
| Public TCP endpoint | `cloudflare:sockets`, subject to public socket restrictions |

A plain `cloudflare:sockets.connect()` call does not gain access to private IPs
by naming a Tunnel hostname. Published Tunnel TCP applications also do not expose
a raw TCP port that Workers can dial directly. Configure the appropriate VPC
binding and network route.

VPC Services constrain the destination to the registered host and port. The URL
host supplies HTTP Host/TLS SNI, not a different connection destination. VPC
Networks allow the runtime URL/address to choose a destination and therefore need
application authorization and destination restrictions.

Read [configuration.md](./configuration.md), then [api.md](./api.md),
[patterns.md](./patterns.md), and [gotchas.md](./gotchas.md).
