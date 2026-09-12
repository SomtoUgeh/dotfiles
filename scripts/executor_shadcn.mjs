#!/usr/bin/env node
// Preserve per-project registry context behind the shared local Executor daemon.
import { stat } from 'node:fs/promises';
import { isAbsolute, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { homedir } from 'node:os';

const modules = process.argv[2];
if (!modules || !isAbsolute(modules)) {
  throw new Error('Pass the absolute executor-local-tools/node_modules directory');
}
const sdk = (file) => import(pathToFileURL(join(modules, '@modelcontextprotocol/sdk/dist/esm', file)).href);
const { Client } = await sdk('client/index.js');
const { StdioClientTransport } = await sdk('client/stdio.js');
const { Server } = await sdk('server/index.js');
const { StdioServerTransport } = await sdk('server/stdio.js');
const { ListToolsRequestSchema, CallToolRequestSchema } = await sdk('types.js');

async function withProject(cwd, action) {
  const client = new Client({ name: 'executor-shadcn-project', version: '1.0.0' });
  try {
    await client.connect(new StdioClientTransport({
      command: process.execPath,
      args: [join(modules, 'shadcn/dist/index.js'), 'mcp', '--cwd', cwd],
      cwd,
      stderr: 'inherit',
    }));
    return await action(client);
  } finally {
    await client.close();
  }
}

// Tool discovery is project-independent; actual calls always start a fresh
// upstream process with the caller's directory, so concurrent projects cannot
// change one another's registry configuration.
const catalog = await withProject(homedir(), (client) => client.listTools());
const names = new Set(catalog.tools.map((tool) => tool.name));
const server = new Server({ name: 'executor-shadcn', version: '1.0.0' }, { capabilities: { tools: {} } });
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: catalog.tools.map((tool) => ({
    ...tool,
    description: `${tool.description ?? ''}\nRequires the absolute local project directory in projectDirectory.`,
    inputSchema: {
      ...tool.inputSchema,
      properties: {
        ...tool.inputSchema.properties,
        projectDirectory: { type: 'string', description: 'Absolute path to the local project whose components.json and registries should be used.' },
      },
      required: [...(tool.inputSchema.required ?? []), 'projectDirectory'],
    },
  })),
}));
server.setRequestHandler(CallToolRequestSchema, async ({ params }) => {
  try {
    if (!names.has(params.name)) throw new Error('Unknown shadcn tool');
    const { projectDirectory, ...args } = params.arguments ?? {};
    if (typeof projectDirectory !== 'string' || !isAbsolute(projectDirectory)) {
      throw new Error('projectDirectory must be an absolute local directory');
    }
    if (!(await stat(projectDirectory)).isDirectory()) throw new Error('projectDirectory must be a directory');
    return await withProject(projectDirectory, (client) => client.callTool({ name: params.name, arguments: args }));
  } catch (error) {
    return { isError: true, content: [{ type: 'text', text: error instanceof Error ? error.message : 'shadcn call failed' }] };
  }
});
await server.connect(new StdioServerTransport());
