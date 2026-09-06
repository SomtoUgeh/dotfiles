# Playground troubleshooting

| Symptom | Diagnosis |
| --- | --- |
| Safari `PreviewRequestFailed` | Current official support is desktop Chrome/Firefox |
| TypeScript parse errors | Use JavaScript/JSDoc or compile locally |
| Missing binding/secret | Use a configured local/deployed Worker; do not hardcode secrets |
| Body already consumed | Read once or clone before the first read |
| Relative redirect fails | Resolve against `request.url` before `Response.redirect` |
| GET request with body fails | Set the correct HTTP method and body combination |
| Cache never hits | Cache API operations have no effect in Playground previews |
| Logs absent from webpage DevTools | Use the preview Worker log viewer |
| Background work still exceeds CPU | `waitUntil` does not increase compute limits |

Use the [current Workers limits](https://developers.cloudflare.com/workers/platform/limits/)
for the selected account/runtime. Do not infer every Playground quota from a Free
plan label or copy conflicting paid subrequest limits into the same guide.

Test success, missing route, wrong method, invalid JSON, and upstream failure.
Return generic errors to clients; log only the information needed for diagnosis.
A successful preview proves the tested request in that preview configuration,
not production bindings, secrets, caching, or deployment behavior.

Sources: [Playground](https://developers.cloudflare.com/workers/playground/),
[Cache API](https://developers.cloudflare.com/workers/runtime-apis/cache/).
