---
title: Vercel AI Gateway
description: Reference for using Vercel AI Gateway with the AI SDK.
---

# Vercel AI Gateway

The Vercel AI Gateway is the fastest way to get started with the AI SDK. It provides access to models from OpenAI, Anthropic, Google, and other providers through a single API.

## Authentication

Authenticate with OIDC (for Vercel deployments) or an [AI Gateway API key](https://vercel.com/d?to=%2F%5Bteam%5D%2F%7E%2Fai-gateway%2Fapi-keys&title=AI+Gateway+API+Keys):

```env filename=".env.local"
AI_GATEWAY_API_KEY=your_api_key_here
```

## Usage

The AI Gateway is the default global provider, so you can access models using a simple string:

```ts
import { generateText } from 'ai';

const modelId = process.env.AI_GATEWAY_MODEL;
if (!modelId) throw new Error('AI_GATEWAY_MODEL is required');

const { text } = await generateText({
  model: modelId,
  prompt: 'What is love?',
});
```

You can also explicitly import and use the gateway provider:

```ts
const modelId = process.env.AI_GATEWAY_MODEL;
if (!modelId) throw new Error('AI_GATEWAY_MODEL is required');

// Option 1: Import from 'ai' package (included by default)
import { gateway } from 'ai';
model: gateway(modelId);

// Option 2: Install and import from '@ai-sdk/gateway' package
import { gateway } from '@ai-sdk/gateway';
model: gateway(modelId);
```

## Find Available Models

**Important**: Always fetch the current model list before writing code. Never use model IDs from memory - they may be outdated.

List all available models through the gateway API:

```bash
curl https://ai-gateway.vercel.sh/v1/models
```

Filter by provider using `jq`. **Do not truncate with `head`** - always fetch the full list to find the latest models:

```bash
# Anthropic models
curl -s https://ai-gateway.vercel.sh/v1/models | jq -r '[.data[] | select(.id | startswith("anthropic/")) | .id] | reverse | .[]'

# OpenAI models
curl -s https://ai-gateway.vercel.sh/v1/models | jq -r '[.data[] | select(.id | startswith("openai/")) | .id] | reverse | .[]'

# Google models
curl -s https://ai-gateway.vercel.sh/v1/models | jq -r '[.data[] | select(.id | startswith("google/")) | .id] | reverse | .[]'
```

Choose a model that supports the task's required capabilities and is available to
the project. Preserve the user's provider and model choice when one is already
configured; do not replace it merely because another identifier sorts later.
