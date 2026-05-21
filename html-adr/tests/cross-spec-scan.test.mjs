import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { findMentions } from '../scripts/cross-spec-scan.mjs';

test('finds references to a path in sibling specs', () => {
  const dir = mkdtempSync(join(tmpdir(), 'adr-scan-'));
  writeFileSync(join(dir, 'self.md'), '# Self');
  writeFileSync(join(dir, 'other.md'), 'See foo/bar.mjs for details');
  writeFileSync(join(dir, 'third.md'), 'no relevant content here');

  const hits = findMentions('foo/bar.mjs', join(dir, 'self.md'));
  assert.equal(hits.length, 1);
  assert.equal(hits[0].file.endsWith('other.md'), true);
  rmSync(dir, { recursive: true });
});

test('does not match the source file itself', () => {
  const dir = mkdtempSync(join(tmpdir(), 'adr-scan-self-'));
  writeFileSync(join(dir, 'self.md'), 'mentions foo/bar.mjs');
  const hits = findMentions('foo/bar.mjs', join(dir, 'self.md'));
  assert.equal(hits.length, 0);
  rmSync(dir, { recursive: true });
});
