---
name: agentation
description: Add Agentation visual feedback toolbar to a Next.js project
---

# Agentation Setup

Set up the Agentation annotation toolbar in this project.

## Steps

1. **Check if already installed**
   - Look for `agentation` in package.json dependencies
   - If not found, run `npm install agentation` (or pnpm/yarn based on lockfile)

2. **Check if already configured**
   - Search for `<Agentation` or `import { Agentation }` in src/ or app/
   - If found, report that Agentation is already set up and exit

3. **Detect framework**
   - Next.js App Router: has `app/layout.tsx` or `app/layout.js`
   - Next.js Pages Router: has `pages/_app.tsx` or `pages/_app.js`

4. **Add the component**

   For Next.js App Router, add to the root layout:
   ```tsx
   import { Agentation } from "agentation";

   // Add inside the body, after children:
   {process.env.NODE_ENV === "development" && <Agentation />}
   ```

   For Next.js Pages Router, add to _app:
   ```tsx
   import { Agentation } from "agentation";

   // Add after Component:
   {process.env.NODE_ENV === "development" && <Agentation />}
   ```

5. **Confirm component setup**
   - Tell the user the Agentation toolbar component is configured

6. **Check if MCP server already configured**
   - Check the active agent runtime's MCP configuration for an `agentation` server
   - If yes, skip to final confirmation step

7. **Configure MCP server**
   - Register the MCP server command: `npx agentation-mcp server`
   - Claude example: `claude mcp add agentation -- npx agentation-mcp server`
   - For Codex and OpenCode, use the runtime's MCP config format and verify against its current docs before editing config

8. **Confirm full setup**
   - Tell the user both components are set up:
     - React component for the toolbar (`<Agentation />`)
     - MCP server configured to auto-start with the active agent runtime
   - Tell user to restart the active agent runtime to load the MCP server
   - Explain that annotations will now sync to the agent automatically

## Notes

- The `NODE_ENV` check ensures Agentation only loads in development
- Agentation requires React 18
- The MCP server auto-starts when the configured agent runtime launches (uses npx, no global install needed)
- Port 4747 is used by default for the HTTP server
- Run `npx agentation-mcp doctor` to verify setup
