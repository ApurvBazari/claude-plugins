import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { getProvenance } from '../scripts/git-provenance.mjs';

function makeTmpRepo() {
  const dir = mkdtempSync(join(tmpdir(), 'adr-git-test-'));
  spawnSync('git', ['init', '-q', '-b', 'main'], { cwd: dir });
  spawnSync('git', ['config', 'user.email', 't@t'], { cwd: dir });
  spawnSync('git', ['config', 'user.name', 'Tester'], { cwd: dir });
  return dir;
}

test('returns date+authors for a tracked file', () => {
  const dir = makeTmpRepo();
  const file = join(dir, 'spec.md');
  writeFileSync(file, '# Hi');
  spawnSync('git', ['add', '.'], { cwd: dir });
  spawnSync('git', ['commit', '-m', 'init', '-q'], { cwd: dir });

  const prov = getProvenance(file);
  assert.ok(prov.date.match(/^\d{4}-\d{2}-\d{2}$/));
  assert.deepEqual(prov.authors, ['Tester']);
  assert.equal(prov.branch, 'main');
  rmSync(dir, { recursive: true });
});

test('returns null fields for an untracked file outside git', () => {
  const dir = mkdtempSync(join(tmpdir(), 'adr-nogit-'));
  const file = join(dir, 'spec.md');
  writeFileSync(file, '# Hi');
  const prov = getProvenance(file);
  assert.equal(prov.date, null);
  assert.deepEqual(prov.authors, []);
  assert.equal(prov.branch, null);
  rmSync(dir, { recursive: true });
});
