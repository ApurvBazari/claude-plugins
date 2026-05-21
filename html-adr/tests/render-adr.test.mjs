import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { render, preflight } from '../scripts/render-adr.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const pluginRoot = join(__dirname, '..');

test('renders a minimal spec to HTML', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'adr-e2e-'));
  const src = join(dir, '2026-01-01-test-design.md');
  writeFileSync(src, '# Test ADR\n\n## Context\n\nWhy we care.\n\n## Affected Files\n\n- foo.js — new\n');
  const out = join(dir, 'test.html');

  await render({ src, out, pluginRoot });

  assert.equal(existsSync(out), true);
  const html = readFileSync(out, 'utf8');
  assert.match(html, /Test ADR/);
  assert.match(html, /foo\.js/);
  rmSync(dir, { recursive: true });
});

test('preflight passes for a valid plugin root', () => {
  // Real plugin root has node_modules + assets after setup
  const result = preflight({ src: 'README.md', pluginRoot: pluginRoot });
  assert.equal(result.ok, true);
});

test('preflight fails for non-existent source', () => {
  const result = preflight({ src: '/nope/missing.md', pluginRoot: pluginRoot });
  assert.equal(result.ok, false);
  assert.match(result.error, /source not found/i);
});
