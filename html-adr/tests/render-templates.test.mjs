import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderTemplates } from '../scripts/plugins/render-templates.mjs';
import { buildDataFlow, buildEdgeCases, buildDepsRisks, buildRollback, buildTesting, buildGenericProse, buildMermaidBlock } from '../scripts/plugins/widget-builders.mjs';
import { buildAdrHeader } from '../scripts/plugins/adr-header-builder.mjs';
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
  writeFileSync(join(dir, 'side-panel.html'), '<aside class="side-panel"></aside>');
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
  assert.match(html, /banner-info/);
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

test('DATA_FLOW builder emits pipeline pills with data-item-type=step', () => {
  const list = {
    type: 'list',
    children: [
      { type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: 'parse' }] }] },
      { type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: 'transform' }] }] },
    ],
  };
  const html = buildDataFlow({ headingText: 'Data Flow', content: [list] });
  assert.match(html, /data-item-type="step"[^>]+data-step="parse"/);
  assert.match(html, /class="pipe-step"/);
});

test('EDGE_CASES builder assigns severity by keyword', () => {
  const list = {
    type: 'list', children: [
      { type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: 'must fail loudly' }] }] },
      { type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: 'should warn' }] }] },
      { type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: 'just a thing' }] }] },
    ],
  };
  const html = buildEdgeCases({ headingText: 'Edge Cases', content: [list] });
  assert.match(html, /severity-high/);
  assert.match(html, /severity-med/);
});

test('DEPS_RISKS builder splits package chips from risk callouts', () => {
  const list = {
    type: 'list', children: [
      { type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: 'lodash@4.17.21' }] }] },
      { type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: 'risk: parser may break' }] }] },
    ],
  };
  const html = buildDepsRisks({ headingText: 'Deps & Risks', content: [list] });
  assert.match(html, /class="dep-chip"[^>]+data-name="lodash"/);
  assert.match(html, /class="risk-callout"/);
});

test('ROLLBACK builder numbers steps', () => {
  const ol = {
    type: 'list', ordered: true, children: [
      { type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: 'revert' }] }] },
      { type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: 'redeploy' }] }] },
    ],
  };
  const html = buildRollback({ headingText: 'Rollback', content: [ol] });
  assert.match(html, /data-item-type="rollback-step"[^>]+data-step="1"/);
  assert.match(html, /data-step="2"/);
});

test('TESTING builder preserves categories from H3 sub-headings', () => {
  const content = [
    { type: 'heading', depth: 3, children: [{ type: 'text', value: 'Unit' }] },
    { type: 'list', children: [
      { type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: 'test x' }] }] },
    ]},
  ];
  const html = buildTesting({ headingText: 'Testing', content });
  assert.match(html, /Unit/);
  assert.match(html, /data-item-type="test"/);
});

test('GENERIC_PROSE builder dumps content as HTML', () => {
  const content = [{ type: 'paragraph', children: [{ type: 'text', value: 'just some prose' }] }];
  const html = buildGenericProse({ id: 'threat-model', headingText: 'Threat Model', content });
  assert.match(html, /just some prose/);
  assert.match(html, /Threat Model/);
});

test('MERMAID_BLOCK builder wraps source in <pre class="mermaid">', () => {
  const html = buildMermaidBlock({ source: 'sequenceDiagram\n  A->>B: hi' });
  assert.match(html, /<pre class="mermaid">[\s\S]*A-&gt;&gt;B: hi/);
});

test('renders decision callout', () => {
  const adr = {
    title: { value: 'My ADR', confidence: 'high' },
    decision_outcome: { value: 'We will do X', confidence: 'high' },
    decision_drivers: { value: ['a', 'b'], confidence: 'high' },
    context: { value: 'because reasons', confidence: 'medium' },
    considered_options: { value: [
      { name: 'A', summary: 'do A', pros: ['fast'], cons: ['risky'], verdict: 'chosen' },
      { name: 'B', summary: 'do B', pros: [], cons: [], verdict: 'rejected' },
    ], confidence: 'high' },
    consequences: { value: { positive: ['good'], negative: ['bad'] }, confidence: 'high' },
  };
  const html = buildAdrHeader(adr);
  assert.match(html, /My ADR/);
  assert.match(html, /We will do X/);
  assert.match(html, /class="driver-chip"[^>]*>a</);
  assert.match(html, /class="option-card chosen"/);
  assert.match(html, /class="cons-box positive"[\s\S]*good/);
});

test('omits ADR header when fewer than 2 options detected', () => {
  const adr = { title: { value: 'X' }, considered_options: null };
  const html = buildAdrHeader(adr);
  assert.match(html, /banner/);
  assert.match(html, /doesn't contain a multi-option decision/);
});

test('rendered HTML contains the locked Mermaid securityLevel: "loose"', async () => {
  // This test guards a deliberate security policy decision documented in
  // assets/runtime.js. 'loose' lets click bindings + inline styles render in
  // Mermaid diagrams (we trust spec authors). 'sandbox' would lose page CSS
  // inheritance. Do not change without a security audit and a documentation
  // update; this assertion exists to make the drift visible.
  const { render } = await import('../scripts/render-adr.mjs');
  const { fileURLToPath } = await import('node:url');
  const { dirname } = await import('node:path');
  const dir = mkdtempSync(join(tmpdir(), 'adr-securitylevel-'));
  const src = join(dir, 'tiny.md');
  writeFileSync(src, '# Tiny\n\n## Context\n\nMinimal.\n');
  const out = join(dir, 'tiny.html');
  const pluginRoot = join(dirname(fileURLToPath(import.meta.url)), '..');

  await render({ src, out, pluginRoot });

  const html = readFileSync(out, 'utf8');
  assert.match(html, /securityLevel:\s*['"]loose['"]/, 'expected Mermaid securityLevel: "loose" in rendered HTML');
});
