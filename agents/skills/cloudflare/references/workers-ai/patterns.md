# Workers AI patterns

## Retrieval-augmented generation

Embed the query, retrieve authorized vectors/documents, bound the context, and then generate. Use the tenant-aware [Vectorize patterns](../vectorize/patterns.md) for retrieval. Current Vectorize metadata options are `"none"`, `"indexed"`, and `"all"`, not `true`.

Treat retrieved text as untrusted source material. Keep application instructions separate, cite sources when the product needs provenance, and validate any proposed action independently. RAG improves access to source material but does not guarantee factual answers or solve authorization.

## Tools and structured output

Choose a model explicitly supporting the tool or structured-output feature. Native Workers AI and OpenAI-compatible tool-call shapes may differ; validate the actual schema, every tool name, argument object, and authorization before dispatch. Bound the tool loop and handle zero/multiple calls and malformed output. Never execute an arbitrary model-supplied function or blindly `JSON.parse` an assumed first call.

Use a supported JSON/schema mode when available and validate the result. A prompt requesting valid JSON is not a schema guarantee. Temperature zero can reduce variation but does not promise identical output.

## Retry, fallback, and cost

Classify errors using documented status/codes. Retry only transient failures with bounded exponential backoff/jitter and a deadline; respect Retry-After when present. Do not retry validation, authorization, or retired-model errors as though they were throttling. Retrying a partially delivered stream may duplicate visible output.

Fallback models must be explicitly configured and satisfy the same schema, capability, privacy, and quality requirements. Do not switch silently on every exception. Compare actual token/usage accounting and the current model price, not guessed per-request neurons.

Use bounded concurrency for independent inference and batch embeddings within model limits. Cache only responses whose sharing is allowed; include tenant/authorization scope, model/version, prompt inputs, and relevant generation settings in the key. AI Gateway caching does not make personalized responses safe to share.

For SSE, pass through the stream as shown in [api.md](api.md); avoid a second framing loop and unhandled background producer promises.
