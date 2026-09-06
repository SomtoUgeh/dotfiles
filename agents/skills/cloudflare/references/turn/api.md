# TURN credential API

Credential operations use the TURN key secret, not the account API token used to manage keys. Run these calls only on the server.

```bash
curl --fail-with-body \
  "https://rtc.live.cloudflare.com/v1/turn/keys/$TURN_KEY_ID/credentials/generate-ice-servers" \
  -H "Authorization: Bearer $TURN_KEY_SECRET" \
  -H 'Content-Type: application/json' \
  -d '{"ttl":3600}'
```

## Validated TypeScript helper

```typescript
export interface IceServer {
  urls: string[];
  username?: string;
  credential?: string;
}

export function parseIceServers(value: unknown): IceServer[] {
  if (!value || typeof value !== "object" || !("iceServers" in value) ||
      !Array.isArray(value.iceServers)) throw new Error("Invalid ICE response");
  const servers: IceServer[] = [];
  for (const server of value.iceServers) {
    if (!server || typeof server !== "object" || !("urls" in server) ||
        !Array.isArray(server.urls) ||
        !server.urls.every((url: unknown) => typeof url === "string")) {
      throw new Error("Invalid ICE server");
    }
    const urls = server.urls.filter((url: string) => !/:53(?:\?|$)/.test(url));
    if (!urls.every((url: string) => /^(stun|stuns|turn|turns):/.test(url))) {
      throw new Error("Invalid ICE URL");
    }
    if (!urls.length) continue;
    const username: unknown = "username" in server ? server.username : undefined;
    const credential: unknown = "credential" in server ? server.credential : undefined;
    const usesTurn = urls.some((url: string) => /^turns?:/.test(url));
    if (usesTurn && (typeof username !== "string" || !username ||
                    typeof credential !== "string" || !credential)) {
      throw new Error("Missing TURN credentials");
    }
    if (username !== undefined && typeof username !== "string") throw new Error("Invalid username");
    if (credential !== undefined && typeof credential !== "string") throw new Error("Invalid credential");
    servers.push({ urls, ...(username === undefined ? {} : { username }),
      ...(credential === undefined ? {} : { credential }) });
  }
  if (!servers.some(server => server.urls.some(url => /^turns?:/.test(url)))) {
    throw new Error("No usable TURN server");
  }
  return servers;
}

export async function generateIceServers(
  keyId: string, secret: string, ttl: number,
): Promise<IceServer[]> {
  if (!keyId || !secret) throw new Error("TURN configuration missing");
  if (!Number.isInteger(ttl) || ttl < 1 || ttl > 172800) throw new Error("Invalid TTL");
  const response = await fetch(
    `https://rtc.live.cloudflare.com/v1/turn/keys/${encodeURIComponent(keyId)}/credentials/generate-ice-servers`,
    { method: "POST", headers: { Authorization: `Bearer ${secret}`,
      "Content-Type": "application/json" }, body: JSON.stringify({ ttl }),
      signal: AbortSignal.timeout(10000) },
  );
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error(`TURN credential generation failed (${response.status})`);
  }
  const body: unknown = await response.json();
  return parseIceServers(body);
}
```

## Revoke a credential

POST to `/v1/turn/keys/{keyId}/credentials/{username}/revoke`, with the TURN key secret as bearer authorization. URL-encode both path components. A successful response is `204 No Content`; do not parse it as JSON. There is no username-in-body `/credentials/revoke` endpoint. Treat usernames and credentials as sensitive and omit them from logs.

[Official API and TTL guidance](https://developers.cloudflare.com/realtime/turn/generate-credentials/)
