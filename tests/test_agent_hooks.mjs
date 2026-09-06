import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { GitGuardPlugin } from '../agents/shared/hooks/opencode/git-guard.js';
import { ShapingRipplePlugin } from '../agents/shared/hooks/opencode/shaping-ripple.js';

const messages = [];
const client = { app: { log: async ({ body }) => messages.push(body) } };
const git = await GitGuardPlugin({ client });
await git['tool.execute.before']({ tool: 'bash' }, { args: { command: 'git status' } });
await assert.rejects(
  git['tool.execute.before']({ tool: 'bash' }, { args: { command: 'git restore --staged file && git reset --hard' } }),
  /BLOCKED/,
);
assert.equal(messages.at(-1).message, 'Git guard blocked a shell command');
assert.ok(!JSON.stringify(messages).includes('git reset --hard'));

const directory = mkdtempSync(join(tmpdir(), 'shaping hook '));
let checks = 2;
try {
  const path = join(directory, 'shape with spaces.md');
  writeFileSync(path, '---\nshaping: true\n---\n');
  writeFileSync(join(directory, 'ordinary.md'), 'Ordinary document\n');
  writeFileSync(join(directory, 'source.py'), 'shaping: true\n');
  const shaping = await ShapingRipplePlugin({ client, directory });
  const patch = (lines) => ['*** Begin Patch', ...lines, '*** End Patch'].join('\n');
  const triggering = [
    { tool: 'edit', args: { filePath: path } },
    { tool: 'write', args: { filePath: 'shape with spaces.md' } },
    { tool: 'apply_patch', args: { patchText: patch(['*** Update File: ordinary.md', '@@', '-Old', '+New', '*** Update File: shape with spaces.md', '@@', '-Old', '+New']) } },
    { tool: 'apply_patch', args: { patchText: patch(['*** Add File: shape with spaces.md', '+---', '+shaping: true', '+---']) } },
    { tool: 'apply_patch', args: { patchText: patch(['*** Update File: old.md', '*** Move to: shape with spaces.md', '@@', '-Old', '+New']).replaceAll('\n', '\r\n') } },
  ];
  for (const input of triggering) {
    const output = { output: 'Edited' };
    await shaping['tool.execute.after'](input, output);
    assert.match(output.output, /Edited[\s\S]*Ripple check/);
    assert.equal(output.output.match(/Ripple check/g).length, 1);
    checks++;
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
    const output = { output: 'Unchanged' };
    const logCount = messages.length;
    await shaping['tool.execute.after'](input, output);
    assert.equal(output.output, 'Unchanged');
    assert.equal(messages.length, logCount);
    checks++;
  }
} finally {
  rmSync(directory, { recursive: true });
}
console.log(`OpenCode hook adapters: ${checks} checks passed`);
