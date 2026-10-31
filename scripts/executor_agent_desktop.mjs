#!/usr/bin/env node
// Expose the agent-desktop CLI (desktop computer use through the macOS accessibility tree) as a
// stdio MCP server for the local Executor 2 bridge. agent-desktop has no MCP mode of its own.
//
// Every call runs the native binary once with execFile (never a shell) and returns its JSON
// envelope verbatim. Reads are annotated read-only; everything that can change the desktop is
// annotated destructive so Executor asks for approval. Physical input (--headed and the raw
// mouse/keyboard commands) is refused unless a `run` call sets allowPhysicalInput. Snapshot and
// screenshot output can hold private desktop content: this process writes none of it to stderr,
// which the bridge copies into its log.
//
// Usage: node executor_agent_desktop.mjs <executor-local-tools/node_modules> <agent-desktop binary> [<disclaim-exec>]
// With disclaim-exec (scripts/disclaim_exec.c), agent-desktop is its own TCC responsible process,
// so the Accessibility and Screen Recording grants belong to the agent-desktop binary and not to
// the bridge's Node.
import { execFile } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { isAbsolute, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const [modules, binary, launcher] = process.argv.slice(2);
if (!modules || !isAbsolute(modules) || !binary || !isAbsolute(binary) || (launcher && !isAbsolute(launcher))) {
  console.error('usage: executor_agent_desktop.mjs <absolute node_modules> <absolute agent-desktop binary> [<absolute disclaim-exec>]');
  process.exit(2);
}
const sdk = (file) => import(pathToFileURL(join(modules, '@modelcontextprotocol/sdk/dist/esm', file)).href);
const { Server } = await sdk('server/index.js');
const { StdioServerTransport } = await sdk('server/stdio.js');
const { ListToolsRequestSchema, CallToolRequestSchema } = await sdk('types.js');

// agent-desktop shares background host processes through sockets under $TMPDIR. A host started
// from a terminal keeps that terminal's TCC grant, so a private TMPDIR keeps bridge calls on hosts
// this adapter started (responsible: the agent-desktop binary), and the grant check stays honest.
const HOST_TMPDIR = join(homedir(), '.agent-desktop', 'bridge-tmp');
mkdirSync(HOST_TMPDIR, { recursive: true, mode: 0o700 });

const MAX_TIMEOUT_MS = 9 * 60 * 1000; // stays under the bridge's 10 minute call limit
const DEFAULT_TIMEOUT_MS = 60 * 1000;
const PHYSICAL_COMMANDS = new Set([
  'double-click', 'triple-click', 'hover', 'drag', 'mouse-move', 'mouse-click',
  'mouse-down', 'mouse-up', 'mouse-wheel', 'key-down', 'key-up',
]);
// Flags that write desktop content to files or stderr (the bridge log). Refused in every call.
const CONTENT_SINK_FLAGS = new Set(['--screenshot', '--debug', '--trace', '--trace-strict', '--verbose', '-v']);
// macOS supported_surfaces from `agent-desktop status`; other surfaces stay reachable through run.
const SURFACES = ['window', 'focused', 'menu', 'menubar', 'sheet', 'popover', 'alert'];

// --- input schema helpers -------------------------------------------------------------------
const str = (description) => ({ type: 'string', description });
const bool = (description) => ({ type: 'boolean', description });
const int = (description) => ({ type: 'integer', minimum: 0, description });
const REF = str('Qualified ref from a snapshot, such as @s8f3k2p9:e5. Refs go stale after the UI changes: snapshot again.');
const APP = str('Application display name, such as "Finder".');
const WINDOW_ID = str('Window ID from list_windows, such as w-4521.');
const TIMEOUT_MS = int('Ref-resolution and actionability wait in milliseconds (agent-desktop default 5000).');
const object = (properties, required = []) => ({ type: 'object', properties, required, additionalProperties: false });

const READ = { readOnlyHint: true, destructiveHint: false, openWorldHint: false };
const WRITE = { readOnlyHint: false, destructiveHint: true, openWorldHint: false };

// Each tool maps validated input to an argv. `flag` adds `--name value` only when set.
const flag = (argv, name, value) => {
  if (value === undefined || value === null || value === false) return;
  if (value === true) argv.push(name);
  else argv.push(name, String(value));
};
const refArg = (ref) => {
  if (typeof ref !== 'string' || !/^@[A-Za-z0-9]+:e\d+$/.test(ref)) {
    throw new Error('ref must be a qualified snapshot ref such as @s8f3k2p9:e5');
  }
  return ref;
};
const textArg = (value, name) => {
  if (typeof value !== 'string') throw new Error(`${name} must be a string`);
  return value;
};

const refAction = (command, description, extra = {}) => ({
  name: command.replace(/-/g, '_'),
  description: `${description} Headless semantic accessibility action; it never moves the pointer or takes focus. Snapshot again afterwards to verify, and retry only when the result's disposition.retry is "safe".`,
  annotations: { ...WRITE, title: command },
  inputSchema: object({ ref: REF, ...(extra.properties ?? {}), timeoutMs: TIMEOUT_MS }, ['ref', ...(extra.required ?? [])]),
  argv: (input) => {
    const argv = [command];
    flag(argv, '--timeout-ms', input.timeoutMs);
    extra.flags?.(argv, input);
    argv.push('--', refArg(input.ref), ...(extra.positionals?.(input) ?? []));
    return argv;
  },
});

const tools = [
  {
    name: 'snapshot',
    description: 'Capture an app\'s accessibility tree as JSON with qualified @refs. The loop: snapshot (use skeleton + interactiveOnly + compact for a large app), drill in with root, act on a ref, then snapshot the same region again to verify. Output can contain private desktop content.',
    annotations: { ...READ, title: 'snapshot' },
    inputSchema: object({
      app: APP, windowId: WINDOW_ID,
      root: str('Start from this ref instead of the window root.'),
      surface: { type: 'string', enum: SURFACES, description: 'Surface to read (default window). Never skeleton a menu, sheet or alert.' },
      interactiveOnly: bool('Interactive elements only (-i).'),
      compact: bool('Collapse single-child unnamed nodes.'),
      skeleton: bool('Shallow overview (depth 3) with children_count on cut branches.'),
      maxDepth: int('Maximum tree depth (default 10).'),
      includeBounds: bool('Include element bounds.'),
      timeoutMs: int('Observation deadline in milliseconds (default 3000).'),
    }),
    argv: (i) => {
      const argv = ['snapshot'];
      flag(argv, '--app', i.app); flag(argv, '--window-id', i.windowId); flag(argv, '--root', i.root);
      flag(argv, '--surface', i.surface); flag(argv, '--interactive-only', i.interactiveOnly);
      flag(argv, '--compact', i.compact); flag(argv, '--skeleton', i.skeleton);
      flag(argv, '--max-depth', i.maxDepth); flag(argv, '--include-bounds', i.includeBounds);
      flag(argv, '--timeout-ms', i.timeoutMs);
      return argv;
    },
  },
  {
    name: 'find',
    description: 'Search elements by role, name, value or text and return matching refs.',
    annotations: { ...READ, title: 'find' },
    inputSchema: object({
      app: APP, windowId: WINDOW_ID,
      role: str('Accessibility role, such as button or textfield.'), name: str('Accessible name or label.'),
      value: str('Current value.'), text: str('Text in name, value, title or description.'),
      description: str('Accessible description.'), nativeId: str('Native automation id (AXIdentifier).'),
      exact: bool('Exact case-insensitive matches.'), root: str('Search only inside this ref.'),
      surface: { type: 'string', enum: SURFACES },
      state: { type: 'array', items: { type: 'string' }, description: 'State tokens, such as enabled or checked=false.' },
      count: bool('Return the match count only.'), first: bool('First match only.'), last: bool('Last match only.'),
      nth: int('Nth match, 0-indexed.'), limit: int('At most N matches (default 50, 0 for all).'),
      timeoutMs: int('Traversal deadline in milliseconds (default 5000).'),
    }),
    argv: (i) => {
      const argv = ['find'];
      for (const [key, name] of [['app', '--app'], ['windowId', '--window-id'], ['role', '--role'], ['name', '--name'],
        ['value', '--value'], ['text', '--text'], ['description', '--description'], ['nativeId', '--native-id'],
        ['exact', '--exact'], ['root', '--root'], ['surface', '--surface'], ['count', '--count'], ['first', '--first'],
        ['last', '--last'], ['nth', '--nth'], ['limit', '--limit'], ['timeoutMs', '--timeout-ms']]) flag(argv, name, i[key]);
      for (const token of i.state ?? []) flag(argv, '--state', textArg(token, 'state'));
      return argv;
    },
  },
  {
    name: 'get',
    description: 'Read one element property: text, value, title, bounds, role or states.',
    annotations: { ...READ, title: 'get' },
    inputSchema: object({ ref: REF, property: { type: 'string', enum: ['text', 'value', 'title', 'bounds', 'role', 'states'] } }, ['ref']),
    argv: (i) => { const argv = ['get']; flag(argv, '--property', i.property); argv.push('--', refArg(i.ref)); return argv; },
  },
  {
    name: 'is',
    description: 'Check one element state: visible, enabled, checked, focused, expanded or selected.',
    annotations: { ...READ, title: 'is' },
    inputSchema: object({ ref: REF, property: { type: 'string', enum: ['visible', 'enabled', 'checked', 'focused', 'expanded', 'selected'] } }, ['ref']),
    argv: (i) => { const argv = ['is']; flag(argv, '--property', i.property); argv.push('--', refArg(i.ref)); return argv; },
  },
  {
    name: 'screenshot',
    description: 'PNG screenshot of an app window or a display, returned as base64 inside the JSON envelope. Needs Screen Recording permission. Output can contain private desktop content.',
    annotations: { ...READ, title: 'screenshot' },
    inputSchema: object({ app: APP, windowId: WINDOW_ID, screen: int('Display index from list_displays (0 = primary).') }),
    argv: (i) => { const argv = ['screenshot']; flag(argv, '--app', i.app); flag(argv, '--window-id', i.windowId); flag(argv, '--screen', i.screen); return argv; },
  },
  {
    name: 'list_apps',
    description: 'List running GUI applications.',
    annotations: { ...READ, title: 'list-apps' },
    inputSchema: object({ app: str('Filter by application name.') }),
    argv: (i) => { const argv = ['list-apps']; flag(argv, '--app', i.app); return argv; },
  },
  {
    name: 'list_windows',
    description: 'List visible windows and their window IDs.',
    annotations: { ...READ, title: 'list-windows' },
    inputSchema: object({ app: str('Exact case-insensitive application name.') }),
    argv: (i) => { const argv = ['list-windows']; flag(argv, '--app', i.app); return argv; },
  },
  {
    name: 'list_surfaces',
    description: 'List accessibility surfaces (window, menu, sheet ...) for an app.',
    annotations: { ...READ, title: 'list-surfaces' },
    inputSchema: object({ app: APP }),
    argv: (i) => { const argv = ['list-surfaces']; flag(argv, '--app', i.app); return argv; },
  },
  {
    name: 'list_displays',
    description: 'List connected displays with bounds and scale factor.',
    annotations: { ...READ, title: 'list-displays' },
    inputSchema: object({}),
    argv: () => ['list-displays'],
  },
  {
    name: 'wait',
    description: 'Wait for a time, an element, text, a window, a menu or a desktop event instead of sleeping.',
    annotations: { ...READ, title: 'wait' },
    inputSchema: object({
      ms: int('Milliseconds to pause.'), element: str('Ref to wait for.'), window: str('Window title to wait for.'),
      text: str('Text to wait for in the app tree.'), menu: bool('Wait until a menu is open.'), menuClosed: bool('Wait until the menu closes.'),
      event: { type: 'string', enum: ['window-opened', 'window-closed', 'app-launched', 'app-terminated', 'focus-changed', 'surface-appeared', 'surface-dismissed'] },
      windowId: WINDOW_ID,
      predicate: { type: 'string', enum: ['exists', 'enabled', 'visible', 'actionable', 'value'] },
      value: str('Expected value for predicate value.'),
      action: { type: 'string', enum: ['click', 'type', 'set-value', 'clear'] },
      count: int('Expected match count for text waits.'),
      timeout: int('Timeout in milliseconds (default 30000).'), app: APP,
    }),
    argv: (i) => {
      const argv = ['wait'];
      for (const [key, name] of [['element', '--element'], ['window', '--window'], ['text', '--text'], ['menu', '--menu'],
        ['menuClosed', '--menu-closed'], ['event', '--event'], ['windowId', '--window-id'], ['predicate', '--predicate'],
        ['value', '--value'], ['action', '--action'], ['count', '--count'], ['timeout', '--timeout'], ['app', '--app']]) flag(argv, name, i[key]);
      if (i.ms !== undefined) argv.push(String(i.ms));
      return argv;
    },
    timeoutMs: (i) => (i.timeout ?? 30000) + (i.ms ?? 0) + 15000,
  },
  {
    name: 'status',
    description: 'Adapter health, platform, permission state (accessibility, screen_recording, automation) and state root.',
    annotations: { ...READ, title: 'status' },
    inputSchema: object({}),
    argv: () => ['status'],
  },
  refAction('click', 'Click an element through its accessibility press action.'),
  refAction('right-click', 'Open an element\'s context menu (AXShowMenu); inspect it with snapshot surface menu.'),
  refAction('type', 'Insert text into a text target.', {
    properties: { text: str('Text to insert.') }, required: ['text'], positionals: (i) => [textArg(i.text, 'text')],
  }),
  refAction('set-value', 'Set an element value directly through its accessibility attribute.', {
    properties: { value: str('Value to set.') }, required: ['value'], positionals: (i) => [textArg(i.value, 'value')],
  }),
  refAction('clear', 'Clear an element value.'),
  refAction('focus', 'Set keyboard focus on an element.'),
  refAction('select', 'Select an option in a list, combo box or menu button.', {
    properties: { value: str('Option to select.') }, required: ['value'], positionals: (i) => [textArg(i.value, 'value')],
  }),
  refAction('toggle', 'Toggle a checkbox or switch. Not idempotent: prefer check or uncheck.'),
  refAction('check', 'Set a checkbox or switch to checked (idempotent).'),
  refAction('uncheck', 'Set a checkbox or switch to unchecked (idempotent).'),
  refAction('expand', 'Expand a disclosure triangle or tree item.'),
  refAction('collapse', 'Collapse a disclosure triangle or tree item.'),
  refAction('scroll', 'Scroll an element.', {
    properties: { direction: { type: 'string', enum: ['up', 'down', 'left', 'right'] }, amount: int('Scroll units (default 3).') },
    flags: (argv, i) => { flag(argv, '--direction', i.direction); flag(argv, '--amount', i.amount); },
  }),
  refAction('scroll-to', 'Scroll an element into the visible area.'),
  {
    name: 'press',
    description: 'Send a key combo, such as return, escape, cmd+c or shift+tab, to an app process without focusing it. Quit shortcuts are refused.',
    annotations: { ...WRITE, title: 'press' },
    inputSchema: object({ combo: str('Key combo.'), app: APP, windowId: WINDOW_ID }, ['combo']),
    argv: (i) => { const argv = ['press']; flag(argv, '--app', i.app); flag(argv, '--window-id', i.windowId); argv.push('--', textArg(i.combo, 'combo')); return argv; },
  },
  {
    name: 'launch',
    description: 'Launch an application by display name or bundle ID and return once it runs.',
    annotations: { ...WRITE, title: 'launch' },
    inputSchema: object({ app: str('Application name or bundle ID.'), activate: bool('Bring it forward and wait for a window.') }, ['app']),
    argv: (i) => { const argv = ['launch']; flag(argv, '--activate', i.activate); argv.push('--', textArg(i.app, 'app')); return argv; },
  },
  {
    name: 'run',
    description: 'Run any other agent-desktop command with an argument array (no shell), for example ["close-app","Notes"], ["list-notifications"] or ["skills","get","desktop"]. --headed and the raw mouse/keyboard commands (hover, drag, double-click, mouse-*, key-down, key-up) are refused unless allowPhysicalInput is true, which the user must have asked for explicitly. --screenshot, --debug, --trace and --verbose are always refused.',
    annotations: { ...WRITE, title: 'run' },
    inputSchema: object({
      args: { type: 'array', items: { type: 'string' }, minItems: 1, description: 'Arguments after the agent-desktop binary.' },
      allowPhysicalInput: bool('Permit --headed and raw mouse/keyboard commands. Only when the user explicitly asked for physical input.'),
      timeoutMs: int('Process timeout in milliseconds (default 60000).'),
    }, ['args']),
    argv: (i) => {
      if (!Array.isArray(i.args) || i.args.length === 0) throw new Error('args must be a non-empty array of strings');
      const args = i.args.map((a) => textArg(a, 'args[]'));
      for (const arg of args) {
        const name = arg.split('=')[0];
        if (CONTENT_SINK_FLAGS.has(name)) throw new Error(`${name} is refused: it writes desktop content to a file or log`);
      }
      const physical = args.some((a) => a.split('=')[0] === '--headed') || args.some((a) => PHYSICAL_COMMANDS.has(a));
      if (physical && i.allowPhysicalInput !== true) {
        throw new Error('Physical input (--headed or a raw mouse/keyboard command) needs allowPhysicalInput: true and an explicit user request');
      }
      return args;
    },
    timeoutMs: (i) => i.timeoutMs ?? DEFAULT_TIMEOUT_MS,
  },
];
const byName = new Map(tools.map((tool) => [tool.name, tool]));

const runBinary = (argv, timeoutMs) => new Promise((resolve) => {
  execFile(launcher ?? binary, launcher ? [binary, ...argv] : argv, {
    // Minimal environment: no inherited session, agent id or debug settings.
    env: { HOME: homedir(), TMPDIR: `${HOST_TMPDIR}/`, PATH: '/usr/bin:/bin:/usr/sbin:/sbin', LANG: process.env.LANG ?? 'en_US.UTF-8' },
    timeout: Math.min(Math.max(timeoutMs, 1000), MAX_TIMEOUT_MS),
    maxBuffer: 64 * 1024 * 1024,
    encoding: 'utf8',
  }, (error, stdout, stderr) => resolve({ error, stdout, stderr }));
});

const server = new Server(
  { name: 'executor-agent-desktop', version: '1.0.0' },
  { capabilities: { tools: {} } },
);
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: tools.map(({ name, description, annotations, inputSchema }) => ({ name, description, annotations, inputSchema })),
}));
server.setRequestHandler(CallToolRequestSchema, async ({ params }) => {
  const tool = byName.get(params.name);
  if (!tool) return { isError: true, content: [{ type: 'text', text: `Unknown agent-desktop tool: ${params.name}` }] };
  let argv;
  const input = params.arguments ?? {};
  try {
    argv = tool.argv(input);
  } catch (error) {
    return { isError: true, content: [{ type: 'text', text: error instanceof Error ? error.message : 'invalid input' }] };
  }
  const { error, stdout, stderr } = await runBinary(argv, tool.timeoutMs?.(input) ?? DEFAULT_TIMEOUT_MS);
  const text = stdout.trim();
  let ok = false;
  try { ok = JSON.parse(text).ok === true; } catch { /* not an envelope */ }
  if (text) return { isError: !ok, content: [{ type: 'text', text }] };
  const reason = error?.killed ? 'timed out' : `exited with ${error?.code ?? 'no output'}`;
  return { isError: true, content: [{ type: 'text', text: `agent-desktop ${reason}${stderr ? `: ${stderr.trim().slice(0, 2000)}` : ''}` }] };
});
await server.connect(new StdioServerTransport());
