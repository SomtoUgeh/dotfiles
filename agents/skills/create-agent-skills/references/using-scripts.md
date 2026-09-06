# Using Scripts

Place a reusable helper in `scripts/`. Give it a single concrete responsibility, validated arguments, documented outputs, and explicit failures. Prefer an existing maintained command when it already provides the operation.

For shell, use an appropriate interpreter and check failures; `set -euo pipefail` is useful but does not replace explicit handling. For Python, use `uv run` and declare dependencies. Inspect any shared script before first execution.

Link the actual script from the entrypoint and the relevant workflow. Explain when it runs, which inputs it receives, and which result proves success. Resolve from the discovered skill path so it works from an unrelated working directory.

A script file is not permission to deploy, publish, or modify an external account. Preserve the user's task authorization and distinguish read-only checks from writes.

Test invalid input, missing dependencies, interrupted operations, repeated execution, and cleanup failures where applicable. Use disposable local fixtures before a live integration. See [executable-code.md](executable-code.md) and [api-security.md](api-security.md).
