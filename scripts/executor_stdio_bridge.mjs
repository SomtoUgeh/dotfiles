#!/usr/bin/env node
// Expose local stdio MCP servers over streamable HTTP for Executor 2, which cannot launch
// processes. Listens on 127.0.0.1 only. Every request must carry the bridge secret as the first
// path segment: http://127.0.0.1:<port>/<secret>/<server>/mcp. One long-lived stdio process per
// server is shared by stateless HTTP requests; it restarts on the next call if it exits.
//
// Usage: node executor_stdio_bridge.mjs <config.json> <node_modules dir with @modelcontextprotocol/sdk>
// config: { "port": 8930, "secretFile": "...", "servers": { "<name>": { "command", "args", "env", "cwd" } } }
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { timingSafeEqual } from "node:crypto";
import { pathToFileURL } from "node:url";
import { join } from "node:path";

const [configPath, modules] = process.argv.slice(2);
if (!configPath || !modules) {
  console.error("usage: executor_stdio_bridge.mjs <config.json> <node_modules>");
  process.exit(2);
}
const sdk = (p) => import(pathToFileURL(join(modules, "@modelcontextprotocol/sdk/dist/esm", p)).href);
const { Client } = await sdk("client/index.js");
const { StdioClientTransport } = await sdk("client/stdio.js");
const { Server } = await sdk("server/index.js");
const { StreamableHTTPServerTransport } = await sdk("server/streamableHttp.js");
const { ListToolsRequestSchema, CallToolRequestSchema } = await sdk("types.js");

const config = JSON.parse(readFileSync(configPath, "utf8"));
const secret = Buffer.from(readFileSync(config.secretFile, "utf8").trim());
if (secret.length < 32) throw new Error("bridge secret must be at least 32 characters");
const port = config.port ?? 8930;

const clients = new Map();
const upstream = async (name) => {
  const existing = clients.get(name);
  if (existing) return existing;
  const spec = config.servers[name];
  const pending = (async () => {
    const transport = new StdioClientTransport({
      command: spec.command,
      args: spec.args ?? [],
      env: { ...process.env, ...(spec.env ?? {}) },
      cwd: spec.cwd,
      stderr: "inherit",
    });
    const client = new Client({ name: `executor-bridge-${name}`, version: "1.0.0" });
    transport.onclose = () => clients.delete(name);
    await client.connect(transport);
    return client;
  })();
  clients.set(name, pending);
  pending.catch(() => clients.delete(name));
  return pending;
};

const authorized = (candidate) => {
  const given = Buffer.from(candidate ?? "");
  return given.length === secret.length && timingSafeEqual(given, secret);
};

const readBody = (req) =>
  new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on("data", (c) => {
      size += c.length;
      if (size > 8 * 1024 * 1024) { reject(new Error("body too large")); req.destroy(); }
      chunks.push(c);
    });
    req.on("end", () => resolve(chunks.length ? JSON.parse(Buffer.concat(chunks).toString("utf8")) : undefined));
    req.on("error", reject);
  });

const http = createServer(async (req, res) => {
  try {
    // Reject browser-originated requests outright (DNS rebinding / drive-by pages).
    if (req.headers.origin) { res.writeHead(403).end(); return; }
    const [token, name, tail] = new URL(req.url, "http://127.0.0.1").pathname.split("/").filter(Boolean);
    if (!authorized(token)) { res.writeHead(404).end(); return; }
    if (!config.servers[name] || tail !== "mcp") { res.writeHead(404).end(); return; }
    if (req.method !== "POST") { res.writeHead(405, { allow: "POST" }).end(); return; }
    const body = await readBody(req);
    const server = new Server({ name, version: "1.0.0" }, { capabilities: { tools: {} } });
    server.setRequestHandler(ListToolsRequestSchema, async (request) =>
      (await upstream(name)).listTools(request.params));
    server.setRequestHandler(CallToolRequestSchema, async (request) =>
      (await upstream(name)).callTool(request.params, undefined, { timeout: 10 * 60 * 1000 }));
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
    res.on("close", () => { transport.close(); server.close(); });
    await server.connect(transport);
    await transport.handleRequest(req, res, body);
  } catch (error) {
    console.error(`[bridge] ${error?.message ?? error}`);
    if (!res.headersSent) res.writeHead(500).end();
  }
});
http.listen(port, "127.0.0.1", () => console.error(`[bridge] listening on 127.0.0.1:${port} for ${Object.keys(config.servers).join(", ")}`));
