import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { inlineAssets } from '../scripts/plugins/inline-assets.mjs';

test('replaces vendored: placeholders with file contents', () => {
  const dir = mkdtempSync(join(tmpdir(), 'adr-inline-'));
  writeFileSync(join(dir, 'cytoscape-3.30.4.min.js'), 'CYTOSCAPE_BODY');
  writeFileSync(join(dir, 'mermaid-11.4.1.min.js'), 'MERMAID_BODY');
  writeFileSync(join(dir, 'highlight-github.min.css'), 'CSS_BODY');

  const html = `
<link rel="stylesheet" href="vendored:highlight-github.min.css">
<script>{{cytoscapeBundle}}</script>
<script>{{mermaidBundle}}</script>
`;
  const out = inlineAssets({ assetsDir: dir })(html);
  assert.match(out, /CSS_BODY/);
  assert.match(out, /CYTOSCAPE_BODY/);
  assert.match(out, /MERMAID_BODY/);
  assert.doesNotMatch(out, /\{\{cytoscapeBundle\}\}/);
});

test('throws if a referenced asset is missing', () => {
  const dir = mkdtempSync(join(tmpdir(), 'adr-inline-missing-'));
  const html = '<script>{{cytoscapeBundle}}</script>';
  assert.throws(() => inlineAssets({ assetsDir: dir })(html), /cytoscape/);
});
