import { createMcpHandler } from "@modelcontextprotocol/server";
import type { Catalog } from "./catalog.js";
import { ORIGIN, SKILLS_PATH } from "./config.js";
import catalogJson from "./generated/catalog.json" with { type: "json" };
import { createServer, type AssetFetcher } from "./server.js";

interface Env {
  ASSETS: AssetFetcher;
}

const catalog: Catalog = catalogJson;

const home = (): Response =>
  Response.json(
    {
      name: "julds-skills",
      skills: catalog.skills.length,
      version: catalog.version,
      commit: catalog.commit,
      mcp: `${ORIGIN}/mcp`,
      index: `${ORIGIN}${SKILLS_PATH}/index.json`,
    },
    { headers: { Link: `<${SKILLS_PATH}/index.json>; rel="agent-skills"; type="application/json"` } },
  );

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);
    if (pathname === "/mcp") return createMcpHandler(() => createServer(catalog, env.ASSETS)).fetch(request);
    if (pathname === "/") return home();
    return new Response("Not found\n", { status: 404 });
  },
};
