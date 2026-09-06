# Agents SDK patterns

Use the maintained implementations for each pattern:

- [AI chat with tools](../../../agents-sdk/references/streaming-chat.md) and [React client](../../../agents-sdk/references/client-sdk.md).
- [Human approval and client tools](../../../agents-sdk/references/human-in-the-loop.md). Omit server `execute` for client tools; `execute: "client"` is not a valid AI SDK function. Approval and client execution are different flows.
- [Queued work and retries](../../../agents-sdk/references/queue-retries.md). The SDK processes registered queue callbacks; do not invent `dequeue(10)` batch processing.
- [Scheduled processing and state](../../../agents-sdk/references/state-scheduling.md). Initialization can run again, so schedule idempotently.
- [Email parsing/replies](../../../agents-sdk/references/email.md). Treat inbound content as untrusted; an LLM's summary is not authorization to send a reply.
- [Webhooks](../../../agents-sdk/references/webhooks-push.md). Verify the raw body once, validate the payload, and deduplicate event IDs.
- [Durable Workflows](../../../agents-sdk/references/workflows.md) for background work that needs replay and step retries.

For manual WebSocket collaboration, use [current WebSocket docs](https://developers.cloudflare.com/agents/runtime/communication/websockets/): authenticate identity on the server, validate message schemas and allowed actions, persist state, and broadcast through `getConnections()`/`broadcast()`. Do not trust a client-provided user ID or score as authority.
