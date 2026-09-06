# Think (Experimental)

Fetch https://developers.cloudflare.com/agents/api-reference/think/ for complete documentation.

`@cloudflare/think` — a higher-level chat agent class that handles the `streamText` loop, tool execution, and message persistence for you. You provide `getModel()` and `getSystemPrompt()`; Think handles the rest.

```bash
npm install @cloudflare/think
```

## Minimal Agent

```typescript
import { Think } from "@cloudflare/think";
import { createWorkersAI } from "workers-ai-provider";
import { routeAgentRequest } from "agents";

export class MyAgent extends Think<Env> {
  getModel() {
    return createWorkersAI({ binding: this.env.AI })("@cf/meta/llama-4-scout-17b-16e-instruct");
  }

  getSystemPrompt() {
    return "You are a helpful assistant.";
  }
}

export default {
  async fetch(req, env) {
    return (await routeAgentRequest(req, env)) ?? new Response("Not found", { status: 404 });
  }
};
```

## Wrangler Config

```jsonc
{
  "compatibility_flags": ["nodejs_compat", "experimental"],
  "durable_objects": {
    "bindings": [{ "name": "MyAgent", "class_name": "MyAgent" }]
  },
  "exports": { "MyAgent": { "type": "durable-object", "storage": "sqlite" } },
  "ai": { "binding": "AI" }
}
```

**Note:** Think requires the `experimental` compatibility flag.

## Custom Tools

```typescript
import { tool } from "ai";
import { z } from "zod";

export class MyAgent extends Think<Env> {
  getTools() {
    return {
      getWeather: tool({
        description: "Get weather",
        inputSchema: z.object({ city: z.string() }),
        execute: async ({ city }) => `72°F in ${city}`
      })
    };
  }
}
```

## Lifecycle Hooks

| Hook | When | Use for |
|------|------|---------|
| `configureSession()` | Agent starts | Set up memory, context providers |
| `beforeTurn(ctx)` | Before each LLM call | Per-turn model/tools/system prompt; return `TurnConfig` |
| `onChunk(chunk)` | Each streaming chunk | Progress tracking |
| `onChatResponse(result)` | After LLM turn completes | Chaining, follow-up `saveMessages` |
| `onChatError(error)` | On LLM error | Error handling |

```typescript
import type { TurnContext, TurnConfig } from "@cloudflare/think";

async beforeTurn(ctx: TurnContext): Promise<TurnConfig> {
  if (ctx.continuation) {
    return { model: cheaperModel };
  }
  return {};
}
```

## Sub-Agents

```typescript
import { RpcTarget } from "cloudflare:workers";
import type { StreamCallback, ChatStartEvent } from "@cloudflare/think";

class ChatEvents extends RpcTarget implements StreamCallback {
  onStart(event: ChatStartEvent) { console.log("Started", event.requestId); }
  onEvent(json: string) { console.log("Chunk", json); }
  onDone() { console.log("Completed"); }
  onError(error: string) { console.error("Chat failed", error); }
  onInterrupted() { console.log("Interrupted; do not finalize a partial response"); }
}

// Inside an async method of the parent Think agent:
const child = await this.subAgent(SpecialistAgent, "specialist-1");
await child.chat("Analyze this data...", new ChatEvents());
```

## Client

Same React hooks as `AIChatAgent`:

```tsx
const agent = useAgent({ agent: "MyAgent", name: "session-1" });
const { messages, sendMessage, status } = useAgentChat({ agent });
// Keep input in React state; see client-sdk.md for the complete form.
```

## Think vs AIChatAgent

| | Think | AIChatAgent |
|-|-------|-------------|
| `streamText` loop | Built-in | You write it |
| Tool execution | Automatic | You wire it |
| Customization | Override hooks | Full control in `onChatMessage` |
| Built-in tools | Workspace, execute, browser | None |
| Compatibility flag | Requires `experimental` | Standard |
