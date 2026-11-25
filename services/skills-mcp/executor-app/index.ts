// Executor app "Skills": serves the mcp.julds.com library through Executor's
// `skills` MCP tool, and its search/read tools as tools.skills.*.
// Deploy: see ../README.md. Keep SHARDS equal to EXECUTOR_SHARDS in ../src/config.ts.
import { defineApp, dynamicSkills } from "apps";
import { mcpRouter } from "apps/mcp";
import { wellKnownSkills } from "apps/skills";

const ORIGIN = "https://mcp.julds.com";
const SHARDS = 3;

export default defineApp({}, async (ctx) => ({
  tools: await mcpRouter(
    { url: `${ORIGIN}/mcp`, cache: ctx.cache, signal: ctx.signal },
    { search_skills: "query", read_skill: "query", list_skill_files: "query" },
  ),
  dynamicSkills: dynamicSkills({
    list: async () => {
      const shards = await Promise.all(
        Array.from({ length: SHARDS }, (_, shard) =>
          wellKnownSkills({
            url: `${ORIGIN}/.well-known/agent-skills/executor-${shard + 1}-index.json`,
            fetch: ctx.fetch,
            signal: ctx.signal,
            cache: ctx.cache,
          }),
        ),
      );
      return shards.flat();
    },
  }),
}));
