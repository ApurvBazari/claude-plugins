import { test } from 'node:test';
import assert from 'node:assert/strict';
import { extractAdr } from '../scripts/plugins/extract-adr.mjs';

function tree(...children) { return { type: 'root', children }; }
function h(depth, text) { return { type: 'heading', depth, children: [{ type: 'text', value: text }] }; }
function p(text) { return { type: 'paragraph', children: [{ type: 'text', value: text }] }; }

test('extracts title from first H1', () => {
  const t = tree(h(1, 'My Decision'), p('intro'));
  extractAdr({ filePath: '/tmp/2026-01-15-foo-design.md' })(t);
  assert.equal(t.data.adr.title.value, 'My Decision');
  assert.equal(t.data.adr.title.confidence, 'high');
  assert.match(t.data.adr.title.provenance, /first H1/);
});

test('falls back to filename when no H1', () => {
  const t = tree(p('only prose'));
  extractAdr({ filePath: '/tmp/2026-01-15-cool-thing-design.md' })(t);
  assert.equal(t.data.adr.title.value, 'Cool Thing');
});

test('extracts date from filename YYYY-MM-DD prefix', () => {
  const t = tree(h(1, 'X'));
  extractAdr({ filePath: '/tmp/2026-03-21-x-design.md' })(t);
  assert.equal(t.data.adr.date.value, '2026-03-21');
  assert.equal(t.data.adr.date.confidence, 'high');
});

test('status from blockquote', () => {
  const t = tree(
    h(1, 'X'),
    { type: 'blockquote', children: [p('Status: accepted')] }
  );
  extractAdr({ filePath: '/tmp/x.md' })(t);
  assert.equal(t.data.adr.status.value, 'accepted');
});
