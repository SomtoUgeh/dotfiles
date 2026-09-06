# CNI API Reference

Use `cloudflare` SDK declarations for the installed version. The examples below match 7.1.0. All account operations require an authorized API token; creating an interconnect can initiate provisioning.

## Endpoints

Base: `https://api.cloudflare.com/client/v4` with `Authorization: Bearer <token>`.

- `/accounts/{account_id}/cni/interconnects`: GET lists and POST creates.
- `/accounts/{account_id}/cni/interconnects/{icon}`: GET details and DELETE.
- Append `/status` for status or `/loa` for the Letter of Authorization PDF.
- `/accounts/{account_id}/cni/cnis`: GET and POST; append `/{cni}` for GET, PUT, DELETE.
- `/accounts/{account_id}/cni/slots`: GET slots; append `/{slot}` for one slot.
- `/accounts/{account_id}/cni/settings`: account settings.

List responses contain `items` and an optional `next` cursor. Interconnect queries use `cursor`, `limit`, `site`, and `type`, not `page`/`per_page`. Slot queries additionally support `occupied`, `speed`, and `address_contains`.

## TypeScript

```typescript
import Cloudflare from 'cloudflare';
const client = new Cloudflare({ apiToken: process.env.CF_TOKEN });
const account_id = process.env.CF_ACCOUNT_ID;
if (!account_id) throw new Error('CF_ACCOUNT_ID is required');

const slots = await client.networkInterconnects.slots.list({
  account_id, occupied: false, site: 'EWR', speed: '10G',
});
const page = await client.networkInterconnects.interconnects.list({ account_id, limit: 20 });

// Use the selected slot ID and connection type provided by Cloudflare.
const created = await client.networkInterconnects.interconnects.create({
  account_id, account: account_id, slot_id: selectedSlotId,
  type: approvedConnectionType, speed: '10G',
});
// Do not assume created.id exists: the API returns a typed connection object.
const connection = await client.networkInterconnects.interconnects.get(icon, { account_id });
const status = await client.networkInterconnects.interconnects.status(icon, { account_id });

// GCP partner interconnect is also supported by the current API.
await client.networkInterconnects.interconnects.create({
  account_id, account: account_id, type: approvedGcpConnectionType,
  bandwidth: '1G', pairing_key: gcpPairingKey,
});

await client.networkInterconnects.cnis.create({
  account_id, account: account_id, interconnect: icon,
  magic: { conduit_name: conduitName, description: 'Private connectivity', mtu: 1500 },
  bgp: { customer_asn: 65000, extra_prefixes: [] },
});
```

`selectedSlotId`, `icon`, conduit names, pairing keys, and connection type values come from the approved provisioning flow. The current SDK does not declare a `validate_only` creation parameter; do not present a real creation as a dry run. Physical create bodies do not accept arbitrary `name` or `facility` properties.

For LOA downloads, check the response before saving:

```typescript
import { writeFile } from 'node:fs/promises';
const response = await fetch(
  `https://api.cloudflare.com/client/v4/accounts/${account_id}/cni/interconnects/${icon}/loa`,
  { headers: { Authorization: `Bearer ${token}` } },
);
if (!response.ok) throw new Error(`LOA request failed: ${response.status}`);
await writeFile('loa.pdf', Buffer.from(await response.arrayBuffer()));
```

## Other clients and operational limits

The Python SDK uses `client.network_interconnects` and keyword arguments (`account_id=...`, `icon=...`); derive request fields from its installed types rather than translating an obsolete example. REST callers use the same documented schemas.

Physical cross-connect installation and account-team activation remain separate from API creation. Check the current status endpoint/dashboard for available telemetry; do not assume BGP state or optical readings are part of every response. BGP MD5 keys are treated by this API as a misconfiguration guard, not a secret authentication mechanism.

Sources: [Network Interconnect API](https://developers.cloudflare.com/api/resources/network_interconnects/), [TypeScript SDK](https://github.com/cloudflare/cloudflare-typescript), [Get started](https://developers.cloudflare.com/network-interconnect/get-started/).
