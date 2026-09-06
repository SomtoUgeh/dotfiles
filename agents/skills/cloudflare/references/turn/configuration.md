# TURN application configuration

1. Create a TURN key in the Realtime dashboard or key management API. Store its ID as configuration and its secret as a server secret.
2. Add an application endpoint such as `POST /api/ice-servers`. Authenticate the caller, authorize membership in the requested call, enforce CSRF/origin protection appropriate to your authentication mechanism, and rate-limit credential issuance. Merely checking that an Authorization header exists does not authenticate it.
3. Call `generateIceServers` from [api.md](api.md) with a server-selected TTL. Return `{ iceServers }` with `Cache-Control: private, no-store` and JSON content type. Map upstream failures to a bounded error response without exposing the secret or response body.
4. Return credentials only to the authorized participant. A global cache shared across users or tenants makes revocation, attribution, and isolation unreliable. If reuse is required, scope it to the authenticated session and TURN key and expire it early.

```jsonc
{
  "name": "realtime-api",
  "main": "src/index.ts",
  "compatibility_date": "2026-09-05",
  "vars": { "TURN_KEY_ID": "your-key-id" },
  "env": {
    "production": { "vars": { "TURN_KEY_ID": "your-production-key-id" } }
  }
}
```

```bash
wrangler secret put TURN_KEY_SECRET
wrangler secret put TURN_KEY_SECRET --env production
wrangler types
```

Environment vars and secrets must exist in the environment being deployed. Store local secrets in an ignored `.dev.vars`; keep production credentials out of source and browser bundles. Test response shape using mock credentials before making billable relay requests.

Use [current TURN networking and limits](https://developers.cloudflare.com/realtime/turn/) for firewall policy, supported transports, rates, and pricing. Do not hardcode a copied IP list indefinitely.
