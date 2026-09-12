---
name: ai-sdk
description: "Explain, implement, or debug Vercel AI SDK features: generation, streaming, tools, structured output, embeddings, agents, and React chat hooks."
---

## Prerequisites

This information targets AI SDK 7. If the project has the package installed,
compare against `node_modules/ai/package.json` and use documentation matching
that version.

Before searching remote docs, check whether `node_modules/ai/docs/` exists. If
it does not, use the official versioned documentation at `ai-sdk.dev`. Do not
change project dependencies merely to obtain documentation.

Install `ai`, provider packages, or client packages only when implementation
requires them and the user's request authorizes adding that functionality. Use
the project's existing package manager and version policy.

## Critical: Do Not Trust Internal Knowledge

Everything you know about the AI SDK is outdated or wrong. Your training data contains obsolete APIs, deprecated patterns, and incorrect usage.

**When working with the AI SDK:**

1. Identify the installed AI SDK version, or the requested target version
2. Search `node_modules/ai/docs/` and `node_modules/ai/src/` for current APIs
3. If not found locally, search ai-sdk.dev documentation (instructions below)
4. Never rely on memory - always verify against source code or docs
5. **`useChat` has changed significantly** - check [Common Errors](references/common-errors.md) before writing client code
6. Preserve the project's existing provider and gateway unless the user asks to
   change it. If no provider has been chosen, compare the task's capability,
   data-handling, deployment, latency, and cost requirements before recommending
   one. Use [AI Gateway Reference](references/ai-gateway.md) only when Gateway is
   already in use or chosen for a stated reason.
7. Verify current model IDs against the selected provider's official catalog.
   When Vercel AI Gateway is selected, its `/v1/models` endpoint is one useful
   source. Do not infer recency from response order or choose the numerically
   highest ID automatically; select a stable model that supports the required
   tools, modalities, context, and structured-output behavior.
8. Run typecheck after changes to ensure code is correct
9. **Be minimal** - Only specify options that differ from defaults. When unsure of defaults, check docs or source rather than guessing or over-specifying.

If you cannot find documentation to support your answer, state that explicitly.

## Finding Documentation

### ai@6.0.34+

Search bundled docs and source in `node_modules/ai/`:

- **Docs**: `rg "query" node_modules/ai/docs/`
- **Source**: `rg "query" node_modules/ai/src/`

Provider packages include docs at `node_modules/@ai-sdk/<provider>/docs/`.

### Earlier versions

1. Search: `https://ai-sdk.dev/api/search-docs?q=your_query`
2. Fetch `.md` URLs from results (e.g., `https://ai-sdk.dev/docs/agents/building-agents.md`)

## When Typecheck Fails

**Before searching source code**, grep [Common Errors](references/common-errors.md) for the failing property or function name. Many type errors are caused by deprecated APIs documented there.

If not found in common-errors.md:

1. Search `node_modules/ai/src/` and `node_modules/ai/docs/`
2. Search ai-sdk.dev (for earlier versions or if not found locally)

## Building and Consuming Agents

### Creating Agents

Use `ToolLoopAgent` for iterative tool-using agents when the installed version
documents it as the appropriate abstraction. Simpler generation or a fixed tool
sequence may use a smaller API. Verify the current agent APIs before choosing.

**File conventions**: See [type-safe-agents.md](references/type-safe-agents.md) for where to save agents and tools.

**Type Safety**: When consuming agents with `useChat`, always use `InferAgentUIMessage<typeof agent>` for type-safe tool results. See [reference](references/type-safe-agents.md).

### Consuming Agents (Framework-Specific)

Before implementing agent consumption:

1. Check `package.json` to detect the project's framework/stack
2. Search documentation for the framework's quickstart guide
3. Follow the framework-specific patterns for streaming, API routes, and client integration

## References

- [Common Errors](references/common-errors.md) - Renamed parameters reference (parameters → inputSchema, etc.)
- [AI Gateway](references/ai-gateway.md) - Gateway setup and usage
- [Type-Safe Agents with useChat](references/type-safe-agents.md) - End-to-end type safety with InferAgentUIMessage
- [DevTools](references/devtools.md) - Set up local debugging and observability (development only)
