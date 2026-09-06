# Human-in-the-Loop

Fetch https://developers.cloudflare.com/agents/concepts/human-in-the-loop/ for complete documentation.

Multiple patterns for adding human approval to agent actions.

## Decision Guide

| Pattern | Best for |
|---------|----------|
| Workflows `waitForApproval` | Long-running background tasks |
| AI SDK `needsApproval` on tools | Chat tool calls requiring approval |
| Client tools (`onToolCall`) | Tools that execute in the browser |
| MCP `elicitInput` | Gathering structured input from MCP clients |

## Workflow Approvals

```typescript
// In AgentWorkflow:
await this.waitForApproval(step, { timeout: "7 days" });
// Rejection and timeout throw; handle the workflow failure explicitly.

// From agent:
await this.approveWorkflow(workflowId);
await this.rejectWorkflow(workflowId);
```

## Chat Tool Approvals (`needsApproval`)

```typescript
const tools = {
  deleteItem: tool({
    description: "Delete an item",
    inputSchema: z.object({ id: z.string() }),
    execute: async ({ id }) => { /* delete */ },
    needsApproval: true  // or a function: (toolCall) => boolean
  })
};
```

Client handles approval:

```tsx
const { addToolApprovalResponse, addToolOutput } = useAgentChat({ agent });
// Render approval-requested message parts and call this from the user's choice:
addToolApprovalResponse({ id: approvalId, approved: true });
// Use approved: false to deny. approvalId is the tool part's approval.id.
```

For a client-executed tool, report an execution error using the object API:

```tsx
addToolOutput({
  toolName,
  toolCallId,
  state: "output-error",
  errorText: "User rejected this action"
});
```

## Important

- `waitForApproval` throws on rejection or timeout — handle those failures
- `addToolOutput` with `output-error` does NOT auto-continue the LLM — you may need `sendMessage` after
- OpenAI Agents SDK is a separate SDK; use its own approval documentation.
