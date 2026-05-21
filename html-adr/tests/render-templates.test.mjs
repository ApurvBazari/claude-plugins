import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderTemplates } from '../scripts/plugins/render-templates.mjs';
import { readFileSync, mkdirSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

function fakeTemplates() {
  const dir = mkdtempSync(join(tmpdir(), 'adr-tpl-'));
  mkdirSync(join(dir, 'widgets'), { recursive: true });
  writeFileSync(join(dir, 'shell.html'), '<html>{{adrHeader}}{{sections}}</html>');
  writeFileSync(join(dir, 'adr-header.html'), '<header>{{title}}</header>');
  writeFileSync(join(dir, 'widgets', 'affected-files.html'), '<section>Files: {{itemCount}}</section>');
  writeFileSync(join(dir, 'widgets', 'generic-prose.html'), '<section>Prose: {{headingText}}</section>');
  return dir;
}

test('substitutes simple placeholders in shell template', async () => {
  const dir = fakeTemplates();
  const t = {
    type: 'root', children: [],
    data: {
      adr: { title: { value: 'My ADR' } },
      sections: [],
      graph: { nodes: [], edges: [] },
    },
  };
  const html = renderTemplates({ templatesDir: dir, meta: {} }).renderShell(t);
  assert.match(html, /<header>My ADR<\/header>/);
});

test('renders AFFECTED_FILES widget with itemCount', async () => {
  const dir = fakeTemplates();
  const t = {
    type: 'root', children: [],
    data: {
      adr: { title: { value: 'X' } },
      sections: [{ type: 'AFFECTED_FILES', headingText: 'Affected Files', content: [], items: [{ path: 'a.js' }, { path: 'b.js' }] }],
      graph: { nodes: [], edges: [] },
    },
  };
  const html = renderTemplates({ templatesDir: dir, meta: {} }).renderShell(t);
  assert.match(html, /Files: 2/);
});
