---
name: agentation
description: Add Agentation visual feedback toolbar to a Next.js project
---

# Agentation Setup

Set up the Agentation annotation toolbar and, when requested, connect it to
the user's selected agent runtime. An existing import proves only that the
component was added; it does not prove that annotations reach the agent.

## Steps

1. **Inspect the project and requested scope**
   - Read project instructions, package.json, the lockfile, and existing setup.
   - Use the project's package manager and preserve the chosen agent runtime.
   - A setup/fix request authorizes the necessary project setup. For a review or
     question, inspect and report without installing packages or editing config.
   - If the user requested only the toolbar, omit MCP setup and describe the
     result as local annotations with copy/export, not agent synchronization.

2. **Check installation and existing configuration**
   - Look for `agentation` in dependencies; install only if missing, using the
     project's package manager. React and React DOM must satisfy its peer ranges
     (currently React 18 or newer).
   - Search app/, pages/, and src/ for Agentation imports and mounted components.
     Reuse the existing mount, inspect its props, and continue verification.
   - For sync, inspect the selected runtime's existing MCP entry and HTTP server
     address. Preserve working custom ports and shared-server arrangements.
     The toolbar's `endpoint` is the HTTP base URL reachable from the browser.
     `serverURL` is not the current React prop.

3. **Mount the toolbar once, only in development**
   - Detect App Router (`app/layout.*` or `src/app/layout.*`) versus Pages Router
     (`pages/_app.*` or `src/pages/_app.*`), following the project's conventions.
   - App Router: create or reuse a small client component and render it after
     children inside the root layout's body. Keep the layout as a Server Component.

   ```tsx
   "use client";

   import { Agentation } from "agentation";

   export function DevAgentation() {
     if (process.env.NODE_ENV !== "development") return null;
     return <Agentation endpoint="http://localhost:4747" />;
   }
   ```

   - Pages Router: render after the page component in `_app`:

   ```tsx
   import { Agentation } from "agentation";

   // Inside the existing render, after <Component {...pageProps} />:
   {process.env.NODE_ENV === "development" && (
     <Agentation endpoint="http://localhost:4747" />
   )}
   ```

   Replace the example URL with the verified browser-reachable address. For a
   local-only toolbar, omit `endpoint`. Do not assume browser localhost reaches
   a remote development host; use the project's existing forwarding arrangement.

4. **Configure the selected runtime's MCP server when in scope**
   - Read its current config and CLI help or official docs before editing. Add
     or repair only its Agentation entry; retain unrelated servers and settings.
   - The stdio command is `npx -y agentation-mcp server`. This starts both the
     HTTP service (default port 4747) and the agent-facing MCP service.
   - Claude example, only when Claude is the selected runtime:
     `claude mcp add agentation -- npx -y agentation-mcp server`.
   - Codex, OpenCode, and Grok: use that runtime's supported MCP registration
     mechanism. Do not run Claude's setup wizard or an all-agent installer as
     a fallback. If MCP is unsupported, report that limit with copy/export as
     the available workflow; do not silently switch providers.
   - Custom port: use `server --port <port>` and the matching toolbar endpoint.
     For an existing shared HTTP service, use
     `server --mcp-only --http-url <server-base-url>` rather than starting a
     competing listener. The MCP-side URL must be reachable from its host.

5. **Verify the complete path before claiming synchronization**
   - Run the project's focused type/build checks and inspect the toolbar in the
     development browser. Verify the development guard excludes it in production.
   - Check `/health` at the configured HTTP base URL and inspect browser network
     errors. Resolve address, forwarding, and connection errors before proceeding.
   - Reload the MCP connection or restart the selected runtime if required, then
     verify its Agentation tools are available and can list sessions.
   - In an authorized setup/fix task, create a clearly labelled test annotation
     through the toolbar, retrieve that same annotation via the runtime's MCP
     session/pending tools, and remove the test annotation afterward.
   - `npx -y agentation-mcp doctor` is supplemental: version 1.2.0 checks Claude
     config and localhost:4747. It does not validate other runtimes, custom ports,
     or browser-to-agent delivery. Use direct checks for the actual configuration.
   - Report what passed and what could not be exercised. If restart or browser
     access is unavailable, call the setup configured but synchronization unverified.
     An import, config entry, or healthy HTTP server alone is insufficient.

## Sources

- [Agentation API](https://www.agentation.com/api): `endpoint` and HTTP routes.
- [Agentation MCP](https://www.agentation.com/mcp): server command, options, and tools.
- Published `agentation` 3.0.2 types: omitted `endpoint` uses localStorage only.
- Published `agentation-mcp` 1.2.0 CLI: `doctor` scope and server flags. Recheck
  installed package types/help when upgrading; do not assume examples prove support.
