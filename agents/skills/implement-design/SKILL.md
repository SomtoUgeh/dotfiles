---
name: implement-design
description: Implement a Figma design when the active runtime has no native Figma design-to-code skill. Use for Figma URLs or selected nodes; prefer the installed Figma plugin workflow when available.
---

# Implement a Figma Design

This is the shared fallback for runtimes without a native Figma workflow.
When selected implicitly, prefer available `figma-design-to-code` as the sole
workflow and stop reading this fallback. If the user explicitly chose this
shared skill, follow it. Respect the active Figma tool's schema and prerequisites;
do not combine two implementation checklists.

## Fallback workflow

1. Read the repository instructions and identify its framework, components,
   tokens, routes, and assets. Keep the user's requested scope.
2. Resolve the target Figma file and node from the supplied link, or use the
   desktop selection only when the connected tool supports it. Ask for a target
   only when it cannot be determined from the request.
3. Fetch design context through the available Figma tool before implementing.
   Use its documented parameter names. For large responses, narrow to relevant
   child nodes; use metadata to locate them when necessary.
4. Inspect the returned visual reference. Request a screenshot only when one
   was not included or further visual verification needs it. Use exported
   images and icons according to the tool's asset instructions; do not assume
   assets are always localhost URLs or replace them with generated substitutes.
5. Adapt reference code to the project's actual stack. Reuse mapped components,
   documented variants, and tokens. Follow design annotations; label inferred
   behavior. Resolve material conflicts between the supplied design and the
   existing product instead of silently overriding either.
6. Render and compare the implementation with the target at relevant viewport
   sizes. Verify assets, typography, spacing, interactions, focus, and responsive
   behavior. Report any accessibility-driven deviation and unverified states.

If Figma access is unavailable, work from a supplied export through
`image-to-code` when that can satisfy the request. Explain which design data is
missing rather than inventing exact tokens or hidden behavior.

## Reference

Use the [official Figma MCP documentation](https://developers.figma.com/docs/figma-mcp-server/)
for connection and tool behavior that the active schema does not explain.
