# Zaraz patterns

## Identity lifecycle

Only send identity attributes allowed by the product's data policy and tool.
Use the key/value API with an intentional scope:

```javascript
// In the application's login callback; user is already verified by the app.
zaraz.set('userId', user.id, { scope: 'session' });
zaraz.set('plan', user.plan, { scope: 'session' });
await zaraz.track('login', { method: 'oauth' });

// In logout/account-switch cleanup; clear every identity-related key.
zaraz.set('userId', undefined);
zaraz.set('plan', undefined);
```

Default `persist` scope survives page reloads and sessions. Setting a key to
`null` sends null; setting it to `undefined` removes it from all scopes.

## Commerce and experiments

Emit purchases from a confirmed order outcome with a stable order ID and provider-
appropriate deduplication. Do not emit a second purchase on every receipt-page
render. Enable Zaraz's commerce setting and the selected tool's commerce support.

```javascript
zaraz.set('experiment_checkout', variant, { scope: 'page' });
await zaraz.track('experiment_viewed', { experiment_id: 'checkout', variant });
```

`variant` comes from the existing experiment assignment, not a new random value
on each render. Track conversions using the same assignment.

## Context Enricher

Enrich the supplied `{ system, client }` context. The Worker's own `request.cf`
metadata does not establish the original visitor's location; read the supplied
system context when needed. Do not put secrets into fields forwarded to tools.

```typescript
function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

type Env = { PUBLIC_APPLICATION_TAG: string };

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    let body: unknown;
    try { body = await request.json(); } catch {
      return new Response('Invalid JSON', { status: 400 });
    }
    if (!isRecord(body) || !isRecord(body.system) || !isRecord(body.client)) {
      return new Response('Invalid context', { status: 400 });
    }
    return Response.json({
      system: body.system,
      client: { ...body.client, application: env.PUBLIC_APPLICATION_TAG },
    });
  }
};
```

Configure this Worker as the Context Enricher in Zaraz settings. Validate a
representative context locally, then test the selected zone and actual tool.
For computed dashboard values, use the documented
[Worker Variables](https://developers.cloudflare.com/zaraz/variables/worker-variables/)
contract rather than inventing a `{{worker.variable_name}}` context path.

## GTM migration

Map each actual source event, property, trigger, consent purpose, and destination
tool. Configure equivalent actions and verify event counts before removing the
old tag. Zaraz also provides a dataLayer compatibility setting; decide whether
to use it for the requested migration. Avoid double emission while both systems
run. SPA tracking choices are covered in [configuration.md](./configuration.md).

Source: [Context Enricher](https://developers.cloudflare.com/zaraz/advanced/context-enricher/).
