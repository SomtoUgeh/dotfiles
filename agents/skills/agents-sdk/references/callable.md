# Callable Methods

Fetch https://developers.cloudflare.com/agents/api-reference/callable-methods/ for complete documentation.

## Overview

`@callable()` exposes agent methods to clients via WebSocket RPC.

```typescript
import { Agent, callable } from "agents";

export class MyAgent extends Agent<Env, State> {
  @callable()
  async greet(name: string): Promise<string> {
    return `Hello, ${name}!`;
  }

  @callable()
  async processData(data: unknown): Promise<Result> {
    // Long-running work
    return result;
  }
}
```

## Client Usage

```typescript
// Basic call
const greeting = await agent.call("greet", ["World"]);

// With timeout
const result = await agent.call("processData", [data], {
  timeout: 5000  // 5 second timeout
});
```

## Streaming Responses

```typescript
import { Agent, callable, StreamingResponse } from "agents";

export class MyAgent extends Agent<Env, State> {
  @callable({ streaming: true })
  async streamResults(stream: StreamingResponse, query: string) {
    for await (const item of fetchResults(query)) {
      stream.send(JSON.stringify(item));
    }
    stream.end();
  }

  @callable({ streaming: true })
  async streamWithError(stream: StreamingResponse) {
    try {
      // ... work
    } catch (error) {
      stream.error(error instanceof Error ? error.message : String(error));  // Signal error to client
      return;
    }
    stream.end();
  }
}
```

Client with streaming:

```typescript
await agent.call("streamResults", ["search term"], {
  stream: {
    onChunk: (data) => console.log("Chunk:", data),
    onDone: () => console.log("Complete"),
    onError: (error) => console.error("Error:", error)
  }
});
```

## Introspection

```typescript
// Inside the agent: returns a Map of method names to callable metadata.
const methods = this.getCallableMethods();
const names = [...methods.keys()];
// Expose your own @callable method if clients need this information.
```

## When to Use

| Scenario | Use |
|----------|-----|
| Browser/mobile calling agent | `@callable()` |
| External service calling agent | `@callable()` |
| Worker calling agent (same codebase) | DO RPC directly |
| Agent calling another agent | `getAgentByName()` + DO RPC |
