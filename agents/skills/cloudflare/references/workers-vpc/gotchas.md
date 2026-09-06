# VPC troubleshooting

| Symptom | Check |
| --- | --- |
| Private IP fails through `cloudflare:sockets` | Use a configured VPC binding; public sockets do not provide private routing |
| VPC fetch throws | Connector health, private DNS, route, destination port, protocol, TLS trust |
| URL host does not change target | Expected for a fixed VPC Service; its registered destination wins |
| Network binding reaches unexpected host | Validate runtime destinations and caller authorization; its scope is broader |
| TCP TLS options rejected | Raw VPC Network TCP is currently plaintext-only |
| `fetch()` to database port fails | HTTP is not the database wire protocol; use Hyperdrive or the supported TCP path |
| Local test touches a real system | `remote: true` uses the actual bound service/network |
| Binding absent in staging | Configure non-inherited binding arrays for that named environment |

## Socket lifecycle

Create I/O objects in the request context. Release reader/writer locks and close
on completion/failure. One read is one chunk, not necessarily a whole protocol
message. Bound accumulated data; parse framing rather than waiting forever for a
persistent server to close. Closing a writable stream may end the connection:
release its lock when the protocol needs a reply before shutdown.

The Workers concurrent outgoing connection limit is shared with other outbound
I/O; it is not a private allowance of six additional TCP sockets. Consult the
[current limits](https://developers.cloudflare.com/workers/platform/limits/).
A timer that only rejects a Promise does not close the socket or clear itself.

## TLS and protocol choices

Public socket `secureTransport: 'on'` performs TLS immediately. SSH is not TLS,
and PostgreSQL's SSL negotiation is not a text `STARTTLS` command. Use a supported
protocol driver. VPC HTTP TLS trust and verification are configured on the service;
do not disable certificate verification as a default troubleshooting step.

## Evidence required

Verify the actual destination from the connector network and then through the
Worker's binding. Record the tested environment and operation. Local typechecks,
mock streams, and deploy dry runs cannot prove private-network reachability.

Sources: [VPC API](https://developers.cloudflare.com/workers-vpc/api/),
[public sockets restrictions](https://developers.cloudflare.com/workers/runtime-apis/tcp-sockets/).
