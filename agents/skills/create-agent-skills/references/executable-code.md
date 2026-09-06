# Executable Helpers

A helper is useful when a repeated operation benefits from deterministic behavior. Read unfamiliar scripts before executing them; output-only execution can save context after the script is understood.

## Contract

Document inputs, outputs, dependencies, supported environments, side effects, exit codes, and cleanup behavior. Validate before writing. Use an atomic replacement when a partial write would corrupt a prior result. Do not follow arbitrary input paths outside a declared boundary.

## Failures

Catch errors only when the program can recover or add useful context. A missing input or permission failure must not silently return an empty successful result. Include the failing operation without exposing credentials. Interrupted or partial work remains incomplete.

## Runtime

Use `uv run` for Python, with PEP 723 dependencies for standalone scripts when useful. Reuse the repository's existing package manager for other languages. Resolve scripts from the skill directory; do not assume the current directory. Use the actual callable MCP schema, not invented `ServerName:tool_name` identifiers.

## Verification

Run normal, malformed-input, missing-input, and side-effect failure cases in temporary fixtures. Test repeat behavior and cleanup. Confirm the workflow interprets the script's exit status and output correctly. Inspect [using-scripts.md](using-scripts.md) for integration guidance.
