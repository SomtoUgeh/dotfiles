# Add a Script

Read [using scripts](../references/using-scripts.md) and [executable helpers](../references/executable-code.md).

Resolve the target skill and operation from existing context. Inspect the relevant files and search for an existing maintained helper before building.

1. Define inputs, outputs, side effects, dependencies, and failure/cleanup behavior.
2. Add the smallest complete helper under `scripts/`. Validate paths and arguments before writes; preserve prior results on failure.
3. Use `uv run` for Python and the project's existing runtime elsewhere. Document the actual invocation and working-directory requirements.
4. Link the helper from the entrypoint and workflow. Explain which output and exit status prove success.
5. Run isolated valid, invalid, repeat, and failure cases appropriate to the operation. Check that secrets are not logged.

Complete when the workflow calls the helper correctly and its behavior is verified. Installing a script does not authorize a live deployment or account mutation.
