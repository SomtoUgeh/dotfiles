# skills-mcp

One skills library for every agent, served from `https://mcp.julds.com`.
The source is `agents/skills` in this repository (including its `p3-stack`
links). Edit a skill there and push to `main`; the
[skills-mcp workflow](../../.github/workflows/skills-mcp.yml) deploys it.

## What it serves

| Path | For |
| ---- | --- |
| `/mcp` | MCP server (stateless Streamable HTTP). Tools `search_skills`, `read_skill`, `list_skill_files`, plus the MCP Skills extension (SEP-2640): `skills/list`, `skills/get`, and `skill://<name>/<path>` resources. |
| `/.well-known/agent-skills/index.json` | Agent Skills Discovery index (RFC draft v0.2.0), with `version` and `files` for Executor. |
| `/.well-known/agent-skills/<name>/<path>` | Every skill file, for clients and scripts that need them on disk. |
| `/.well-known/agent-skills/executor-N-index.json` | The same index split in three shards: Executor reads at most 1,000 files per index. |

## Executor

The Executor app `Skills` (slug `skills`, source in `executor-app/`) loads
the shards with `wellKnownSkills` and imports the MCP tools with `mcpRouter`.
Every Executor client then reads skills with the `skills` MCP tool
(`{app: "skills", name: "<skill>"}`) or calls `tools.skills.search_skills`.
Executor checks the index every 5 minutes, so the app needs no redeploy when
skills change. Redeploy it only when `executor-app/` changes or the shard count
changes (keep `SHARDS` equal to `EXECUTOR_SHARDS` in `src/config.ts`).

## Commands

```sh
bun install
bun run build    # dist/assets and src/generated/catalog.json from agents/skills
bun run check    # TypeScript
bun test         # unit tests, plus Executor's loader and the MCP endpoint on the build
bun run deploy   # all of the above, then wrangler deploy
```

The build includes only git-tracked UTF-8 files, skips binaries and symlinks,
and fails when any skill would be refused by Executor's `fileSkill` or the MCP
SDK's `skillEntry`. One invalid skill would otherwise fail a whole catalog.

The workflow needs the repository secret `CLOUDFLARE_API_TOKEN` (Workers
Scripts Edit and Workers Routes Edit on julds.com, for this account).
