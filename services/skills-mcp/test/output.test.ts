// Checks the real build output (run `bun run build` first) with the same
// loader Executor uses and with the MCP endpoint the Worker serves.
import { afterAll, describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { createMcpHandler } from "@modelcontextprotocol/server";
import { wellKnownSkills } from "apps/skills";
import type { Catalog } from "../src/catalog.js";
import { EXECUTOR_SHARDS, SKILLS_PATH, executorShardFile } from "../src/config.js";
import { createServer, type AssetFetcher } from "../src/server.js";

const serviceDir = join(import.meta.dir, "..");
const assetsDir = join(serviceDir, "dist", "assets");
const catalogFile = join(serviceDir, "src", "generated", "catalog.json");
const built = existsSync(assetsDir) && existsSync(catalogFile);

const assets: AssetFetcher = {
  fetch: async (request) => {
    const path = join(assetsDir, decodeURIComponent(new URL(request.url).pathname));
    if (!path.startsWith(assetsDir) || !existsSync(path)) return new Response("Not found", { status: 404 });
    return new Response(Bun.file(path));
  },
};

describe.skipIf(!built)("build output", () => {
  const catalog: Catalog = built ? JSON.parse(readFileSync(catalogFile, "utf8")) : { version: "", commit: "", skills: [] };
  const server = Bun.serve({ port: 0, fetch: (request) => assets.fetch(request) });
  afterAll(() => server.stop(true));

  test("Executor's wellKnownSkills loads every shard with no duplicate names", async () => {
    const shards = await Promise.all(
      Array.from({ length: EXECUTOR_SHARDS }, (_, shard) =>
        wellKnownSkills({ url: `${server.url.origin}${SKILLS_PATH}/${executorShardFile(shard)}` }),
      ),
    );
    const names = shards.flat().map((skill) => skill.name);
    expect(names.length).toBe(catalog.skills.length);
    expect(new Set(names).size).toBe(names.length);
  }, 60_000);

  test("the discovery index follows RFC v0.2 with digests that match", async () => {
    const index = await (await fetch(`${server.url.origin}${SKILLS_PATH}/index.json`)).json();
    expect(index.$schema).toBe("https://schemas.agentskills.io/discovery/0.2.0/schema.json");
    const first = index.skills[0];
    const body = readFileSync(join(assetsDir, SKILLS_PATH, first.name, "SKILL.md"));
    expect(first.digest).toBe(`sha256:${new Bun.CryptoHasher("sha256").update(body).digest("hex")}`);
  });

  const rpc = async (method: string, params: Record<string, unknown> = {}) => {
    const handler = createMcpHandler(() => createServer(catalog, assets));
    const response = await handler.fetch(
      new Request("https://mcp.julds.com/mcp", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          accept: "application/json, text/event-stream",
          "mcp-protocol-version": "2025-06-18",
        },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
      }),
    );
    const raw = await response.text();
    const data = raw.startsWith("{") ? raw : (raw.split("\n").find((line) => line.startsWith("data: "))?.slice(6) ?? raw);
    return JSON.parse(data);
  };

  test("MCP initialize declares the skills extension", async () => {
    const result = await rpc("initialize", {
      protocolVersion: "2025-06-18",
      capabilities: {},
      clientInfo: { name: "test", version: "1" },
    });
    expect(result.result.serverInfo.name).toBe("julds-skills");
    expect(result.result.capabilities.extensions["io.modelcontextprotocol/skills"]).toBeDefined();
  });

  test("MCP tools search and read skills", async () => {
    const search = await rpc("tools/call", { name: "search_skills", arguments: { query: "cloudflare workers", limit: 3 } });
    expect(search.result.structuredContent.skills[0].name).toBe("cloudflare");
    const read = await rpc("tools/call", { name: "read_skill", arguments: { name: "cloudflare" } });
    expect(read.result.content[0].text).toContain("name: cloudflare");
    const missing = await rpc("tools/call", { name: "read_skill", arguments: { name: "cloudflare", file: "../x" } });
    expect(missing.result.isError).toBe(true);
  });

  test("MCP skills/list pages through every skill and resources/read serves files", async () => {
    const names: string[] = [];
    let cursor: string | undefined;
    do {
      const page = await rpc("skills/list", cursor === undefined ? {} : { cursor });
      names.push(...page.result.skills.map((s: { frontmatter: { name: string } }) => s.frontmatter.name));
      cursor = page.result.nextCursor;
    } while (cursor !== undefined);
    expect(names.length).toBe(catalog.skills.length);
    const read = await rpc("resources/read", { uri: "skill://cloudflare/SKILL.md" });
    expect(read.result.contents[0].text).toContain("name: cloudflare");
  });
});
