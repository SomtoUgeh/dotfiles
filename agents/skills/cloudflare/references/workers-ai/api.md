# Workers AI API

Model input/output schemas differ. Use generated types with literal model IDs and consult the selected model page, rather than assuming every model accepts identical tool, image, audio, or text fields.

## Text and streaming

```typescript
const output = await env.AI.run("@cf/meta/llama-3.1-8b-instruct-fp8", {
  messages: [{ role: "user", content: "Describe edge computing." }],
  max_tokens: 128,
});
```

```typescript
const stream = await env.AI.run("@cf/meta/llama-3.1-8b-instruct-fp8", {
  messages: [{ role: "user", content: "Describe edge computing." }],
  stream: true, max_tokens: 128,
});
return new Response(stream, {
  headers: { "Content-Type": "text/event-stream", "Cache-Control": "no-store" },
});
```

The stream is already SSE-formatted bytes. Do not access `chunk.response` on its byte chunks or JSON-wrap each chunk into another SSE frame. If transforming, use a real incremental SSE parser and propagate cancellation/errors.

## Embeddings

```typescript
const embeddings = await env.AI.run("@cf/baai/bge-base-en-v1.5", {
  text: ["Query", "Document one", "Document two"],
});
if (!("data" in embeddings) || !embeddings.data) throw new Error("Expected synchronous embeddings");
const queryVector = embeddings.data[0];
if (!queryVector) throw new Error("Missing embedding");
```

This model produces 768-dimensional vectors; keep index dimensions and model/preprocessing aligned. Bound batch size and text length according to the model schema.

## REST

```bash
curl --fail-with-body   "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/ai/run/@cf/meta/llama-3.1-8b-instruct-fp8"   -H "Authorization: Bearer $API_TOKEN"   -H 'Content-Type: application/json'   -d '{"messages":[{"role":"user","content":"Hello"}],"max_tokens":128}'
```

Handle HTTP status and the endpoint's documented response/error envelope. REST envelopes, native binding objects, OpenAI-compatible responses, and byte streams are different contracts. Do not cast unknown JSON directly to the desired shape.

For image/audio/translation operations, inspect the current model schema and deprecation status. Some return binary streams, others structured JSON/base64; choose the content type and body handling accordingly. Enforce upload limits before converting an entire audio body into an array.

[FP8 text model](https://developers.cloudflare.com/workers-ai/models/llama-3.1-8b-instruct-fp8/) · [Embedding model](https://developers.cloudflare.com/workers-ai/models/bge-base-en-v1.5/) · [Errors](https://developers.cloudflare.com/workers-ai/platform/errors/)
