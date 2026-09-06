# Documentation checks for implementation

Use these checks when adding or upgrading a dependency, integrating a service,
changing an external contract, or diagnosing missing exports, unknown options,
deprecations, or changed defaults. A small local edit whose contract is fully
defined by nearby code and tests does not need an unrelated research exercise.

## Establish the contract

- Identify the actual package, installed version, runtime, API version, CLI
  command, or local interface. Read the lockfile and existing usage before
  choosing examples.
- Read repository specs, ADRs, generated schemas, and types for internal
  contracts; read official API references, migration guides, changelogs, and
  SDK source for third-party behavior. Open the relevant source rather than
  relying on a search-result summary.
- For new dependencies or upgrades, verify registry versions and release
  channels. A `latest` tag may point to a different major or preview. Check
  compatible SDK, adapter, runtime, and peer-dependency versions together.
  Researching a version does not authorize installing or upgrading it.
- Match examples to the installed version or the user's explicit upgrade
  target. Record the imports, option names, return types, lifecycle behavior,
  defaults, and breaking changes the implementation actually depends on.

## Apply and verify

For auth, permissions, secrets, webhooks, billing, migrations, retry behavior,
or deployment changes, verify the specific operational contract before editing.
For example: raw-body requirements for webhook verification, migration data
effects, and whether a command targets local or remote state.

If docs and code disagree, inspect the installed types/source and a minimal
reproduction. Explain a material discrepancy; do not copy a modern example
into an older project without an authorized migration.

A current website can be ahead of its published package. Check the official
documentation at the package's release tag and test the actual command or
export. Prefer a verified released procedure over a speculative workflow that
only tells the user to wait for missing commands. Keep fresh schema setup,
schema changes, and populated-data upgrades separate; they may require
different preparation even when the CLI command has the same name.

For Stripe, read [the compatibility reference](stripe-compatibility.md) with
the native Stripe skill. Shared corrections live here rather than in installed
plugin caches, so plugin updates do not erase them.

Use the smallest meaningful check for the changed contract: typecheck, focused
test, build, documented dry run, schema validation, or local reproduction.
Report the evidence and any unverified behavior. Do not install tools, mutate a
service, or create research documents merely to answer a question.
