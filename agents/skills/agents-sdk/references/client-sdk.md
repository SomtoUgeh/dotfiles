# Client SDK

Fetch https://developers.cloudflare.com/agents/api-reference/client-sdk/ for complete documentation.

## React: `useAgent`

```tsx
import { useState } from "react";
import { useAgent } from "agents/react";

function App() {
  const [state, setState] = useState({ count: 0 });

  const agent = useAgent<{ count: number }>({
    agent: "Counter",
    name: "my-instance",
    onStateUpdate: (newState) => setState(newState),
    onIdentity: (name, agentType) => console.log(`Connected to ${name}`)
  });

  return <button onClick={() => agent.setState({ count: state.count + 1 })}>
    {state.count}
  </button>;
}
```

### Typed RPC via `stub`

```tsx
const agent = useAgent<typeof MyAgent>({
  agent: "MyAgent",
  name: "default"
});

const result = await agent.stub.myMethod(arg1, arg2);
```

### Auth via Query Params

```tsx
useAgent({
  agent: "MyAgent",
  name: "default",
  query: async () => ({ token: await getToken() }),
  queryDeps: [tokenVersion]
});
```

## React: `useAgentChat`

```tsx
import { useState } from "react";
import { useAgent } from "agents/react";
import { useAgentChat } from "@cloudflare/ai-chat/react";

function Chat() {
  const agent = useAgent({ agent: "ChatAgent", name: "session-1" });

  const [input, setInput] = useState("");
  const { messages, sendMessage, status } = useAgentChat({ agent });
  const busy = status === "submitted" || status === "streaming";

  return (
    <div>
      {messages.map((message) => <div key={message.id}>
        {message.parts.map((part, index) =>
          part.type === "text" ? <span key={index}>{part.text}</span> : null)}
      </div>)}
      <form onSubmit={(event) => {
        event.preventDefault();
        if (busy || !input.trim()) return;
        void sendMessage({ text: input });
        setInput("");
      }}>
        <input value={input} onChange={(event) => setInput(event.target.value)} />
        <button disabled={busy || !input.trim()}>Send</button>
      </form>
    </div>
  );
}
```

## Vanilla JS: `AgentClient`

```typescript
import { AgentClient } from "agents/client";

const client = new AgentClient({
  agent: "MyAgent",
  name: "default",
  host: "my-worker.workers.dev",
  onStateUpdate: (state) => console.log(state)
});
const result = await client.call("myMethod", [arg]);
client.close();
```

## `agentFetch` for HTTP-only

```typescript
import { agentFetch } from "agents/client";

const response = await agentFetch({
  agent: "MyAgent",
  name: "default",
  host: "https://my-worker.workers.dev",
  path: "api/data"
});
```

## Streaming RPC

```typescript
await agent.call("streamResults", ["query"], {
  stream: {
    onChunk: (data) => console.log(data),
    onDone: () => console.log("done"),
    onError: (err) => console.error(err)
  }
});
```
