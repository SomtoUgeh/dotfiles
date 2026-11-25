export const ORIGIN = "https://mcp.julds.com";
export const SKILLS_PATH = "/.well-known/agent-skills";
export const SKILL_URI_BASE = "skill://";
export const DISCOVERY_SCHEMA = "https://schemas.agentskills.io/discovery/0.2.0/schema.json";

// Executor's wellKnownSkills reads at most 1,000 files per index. Each skill
// stays in the shard its name hashes to, so a cached shard never lists a skill
// that a fresher shard also lists. Changing the count also changes the
// Executor app in executor-app/index.ts.
export const EXECUTOR_SHARDS = 3;
export const EXECUTOR_SHARD_FILE_LIMIT = 1000;

export const executorShardFile = (shard: number): string => `executor-${shard + 1}-index.json`;
