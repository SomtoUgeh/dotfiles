# Workers AI troubleshooting

- **Retired model:** inspect the current catalog. `@cf/meta/llama-3.1-8b-instruct` was deprecated May 30, 2026; select and test a supported replacement, such as the currently listed FP8 variant, rather than retrying forever.
- **Local development misconception:** `wrangler dev` supports remote AI bindings. Inference uses real account resources; `--remote` is not required for the whole Worker.
- **Binding missing:** check the exact environment configuration and regenerate types. A Vectorize binding is configured as an array.
- **Broken SSE:** native text streams contain already-framed SSE bytes, not `{ response }` chunk objects. Forward them or use a proper parser.
- **Wrong response shape:** distinguish native binding, REST envelope, OpenAI-compatible JSON, and binary models. Validate external JSON and handle absent output.
- **Tool failures:** model support and schemas vary; there is no fixed “only these two model families support tools” rule. Validate names, arguments, authorization, and loop limits.
- **Unexpected latency/cost:** cold-start time, context size, batch size, output length, and model load vary. Do not promise a 1–3 second first call or fixed neurons per request.
- **Error code mismatch:** use the [current error table](https://developers.cloudflare.com/workers-ai/platform/errors/) and structured status, not a copied mapping or substring test against an arbitrary error message.
- **Context rejected:** limits are model-specific and not universally 2K–8K. Bound inputs/output and inspect the selected model's context window.
- **SDK endpoint mismatch:** configure the provider's base URL and compatible API family; a default Responses request may not match Workers AI's chat-completions endpoint.

[Catalog](https://developers.cloudflare.com/workers-ai/models/) · [Limits](https://developers.cloudflare.com/workers-ai/platform/limits/) · [Pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/)
