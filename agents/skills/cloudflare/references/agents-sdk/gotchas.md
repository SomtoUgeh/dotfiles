# Agents SDK troubleshooting

Verify against installed types and https://developers.cloudflare.com/agents/ before assigning a cause.

- State does not sync: use `setState()` with the complete next state instead of mutating properties.
- Chat history grows: use the current chat retention/pruning API and preserve tool-call/result pairs. See [streaming chat](../../../agents-sdk/references/streaming-chat.md).
- WebSocket fails: inspect routing, authentication, upgrade headers, and connection errors. The Agents SDK accepts its managed connection; do not call `conn.accept()` again as a universal fix.
- MCP disconnects: use SDK-managed server registration/reconnect state through `addMcpServer`; there is no `mcp.registerServer` API. See [MCP](../../../agents-sdk/references/mcp.md).
- RPC fails: check `@callable`, serialization, and the client's `.call()` or typed `.stub` API.
- Schedules duplicate after wake: make `onStart` scheduling idempotent; check existing schedules or use the SDK's idempotent schedule option.
- Chat UI has missing fields: current hooks use `sendMessage`, `status`, and `message.parts`; keep input state in React.
- Quotas/overload: retrieve current [Agents limits](https://developers.cloudflare.com/agents/platform/limits/) and [DO limits](https://developers.cloudflare.com/durable-objects/platform/limits/). Do not assume unlimited connections or a fixed application throughput.

Use [observability](../../../agents-sdk/references/observability.md) to collect failures before changing behavior.
