# Testing and Iteration

## Establish coverage

List supported tasks, resources, runtimes, and external dependencies. Separate structural validation, semantic review, local execution, and live integration. A file read is not an end-to-end test.

## Evaluate a workflow

1. Select a representative user request and define the expected observable result.
2. Use a disposable fixture with known input and record relevant versions.
3. Run the workflow with the declared resources, including resource discovery.
4. Exercise a meaningful invalid-input or failure path.
5. Compare observed output and side effects with the expectation.
6. Fix the demonstrated defect and rerun affected checks.

For prompt-only workflows, test route selection, instruction consistency, missing-input handling, and output against a rubric. A scripted parser check cannot prove that a fresh agent follows the prose. Use a fresh agent/harness when available and identify it honestly.

## Supported runtimes

Use the configured models and available tools. Do not choose a provider-specific model matrix by habit. If a harness, device, account, service, or project is unavailable, record that specific test as unverified. Never manufacture a success rate from a few illustrative examples.

## Completion

Report cases run, failures repaired, and remaining gaps. Recheck version-sensitive guidance when applying it to a real project. Commit only when authorized; a testing workflow does not independently authorize a commit or publication.
