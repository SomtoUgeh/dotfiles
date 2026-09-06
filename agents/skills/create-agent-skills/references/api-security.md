# API Credentials and Authorization

Prefer the user's configured connector, credential provider, or official CLI. Discover its actual capabilities before authoring calls. Do not invent global helpers, profile stores, or a shared credential file.

## Credential handling

A literal shell variable in a tool request is not inherently expanded in chat. Exposure depends on shell tracing, process arguments, error logs, and tool output. A wrapper alone does not remove those risks.

- Read secrets through the configured provider or environment inside the client process. Never print their values or enable tracing around them.
- Use the client's supported secret input mechanism. Avoid raw secrets in command arguments, URLs, committed files, and generated artifacts.
- Check for missing or empty credentials without logging their contents.
- Never use `eval` to select a credential variable from a profile name.
- Do not create or modify global credential stores as a side effect of writing a skill.
- Use the account/project already selected for the task. Ask only when the target is materially ambiguous.

## Request behavior

Document the real API version, authentication method, method/path, input validation, timeout, and success/error schema. Check HTTP status and application success fields. Handle pagination, rate limits, and partial results explicitly. Retry writes only when the API provides safe idempotency or after reconciling the outcome.

Read-only discovery does not authorize publishing or messaging others. Preserve existing authorization for requested writes; prepare the concrete result before any genuinely necessary approval.

## Tests

Use dummy credentials and a local mock for success, invalid credentials, timeout, malformed response, rate limiting, and cleanup failure. Verify secrets stay out of captured stdout/stderr and artifacts. A mock proves client behavior, not live account permissions or service acceptance; record those as separate checks.
