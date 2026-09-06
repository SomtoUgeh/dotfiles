# Browse the Web (Experimental)

Fetch https://developers.cloudflare.com/agents/api-reference/browse-the-web/ for complete documentation.

CDP-powered browser tools that let agents scrape, screenshot, and interact with web pages.

## Setup

```jsonc
// wrangler.jsonc
{
  "browser": { "binding": "BROWSER" },
  "worker_loaders": [{ "binding": "LOADER" }],
  "compatibility_flags": ["nodejs_compat"]
}
```

Export the codemode runtime from your Worker entry module:

```typescript
export { CodemodeRuntime } from "@cloudflare/codemode";
```

## Usage with AI SDK

```typescript
import { createBrowserTools } from "agents/browser/ai";

export class MyAgent extends AIChatAgent<Env> {
  async onChatMessage(
    onFinish: Parameters<AIChatAgent<Env>["onChatMessage"]>[0],
    options: Parameters<AIChatAgent<Env>["onChatMessage"]>[1]
  ) {
    const browserTools = createBrowserTools({
      browser: this.env.BROWSER,
      loader: this.env.LOADER
    });

    const result = streamText({
      model: openai("gpt-4o"),
      messages: await convertToModelMessages(this.messages),
      tools: { ...myTools, ...browserTools },
      abortSignal: options?.abortSignal,
      onFinish
    });
    return result.toUIMessageStreamResponse();
  }
}
```

## Available Tools

| Tool | Purpose |
|------|---------|
| `browser_execute` | Run code that navigates and interacts with pages through CDP |
| `browser_markdown` | Convert a page to Markdown |
| `browser_extract` | Extract structured data from a page |
| `browser_links` | List links from a page |
| `browser_scrape` | Extract matching elements from a page |

The LLM writes an async JavaScript arrow function for `browser_execute`. Each execution gets a fresh browser session by default. The other tools use Browser Run Quick Actions and require a browser binding with Quick Actions support (compatibility date `2026-03-24` or later).

## When to Use

- Need a real browser (JS rendering, screenshots, interaction) → browser tools
- Just need HTML/API data → use `fetch()` instead (faster, cheaper)

## Low-Level API

```typescript
import { connectBrowser } from "agents/browser";

const cdp = await connectBrowser(this.env.BROWSER);
try {
  const target = await cdp.send("Target.createTarget", { url: "about:blank" });
  if (!target || typeof target !== "object" ||
      !("targetId" in target) || typeof target.targetId !== "string") {
    throw new Error("Browser did not return a target ID");
  }
  const sessionId = await cdp.attachToTarget(target.targetId);
  await cdp.send("Page.navigate", { url: "https://example.com" }, { sessionId });
} finally {
  cdp.close();
}
```

`connectBrowser` opens a browser-level connection. Page commands need the session ID returned by attaching to a target; navigation does not itself wait for the page to finish loading.
