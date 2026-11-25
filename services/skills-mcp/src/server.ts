import { McpServer, type CallToolResult } from "@modelcontextprotocol/server";
import { SkillsExtension, type SkillSource } from "@modelcontextprotocol/server/ext/skills";
import { z } from "zod";
import {
  assetPath,
  hasFile,
  mimeType,
  parseSkillUri,
  searchSkills,
  skillFiles,
  type Catalog,
  type CatalogSkill,
} from "./catalog.js";

export interface AssetFetcher {
  fetch(request: Request): Promise<Response>;
}

const PAGE_SIZE = 100;

const INSTRUCTIONS = `Somto's agent skills library: one SKILL.md per skill, with optional reference files.
Before a task, call search_skills with a few task words, then read_skill for the best match and follow it.
When a skill names another of its files, read it with read_skill and that file path.
Clients with the MCP Skills extension can also use skills/list and read skill://<name>/<path> resources.`;

export const readAsset = async (assets: AssetFetcher, name: string, path: string): Promise<string | undefined> => {
  const response = await assets.fetch(new Request(`https://assets.local${assetPath(name, path)}`));
  if (response.status === 404) return undefined;
  if (!response.ok) throw new Error(`Reading ${name}/${path} returned HTTP ${response.status}.`);
  return response.text();
};

const text = (value: string): CallToolResult => ({ content: [{ type: "text", text: value }] });
const json = <T extends Record<string, unknown>>(value: T): CallToolResult => ({
  content: [{ type: "text", text: JSON.stringify(value, null, 2) }],
  structuredContent: value,
});
const failure = (message: string): CallToolResult => ({ content: [{ type: "text", text: message }], isError: true });

const notFound = (catalog: Catalog, name: string): CallToolResult => {
  const suggestions = searchSkills(catalog.skills, name, 5).map((s) => s.name);
  return failure(
    `No skill named "${name}".${suggestions.length > 0 ? ` Closest: ${suggestions.join(", ")}.` : ""} Use search_skills to find one.`,
  );
};

const skillSource = (catalog: Catalog, byName: Map<string, CatalogSkill>, assets: AssetFetcher): SkillSource => ({
  list: async ({ cursor }) => {
    const start = cursor === undefined ? 0 : Number.parseInt(cursor, 10);
    const offset = Number.isFinite(start) && start > 0 ? start : 0;
    const page = catalog.skills.slice(offset, offset + PAGE_SIZE).map((skill) => skill.entry);
    const next = offset + PAGE_SIZE;
    return next < catalog.skills.length ? { skills: page, nextCursor: String(next) } : { skills: page };
  },
  get: async (uri) => {
    const parsed = parseSkillUri(uri);
    if (parsed === undefined || parsed.path !== "SKILL.md") return undefined;
    return byName.get(parsed.name)?.entry;
  },
  read: async (uri) => {
    const parsed = parseSkillUri(uri);
    if (parsed === undefined) return undefined;
    const skill = byName.get(parsed.name);
    if (skill === undefined || !hasFile(skill, parsed.path)) return undefined;
    const content = await readAsset(assets, parsed.name, parsed.path);
    return content === undefined ? undefined : { text: content, mimeType: mimeType(parsed.path) };
  },
});

export const createServer = (catalog: Catalog, assets: AssetFetcher): McpServer => {
  const byName = new Map(catalog.skills.map((skill) => [skill.name, skill]));
  const server = new McpServer(
    { name: "julds-skills", title: "Julds skills", version: catalog.version },
    { instructions: INSTRUCTIONS },
  );
  new SkillsExtension({
    source: skillSource(catalog, byName, assets),
    cacheHint: { ttlMs: 60_000, cacheScope: "public" },
  }).attach(server);

  const readOnly = { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false };

  server.registerTool(
    "search_skills",
    {
      title: "Search skills",
      description:
        "Find skills for a task by words in their names and descriptions. Returns name, description and file count, best match first. An empty query lists every skill by name.",
      inputSchema: z.object({
        query: z.string().default("").describe("Task words, such as 'react performance' or 'cloudflare worker'."),
        limit: z.number().int().min(1).max(200).default(10).describe("Most results to return."),
      }),
      annotations: readOnly,
    },
    async ({ query, limit }) => {
      const skills = searchSkills(catalog.skills, query, limit);
      return json({ total: skills.length, version: catalog.version, skills });
    },
  );

  server.registerTool(
    "read_skill",
    {
      title: "Read a skill",
      description:
        "Read a skill's SKILL.md, or another of its text files when `file` is given (a path such as references/guide.md from list_skill_files).",
      inputSchema: z.object({
        name: z.string().describe("Skill name, such as 'shadcn'."),
        file: z.string().default("SKILL.md").describe("File path inside the skill folder."),
      }),
      annotations: readOnly,
    },
    async ({ name, file }) => {
      const skill = byName.get(name);
      if (skill === undefined) return notFound(catalog, name);
      if (!hasFile(skill, file))
        return failure(`Skill "${name}" has no file "${file}". Files: ${skillFiles(skill).map((f) => f.path).join(", ")}`);
      const content = await readAsset(assets, name, file);
      return content === undefined ? failure(`The file ${name}/${file} is missing from this deployment.`) : text(content);
    },
  );

  server.registerTool(
    "list_skill_files",
    {
      title: "List a skill's files",
      description: `List every file of a skill with its size in bytes. Files are also served at ${"https://mcp.julds.com/.well-known/agent-skills/<name>/<path>"} for scripts that need them on disk.`,
      inputSchema: z.object({ name: z.string().describe("Skill name.") }),
      annotations: readOnly,
    },
    async ({ name }) => {
      const skill = byName.get(name);
      if (skill === undefined) return notFound(catalog, name);
      return json({ name, version: skill.version, files: skillFiles(skill) });
    },
  );

  return server;
};
