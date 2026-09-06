# Server-Driven Messages (Trigger Patterns)

Fetch https://developers.cloudflare.com/agents/api-reference/trigger-patterns/ for complete documentation.

Patterns for server-initiated LLM turns in `AIChatAgent` — from schedules, webhooks, email, or other agents.

## `saveMessages` — Trigger an LLM Turn

```typescript
await this.saveMessages((existingMessages) => [
  ...existingMessages,
  { role: "user", id: crypto.randomUUID(), parts: [{ type: "text", text: "Check for new notifications" }] }
]);
```

`saveMessages` persists the messages AND triggers `onChatMessage`.

## `persistMessages` — Save Without Triggering

```typescript
await this.persistMessages([
  ...this.messages,
  { role: "assistant", id: crypto.randomUUID(), parts: [{ type: "text", text: "System note: checked at " + new Date() }] }
]);
```

## `waitUntilStable`

**Always call before `saveMessages` from non-chat contexts** (schedules, webhooks, email):

```typescript
async checkNotifications(payload: unknown, schedule: Schedule<unknown>) {
  const stable = await this.waitUntilStable({ timeout: 30_000 });
  if (!stable) return; // Retry later; pending user interactions may still block the conversation.
  await this.saveMessages((msgs) => [
    ...msgs,
    { role: "user", id: crypto.randomUUID(), parts: [{ type: "text", text: "Run scheduled notification check" }] }
  ]);
}
```

## `onChatResponse`

Runs after each LLM turn completes. Use for chaining:

```typescript
async onChatResponse(result: ChatResponseResult) {
  if (result.status === "completed" && needsFollowUp(result)) {
    await this.saveMessages((msgs) => [
      ...msgs,
      { role: "user", id: crypto.randomUUID(), parts: [{ type: "text", text: "Continue with next step" }] }
    ]);
  }
}
```

## Client Status

```tsx
const { isStreaming, isServerStreaming } = useAgentChat({ agent });
```

- `isStreaming` — true during any streaming (user-initiated or server-initiated)
- `isServerStreaming` — true only during server-initiated streams
