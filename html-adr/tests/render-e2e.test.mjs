import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { render } from '../scripts/render-adr.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const pluginRoot = join(__dirname, '..');
const fixturesDir = join(__dirname, 'fixtures');
const goldenDir = join(__dirname, 'golden');

function normalize(html) {
  return html
    .replace(/<script id="extraction-log"[\s\S]*?<\/script>/g, '<script id="extraction-log"></script>')
    .replace(/<script id="graph-data"[\s\S]*?<\/script>/g, '<script id="graph-data"></script>')
    .replace(/\s+\n/g, '\n');
}

const fixtures = readdirSync(fixturesDir).filter(f => f.endsWith('.md'));

for (const fname of fixtures) {
  test(`golden: ${fname}`, async () => {
    const tmp = mkdtempSync(join(tmpdir(), 'adr-golden-'));
    const out = join(tmp, basename(fname, '.md') + '.html');
    await render({ src: join(fixturesDir, fname), out, pluginRoot });
    const actual = normalize(readFileSync(out, 'utf8'));
    const goldenPath = join(goldenDir, basename(fname, '.md') + '.html');

    if (process.env.UPDATE_GOLDEN === '1') {
      writeFileSync(goldenPath, readFileSync(out, 'utf8'));
      rmSync(tmp, { recursive: true });
      return;
    }

    const expected = normalize(readFileSync(goldenPath, 'utf8'));
    if (actual !== expected) {
      const actualPath = goldenPath + '.actual.html';
      writeFileSync(actualPath, readFileSync(out, 'utf8'));
      assert.fail(`golden diff for ${fname}. wrote actual to ${actualPath}; run UPDATE_GOLDEN=1 npm test to accept.`);
    }
    rmSync(tmp, { recursive: true });
  });
}
