# Agents SDK API map

The [shared Agents SDK reference](../../../agents-sdk/SKILL.md) owns executable examples; this index avoids maintaining a second incompatible copy.

| Task | Maintained reference |
|---|---|
| State, SQL, lifecycle, schedules | [State and scheduling](../../../agents-sdk/references/state-scheduling.md) |
| Callable RPC and streaming | [Callable methods](../../../agents-sdk/references/callable.md) |
| AI chat and tools | [Streaming chat](../../../agents-sdk/references/streaming-chat.md) |
| React / vanilla clients | [Client SDK](../../../agents-sdk/references/client-sdk.md) |
| MCP clients and servers | [MCP](../../../agents-sdk/references/mcp.md) |
| Queue and retry | [Queue and retries](../../../agents-sdk/references/queue-retries.md) |
| Email | [Email](../../../agents-sdk/references/email.md) |
| Fibers | [Durable execution](../../../agents-sdk/references/durable-execution.md) |

`AIChatAgent` uses AI SDK `streamText`, not `this.streamText`. Iterate `this.getConnections()` or use `this.broadcast()`. `dequeue(id)` removes a queued item; it does not process a requested number of tasks. Await `getAgentByName()` before using the stub. Parse `AgentEmail.getRaw()` with a MIME parser rather than calling `email.text()`.
