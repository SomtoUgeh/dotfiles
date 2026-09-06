import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const script = fileURLToPath(new URL('./create-html.ts', import.meta.url));
const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 400"><rect width="800" height="400" fill="#123456"/></svg>';

test('renders dimensions, zero padding, escaped title, and inert SVG image', () => {
  const dir = mkdtempSync(join(tmpdir(), 'svg-wrapper-'));
  try {
    const input = join(dir, 'logo&<one>.svg');
    const output = join(dir, 'output.html');
    writeFileSync(input, svg.replace('</svg>', '<script>alert(1)</script></svg>'));
    const result = spawnSync(process.execPath, [script, '-s', input, '-o', output, '-p', '0', '-w', '800'], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    const html = readFileSync(output, 'utf8');
    assert.match(html, /padding: 0px/);
    assert.match(html, /width: 800px/);
    assert.match(html, /background: #123456/);
    assert.match(html, /logo&amp;&lt;one&gt;/);
    assert.match(html, /data:image\/svg\+xml;base64,/);
    assert.doesNotMatch(html, /<script>/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('detects full background independent of attribute order and quotes', () => {
  const dir = mkdtempSync(join(tmpdir(), 'svg-background-'));
  try {
    const input = join(dir, 'in.svg');
    const output = join(dir, 'out.html');
    for (const source of [
      svg.replace('width="800" height="400" fill="#123456"', "fill='#123456' height='100%' width='100%'"),
      svg.replace('viewBox=', 'style="background-color: #123456" viewBox='),
    ]) {
      writeFileSync(input, source);
      const result = spawnSync(process.execPath, [script, '--svg', input, '--output', output, '--padding', '1.5'], { encoding: 'utf8' });
      assert.equal(result.status, 0, result.stderr);
      assert.match(readFileSync(output, 'utf8'), /background: #123456/);
      assert.match(readFileSync(output, 'utf8'), /padding: 1.5px/);
    }
    const result = spawnSync(process.execPath, [script, '-s', input, '-o', output, '-b', 'rgb(1, 2, 3)'], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    assert.match(readFileSync(output, 'utf8'), /background: rgb\(1, 2, 3\)/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('rejects malformed arguments and prevents overwriting input', () => {
  const dir = mkdtempSync(join(tmpdir(), 'svg-invalid-'));
  try {
    const input = join(dir, 'in.svg');
    const output = join(dir, 'out.html');
    writeFileSync(input, svg);
    const base = ['--svg', input, '--output', output];
    for (const args of [[], ['--svg'], [...base, '--padding'], [...base, '--padding', '-1'], [...base, '--padding', 'garbage'], [...base, '--padding', 'Infinity'], [...base, '--width', '0'], [...base, '--unknown'], [...base, '--background', 'red;display:none'], ['--svg', input, '--output', input]]) {
      const result = spawnSync(process.execPath, [script, ...args], { encoding: 'utf8' });
      assert.notEqual(result.status, 0, JSON.stringify(args));
    }
    assert.equal(readFileSync(input, 'utf8'), svg);
    writeFileSync(input, '<html>not SVG</html>');
    assert.notEqual(spawnSync(process.execPath, [script, ...base]).status, 0);
    assert.equal(spawnSync(process.execPath, [script, '--help']).status, 0);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
