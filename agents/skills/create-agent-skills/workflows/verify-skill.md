# Verify Skill Accuracy and Behavior

Read [testing](../references/iteration-and-testing.md). Use the target already named by the user.

## Inventory

Read the entire declared scope and list verifiable claims: commands/flags, API methods, versions, paths, workflow decisions, and expected outputs. Track file reads and actual execution separately.

## Check contracts

- CLI: locate it, read current help/version, and run a disposable example. Help output alone does not prove behavior.
- Package/API: inspect the project's lockfile and released types/source; compare matching primary documentation. A website can be ahead of the published package.
- Integration: test a local fixture first, then a live account only within authorization. Mark absent credentials, devices, and real-project prerequisites as unverified.
- Prompt workflow: test route selection, relevant resource loading, output requirements, and error/permission handling with representative scenarios. Use a fresh available agent/harness for execution evidence when practical.

Use tools actually exposed by the active runtime. Do not assume a Context7 method name or install a tool merely to answer an informational question.

## Reconcile

Classify each check as passed, failed, or unverified, with evidence and versions. Fix demonstrated defects within existing authorization and retest affected cases. Do not convert a failed or omitted check into a fresh/clean overall verdict.

Complete when the claimed coverage matches the work performed. Recheck version-sensitive instructions when applying them to a particular project; periodic review alone cannot guarantee future compatibility.
