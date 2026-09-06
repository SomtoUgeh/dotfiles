---
title: AI SDK DevTools
description: Debug AI SDK calls by inspecting captured runs and steps.
---

# AI SDK DevTools

DevTools is experimental and intended for local development. It captures AI SDK calls in a local JSON file and exposes a browser viewer for requests, responses, tool calls, token use, and multi-step runs.

## Compatibility

Inspect the installed `ai` and `@ai-sdk/devtools` packages before configuring it. The current DevTools line uses the AI SDK 7 telemetry integration and requires Node.js 22 or newer. Some published DevTools documentation may target an AI SDK 7 canary; confirm `registerTelemetry`, `DevToolsTelemetry`, and the runtime engine in the installed package instead of assuming compatibility from the major number alone.

Add the package with the project's package manager only when the user authorized dependency changes. Keep it in development tooling and do not initialize it in production code.

## Register telemetry

Register the integration once in the development process before AI SDK calls run:

```ts
import { DevToolsTelemetry } from '@ai-sdk/devtools';
import { registerTelemetry } from 'ai';

if (process.env.NODE_ENV === 'development') {
  registerTelemetry(DevToolsTelemetry());
}
```

For a single call, pass the integration through that call's `telemetry.integrations` option when the installed AI SDK types expose it. Do not wrap every model with the legacy `devToolsMiddleware()` setup when the telemetry integration is available.

## View captured data

Run the installed DevTools executable from the same workspace as the application. If it is not installed, add or execute a pinned compatible version only with dependency authorization.

The viewer listens on `http://localhost:4983` by default. Captured runs are stored locally in:

```text
.devtools/generations.json
```

Treat that file as sensitive development data: prompts, outputs, tool inputs, and provider metadata may contain secrets or personal information. Keep it out of version control and remove it according to the project's retention policy.

## Verify

1. Start the application in its Node.js development runtime.
2. Make one known AI SDK request.
3. Confirm the viewer records one run with its steps and tool calls.
4. Confirm production builds do not register DevTools or package captured data.
