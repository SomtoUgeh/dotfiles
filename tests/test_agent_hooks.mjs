import assert from 'node:assert/strict';
import { mkdtempSync, readdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import gitGuard from '../agents/shared/hooks/opencode/git-guard.js';
import shapingRipple from '../agents/shared/hooks/opencode/shaping-ripple.js';

const repo = dirname(dirname(fileURLToPath(import.meta.url)));
let checks = 0;

function mockCtx(directory) {
  const hooks = {};
  return {
    location: { directory: directory ?? repo },
    tool: {
      hook: async (name, callback) => {
        hooks[name] = callback;
        return { dispose: async () => {} };
      },
    },
    hooks,
  };
}

assert.equal(gitGuard.id, 'git-guard');
assert.equal(typeof gitGuard.setup, 'function');
assert.equal(gitGuard.server, undefined);
assert.equal(shapingRipple.id, 'shaping-ripple');
assert.equal(typeof shapingRipple.setup, 'function');
assert.equal(shapingRipple.server, undefined);
assert.deepEqual(readdirSync(join(repo, 'agents/opencode/plugins')).sort(), ['git-guard.js', 'shaping-ripple.js']);
checks += 7;

const gitCtx = mockCtx();
await gitGuard.setup(gitCtx);
await gitCtx.hooks['execute.before']({ tool: 'bash', input: { command: 'git status' } });
await gitCtx.hooks['execute.before']({ tool: 'shell', input: { command: 'git status' } });
await gitCtx.hooks['execute.before']({ tool: 'edit', input: { filePath: 'README.md' } });
await assert.rejects(
  gitCtx.hooks['execute.before']({ tool: 'bash', input: { command: 'git restore --staged file && git reset --hard' } }),
  /BLOCKED/,
);
await assert.rejects(
  gitCtx.hooks['execute.before']({ tool: 'shell', input: { command: 'git restore --staged file && git reset --hard' } }),
  /BLOCKED/,
);
checks += 5;

const directory = mkdtempSync(join(tmpdir(), 'shaping hook '));
try {
  const path = join(directory, 'shape with spaces.md');
  writeFileSync(path, '---\nshaping: true\n---\n');
  writeFileSync(join(directory, 'ordinary.md'), 'Ordinary document\n');
  writeFileSync(join(directory, 'source.py'), 'shaping: true\n');
  const shapingCtx = mockCtx(directory);
  await shapingRipple.setup(shapingCtx);
  const patch = (lines) => ['*** Begin Patch', ...lines, '*** End Patch'].join('\n');
  const triggering = [
    { tool: 'edit', args: { filePath: path } },
    { tool: 'write', args: { filePath: 'shape with spaces.md' } },
    { tool: 'apply_patch', args: { patchText: patch(['*** Update File: ordinary.md', '@@', '-Old', '+New', '*** Update File: shape with spaces.md', '@@', '-Old', '+New']) } },
    { tool: 'apply_patch', args: { patchText: patch(['*** Add File: shape with spaces.md', '+---', '+shaping: true', '+---']) } },
    { tool: 'apply_patch', args: { patchText: patch(['*** Update File: old.md', '*** Move to: shape with spaces.md', '@@', '-Old', '+New']).replaceAll('\n', '\r\n') } },
  ];
  for (const input of triggering) {
    const event = { tool: input.tool, input: input.args, status: 'completed', result: { content: 'Edited' } };
    await shapingCtx.hooks['execute.after'](event);
    assert.match(event.result.content, /Edited[\s\S]*Ripple check/);
    assert.equal(event.result.content.match(/Ripple check/g).length, 1);
    checks += 2;
  }
  const quiet = [
    { tool: 'read', args: { filePath: path } },
    { tool: 'edit', args: { filePath: 'ordinary.md' } },
    { tool: 'apply_patch', args: { patchText: patch(['*** Update File: ordinary.md', '@@', '-Old', '+New']) } },
    { tool: 'apply_patch', args: { patchText: patch(['*** Delete File: shape with spaces.md']) } },
    { tool: 'apply_patch', args: { patchText: patch(['*** Update File: source.py', '@@', '-Old', '+New']) } },
    { tool: 'apply_patch', args: {} },
  ];
  for (const input of quiet) {
    const event = { tool: input.tool, input: input.args, status: 'completed', result: { content: 'Unchanged' } };
    await shapingCtx.hooks['execute.after'](event);
    assert.equal(event.result.content, 'Unchanged');
    checks += 1;
  }
} finally {
  rmSync(directory, { recursive: true });
}
console.log(`OpenCode hook adapters: ${checks} checks passed`);
