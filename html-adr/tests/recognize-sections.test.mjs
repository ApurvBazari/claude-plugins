import { test } from 'node:test';
import assert from 'node:assert/strict';
import { recognizeSections } from '../scripts/plugins/recognize-sections.mjs';

const h = (depth, text) => ({ type: 'heading', depth, children: [{ type: 'text', value: text }] });
const p = (text) => ({ type: 'paragraph', children: [{ type: 'text', value: text }] });
const tree = (...c) => ({ type: 'root', children: c });

test('classifies canonical headings', () => {
  const t = tree(h(2, 'Affected Files'), p('a'), h(2, 'Data Flow'), p('b'), h(2, 'Edge Cases'), p('c'));
  recognizeSections()(t);
  const types = t.data.sections.map(s => s.type);
  assert.deepEqual(types, ['AFFECTED_FILES', 'DATA_FLOW', 'EDGE_CASES']);
});

test('non-canonical heading falls to GENERIC_PROSE', () => {
  const t = tree(h(2, 'Threat Model'), p('content'));
  recognizeSections()(t);
  assert.equal(t.data.sections[0].type, 'GENERIC_PROSE');
});

test('frontmatter override remaps a heading', () => {
  const t = tree(h(2, 'Threat Model'), p('content'));
  recognizeSections({ sectionsOverride: { 'Threat Model': 'DEPS_RISKS' } })(t);
  assert.equal(t.data.sections[0].type, 'DEPS_RISKS');
});

test('headings consumed by extract-adr are skipped', () => {
  const t = tree(h(2, 'Context'), p('a'), h(2, 'Approach A'), p('b'), h(2, 'Affected Files'), p('c'));
  recognizeSections()(t);
  const types = t.data.sections.map(s => s.type);
  assert.deepEqual(types, ['AFFECTED_FILES']);
});
