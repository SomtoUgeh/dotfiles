# Workers AI configuration

```jsonc
{
  "name": "ai-example",
  "main": "src/index.ts",
  "compatibility_date": "2026-09-05",
  "ai": { "binding": "AI", "remote": true },
  "vectorize": [
    { "binding": "VECTORIZE", "index_name": "documents", "remote": true }
  ]
}
```

Omit Vectorize when retrieval is not required. Its configuration is an array, not `{ bindings: [...] }`. Redeclare bindings for named environments. Generate types with `wrangler types`, then use `env.AI`; the old `@cloudflare/ai` wrapper is unnecessary.

```bash
wrangler types
wrangler dev
```

AI inference remains remote and billable during local Worker development. Use mocks for offline tests. `remote: false` does not supply a local inference engine.

## External clients

Use the server-side account endpoint `https://api.cloudflare.com/client/v4/accounts/{accountId}/ai/v1` for OpenAI-compatible chat-completion/embedding clients. Configure the SDK provider once with this base URL and the Cloudflare API token, then select an actual Cloudflare model ID. Do not send `gpt-3.5-turbo` or assume the Responses API is supported merely because the client defaults to it.

For Vercel AI SDK, use the current [Cloudflare integration](https://developers.cloudflare.com/workers-ai/configuration/ai-sdk/) and installed provider version. If using `@ai-sdk/openai`, configure `createOpenAI({ baseURL, apiKey })` and explicitly select its chat-completions model API where needed; `openai(model, { baseURL })` is not the provider configuration API. The native-binding provider is another supported integration and avoids distributing a REST token.

Keep API credentials on the server with least-privilege permissions listed by the chosen operation. Never place them in public environment variables or browser bundles.

[Local development](https://developers.cloudflare.com/workers/local-development/) · [OpenAI compatibility](https://developers.cloudflare.com/workers-ai/configuration/open-ai-compatibility/)
