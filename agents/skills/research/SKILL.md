---
name: research
description: Investigate questions using authoritative sources, including version-specific documentation checks for implementation, integrations, upgrades, and API-drift debugging.
---

# Research

Investigate the user's question against the sources that own the facts: official documentation, specifications, source code, first-party APIs, or original research. Trace material claims to direct citations and distinguish source facts from inference.

For implementation, integration, upgrades, or errors suggesting API drift, read
[implementation documentation checks](references/implementation-docs.md).
That reference adds contract and version verification to this workflow; it is
not a second research process.

1. Define the question and the facts needed to answer it. Inspect repository
   docs, schemas, types, and tests for project-specific behavior.
2. For current or external behavior, read official documentation and release
   information for the relevant version. Use primary source code or types to
   resolve missing or contradictory documentation. Follow the active runtime's
   browsing requirements and the user's requested sources.
3. Compare evidence with the local implementation. Separate confirmed facts,
   inference, and unresolved questions; do not silently mix release channels
   or documentation for different major versions.
4. Return the answer with direct source links and material limitations. If a
   source is unavailable, use accessible primary evidence and identify what
   remains unverified rather than presenting memory as confirmed-current.

Return the findings in the conversation by default. Create or modify a repository document only when the user asks for an artifact or an established task explicitly requires one; then use the repository's existing location and format.

Use background or parallel agents only when the active runtime and session permit delegation and the research has independent branches that justify it. The main agent remains responsible for source quality, contradictions, and the final synthesis.
