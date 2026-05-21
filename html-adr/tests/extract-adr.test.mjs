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

test('extracts context from H2 "Context"', () => {
  const t = tree(
    h(1, 'X'),
    h(2, 'Context'),
    p('the why prose'),
    h(2, 'Decision'),
    p('the what')
  );
  extractAdr({ filePath: '/tmp/x.md' })(t);
  assert.match(t.data.adr.context.value, /the why prose/);
  assert.equal(t.data.adr.context.confidence, 'high');
});

test('extracts context from prose between H1 and first H2 if no Context section', () => {
  const t = tree(
    h(1, 'X'),
    p('implicit context'),
    h(2, 'Approach A'),
  );
  extractAdr({ filePath: '/tmp/x.md' })(t);
  assert.match(t.data.adr.context.value, /implicit context/);
  assert.equal(t.data.adr.context.confidence, 'medium');
});

test('extracts decision_drivers from frontmatter list', () => {
  const t = tree(h(1, 'X'));
  extractAdr({ filePath: '/tmp/x.md', frontmatter: { drivers: ['a', 'b'] } })(t);
  assert.deepEqual(t.data.adr.decision_drivers.value, ['a', 'b']);
});

test('decision_drivers null when no source matches', () => {
  const t = tree(h(1, 'X'), p('just prose'));
  extractAdr({ filePath: '/tmp/x.md' })(t);
  assert.equal(t.data.adr.decision_drivers, null);
});

test('extracts options from "Approach A/B/C" H3 headings', () => {
  const t = tree(
    h(1, 'X'),
    h(2, 'Considered options'),
    h(3, 'Approach A — fast'),
    p('summary A'),
    { type: 'list', children: [
      { type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: '+ pro a1' }] }] }
    ]},
    h(3, 'Approach B — slow (Rejected)'),
    p('summary B'),
  );
  extractAdr({ filePath: '/tmp/x.md' })(t);
  const opts = t.data.adr.considered_options.value;
  assert.equal(opts.length, 2);
  assert.equal(opts[0].name, 'Approach A — fast');
  assert.equal(opts[0].verdict, null);
  assert.equal(opts[1].verdict, 'rejected');
  assert.match(opts[0].summary, /summary A/);
});

test('considered_options gets n/a when fewer than 2 options detected', () => {
  const t = tree(h(1, 'X'), h(3, 'Approach A'), p('only one'));
  extractAdr({ filePath: '/tmp/x.md' })(t);
  assert.equal(t.data.adr.considered_options, null);
});
