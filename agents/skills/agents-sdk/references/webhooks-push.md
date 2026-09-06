# Webhooks & Push Notifications

## Webhooks

Fetch https://developers.cloudflare.com/agents/api-reference/webhooks/ for complete documentation.

Route external webhooks to agent instances via `onRequest`:

```typescript
export default {
  async fetch(req: Request, env: Env) {
    const url = new URL(req.url);
    if (url.pathname.startsWith("/webhooks/")) {
      const entityId = url.pathname.split("/")[2];
      if (!entityId) return new Response("Missing entity ID", { status: 400 });
      const agent = await getAgentByName(env.MyAgent, entityId);
      return agent.fetch(req);
    }
    return (await routeAgentRequest(req, env)) ?? new Response("Not found", { status: 404 });
  }
};
```

In the agent:

```typescript
export class MyAgent extends Agent<Env, State> {
  async onRequest(request: Request) {
    const signature = request.headers.get("X-Signature");
    const body = await request.text();
    if (!await verifySignature(signature, body, this.env.WEBHOOK_SECRET)) {
      return new Response("Unauthorized", { status: 401 });
    }
    let payload: unknown;
    try {
      payload = JSON.parse(body);
    } catch {
      return new Response("Invalid JSON", { status: 400 });
    }
    await this.queue("processWebhook", payload);
    return new Response("OK", { status: 202 });
  }

  async processWebhook(payload: unknown) {
    // Application validates the provider event and performs idempotent work.
    await handleVerifiedWebhook(payload);
  }
}
```

**Tips:** Respond quickly (200/202), verify signatures, deduplicate with stored event IDs, use `queue()` for async processing.

## Push Notifications

Fetch https://developers.cloudflare.com/agents/api-reference/push-notifications/ for complete documentation.

Web Push via VAPID from agents. Store subscriptions in agent state, send via `web-push`.

```bash
npm install web-push
```

```typescript
import webpush from "web-push";

type NotificationState = { subscriptions: webpush.PushSubscription[] };

export class NotifyAgent extends Agent<Env, NotificationState> {
  initialState: NotificationState = { subscriptions: [] };
  @callable()
  async subscribe(subscription: webpush.PushSubscription) {
    this.setState({
      ...this.state,
      subscriptions: [...this.state.subscriptions, subscription]
    });
  }

  async sendReminder(payload: { message: string }, schedule: Schedule<{ message: string }>) {
    for (const sub of this.state.subscriptions) {
      try {
        await webpush.sendNotification(sub, JSON.stringify({
          title: "Reminder",
          body: payload.message
        }), {
          vapidDetails: {
            subject: "mailto:you@example.com",
            publicKey: this.env.VAPID_PUBLIC_KEY,
            privateKey: this.env.VAPID_PRIVATE_KEY
          }
        });
      } catch (err) {
        if (err instanceof webpush.WebPushError &&
            (err.statusCode === 404 || err.statusCode === 410)) {
          this.setState({
            ...this.state,
            subscriptions: this.state.subscriptions.filter(
              (subscription) => subscription.endpoint !== sub.endpoint
            )
          });
        } else {
          throw err;
        }
      }
    }
  }
}
```

VAPID keys: generate with `npx web-push generate-vapid-keys`, store as secrets.
