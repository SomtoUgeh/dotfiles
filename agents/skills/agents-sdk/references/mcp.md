# MCP Integration

Fetch https://developers.cloudflare.com/agents/api-reference/mcp-client-api/ and https://developers.cloudflare.com/agents/api-reference/mcp-agent-api/ for complete documentation.

Agents include a multi-server MCP client for connecting to external MCP servers and `createMcpHandler` for building new stateless MCP servers. `McpAgent` is a deprecated, feature-frozen path for existing stateful servers.

## Add an MCP Server

```typescript
import { Agent, callable } from "agents";

export class MyAgent extends Agent<Env, State> {
  @callable()
  async addServer(name: string, url: string) {
    // Options-based API (recommended)
    const result = await this.addMcpServer(name, url, {
      callbackHost: "https://my-worker.workers.dev",
      transport: { headers: { Authorization: "Bearer ..." } }
    });

    if (result.state === "authenticating") {
      // OAuth required - redirect user to result.authUrl
      return { needsAuth: true, authUrl: result.authUrl };
    }

    return { ready: true, id: result.id };
  }
}
```

## Use MCP Tools

```typescript
async onChatMessage() {
  // Get AI-compatible tools from all connected MCP servers
  const mcpTools = this.mcp.getAITools();
  
  const allTools = {
    ...localTools,
    ...mcpTools
  };

  const result = streamText({
    model: openai("gpt-4o"),
    messages: await convertToModelMessages(this.messages),
    tools: allTools
  });
  
  return result.toUIMessageStreamResponse();
}
```

## List MCP Resources

```typescript
// List all registered servers
const servers = this.mcp.listServers();

// List tools from all servers
const tools = this.mcp.listTools();

// List resources
const resources = this.mcp.listResources();

// List prompts
const prompts = this.mcp.listPrompts();
```

## Remove Server

```typescript
await this.removeMcpServer(serverId);
```

## Building an MCP Server

New servers should use the SDK v2 factory API with `createMcpHandler` from the isolated `agents/mcp/server` entry point. A factory gives each concurrent request its own server instance and does not require a Durable Object binding or migration.

**Install dependencies:**
```bash
npm install agents @modelcontextprotocol/server@2.0.0 zod
```

**Server implementation:**
```typescript
import { McpServer } from "@modelcontextprotocol/server";
import { createMcpHandler } from "agents/mcp/server";
import { z } from "zod";

function createServer() {
  const server = new McpServer({
    name: "MyMCPServer",
    version: "1.0.0"
  });

  server.registerTool(
    "increment",
    {
      description: "Increment a value",
      inputSchema: { value: z.number(), amount: z.number().default(1) }
    },
    async ({ value, amount }) => ({
      content: [{ text: String(value + amount), type: "text" }]
    })
  );

  return server;
}

const mcpHandler = createMcpHandler(createServer);

export default {
  fetch(request: Request, env: Env, ctx: ExecutionContext) {
    return mcpHandler(request, env, ctx);
  }
} satisfies ExportedHandler<Env>;
```

### Existing stateful MCP servers

`McpAgent` from `agents/mcp` is deprecated and feature-frozen. Keep it only when an existing deployment depends on Durable Object state, resumable event storage, or legacy sessionful transports. Migrate by adding a stateless `createMcpHandler` route beside the legacy route, moving clients to it, and retiring the Durable Object only after legacy sessions drain.

Do not convert an existing `McpAgent` deployment in place without planning state and client migration. Its Durable Object binding and migration remain necessary while the legacy route is served.

## Transports

Fetch https://developers.cloudflare.com/agents/api-reference/mcp-transports/ for complete documentation.

| Transport | Use for |
|-----------|---------|
| Stateless Streamable HTTP (`createMcpHandler`) | New external/public servers (recommended) |
| `McpAgent.serve` / `serveSSE` | Existing stateful legacy servers only (deprecated) |
| RPC (`addMcpServer(name, env.Binding)`) | Same-Worker internal calls (fastest) |

### RPC Transport (Same Worker)

```typescript
async onStart() {
  await this.addMcpServer("internal-tools", this.env.MyMCPBinding, {
    props: { userId: this.name }
  });
}
```

## Retry on MCP Connections

```typescript
await this.addMcpServer("tools", url, {
  retry: { maxAttempts: 3, baseDelayMs: 500 }
});
```

## Securing MCP Servers

Fetch https://developers.cloudflare.com/agents/api-reference/securing-mcp-servers/ for complete documentation.

Use `@cloudflare/workers-oauth-provider` to add OAuth in front of your MCP server. See the securing docs for proxy patterns and `redirect_uri` validation.
