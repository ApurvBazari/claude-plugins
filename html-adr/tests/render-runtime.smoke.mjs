/**
 * Puppeteer runtime smoke for html-adr.
 *
 * For each fixture: render → serve over http://127.0.0.1:<ephemeral> →
 * launch headless Chromium → navigate → wait for fixture-specific
 * readiness predicate → assert no console errors / no page errors /
 * diagrams rendered.
 *
 * This is the test that would have caught the 2026-05-21 "diagrams don't
 * render in Live Server" class of bug at CI time rather than at view time.
 *
 * Opt-in: run via `npm run test:smoke`. Not picked up by `npm test`
 * because the file uses .smoke.mjs (default test glob is *.test.mjs).
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { render } from '../scripts/render-adr.mjs';
import { serveOnEphemeralPort } from './helpers/serve-on-ephemeral-port.mjs';

// Lazy-load puppeteer with a friendly preflight message so the failure mode
// is "run npm install" rather than a confusing module-resolution stack trace.
let puppeteer;
try {
  ({ default: puppeteer } = await import('puppeteer'));
} catch {
  console.error('Run `npm install` in html-adr/ before running test:smoke (puppeteer not installed).');
  process.exit(1);
}

const __dirname = dirname(fileURLToPath(import.meta.url));
const pluginRoot = join(__dirname, '..');
const fixturesDir = join(__dirname, 'fixtures');
const smokeFixturesDir = join(__dirname, 'fixtures-smoke');

// The static HTTP helper in tests/helpers/ has no favicon to serve, and every
// headless Chromium auto-requests /favicon.ico on first navigation, producing
// a "Failed to load resource: 404" console error that has nothing to do with
// the renderer under test. Filter that one specific incidental error so a
// missing favicon never fails the smoke gate.
const FAVICON_404_PATTERN = /favicon\.ico|Failed to load resource: the server responded with a status of 404/i;

// Per-fixture expectations. Each entry names how to assert "this rendered
// correctly" beyond zero-console-errors.
//
// Notes on the flags at HEAD (feat/html-adr, post-commit 59cb088):
//   - The overview decision-map (#cy, Cytoscape) renders for every fixture
//     whose extracted graph has ≥2 nodes. That covers 6 of 7 fixtures —
//     only minimal-h1-only (single H1, no sections) falls below the threshold.
//   - Cytoscape paints into <canvas> elements (3 stacked layers), not <svg>.
//     The plan's draft selectors targeted SVG; tuned to canvas to match the
//     actual DOM produced by assets/runtime.js initGraph().
//   - No fixture currently produces a Mermaid <pre class="mermaid"> block:
//     buildMermaidBlock exists in scripts/plugins/widget-builders.mjs but is
//     not wired into the render-templates pipeline yet. expectMermaid is set
//     to false everywhere until that auto-detect pass lands (tracked as the
//     "TODO Task 27 dogfood: mermaid auto-detect pass" in render-templates).
//     When it does, flip the expectMermaid flag(s) and the waitForFunction
//     below will start enforcing the SVG presence.
const FIXTURES = [
  { name: 'well-formed-spec',       dir: fixturesDir,      expectMermaid: false, expectCytoscape: true  },
  { name: 'minimal-h1-only',        dir: fixturesDir,      expectMermaid: false, expectCytoscape: false },
  { name: 'no-alternatives-spec',   dir: fixturesDir,      expectMermaid: false, expectCytoscape: true  },
  { name: 'malformed-mermaid',      dir: fixturesDir,      expectMermaid: false, expectCytoscape: true  },
  { name: 'frontmatter-override',   dir: fixturesDir,      expectMermaid: false, expectCytoscape: true  },
  { name: 'ascii-flow-detection',   dir: fixturesDir,      expectMermaid: false, expectCytoscape: true  },
  { name: 'self-render-spec',       dir: smokeFixturesDir, expectMermaid: false, expectCytoscape: true  },
];

for (const fx of FIXTURES) {
  test(`smoke: ${fx.name}`, { timeout: 30000 }, async () => {
    const tmp = mkdtempSync(join(tmpdir(), `adr-smoke-${fx.name}-`));
    const out = join(tmp, `${fx.name}.html`);
    await render({ src: join(fx.dir, `${fx.name}.md`), out, pluginRoot });

    const { port, close } = await serveOnEphemeralPort(tmp);
    const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
    try {
      const page = await browser.newPage();
      const consoleErrors = [];
      const pageErrors = [];
      page.on('console', m => {
        if (m.type() === 'error') consoleErrors.push(m.text());
      });
      page.on('pageerror', e => pageErrors.push(e.message));

      await page.goto(`http://127.0.0.1:${port}/${fx.name}.html`, {
        timeout: 15000,
        waitUntil: 'networkidle0',
      });

      // Wait for runtime init: cytoscape (if expected) renders by DOMContentLoaded;
      // mermaid (if expected) fires startOnLoad => window load. Give both a beat.
      if (fx.expectMermaid) {
        await page.waitForFunction(
          () => typeof window.mermaid !== 'undefined' &&
                document.querySelectorAll('.mermaid svg, pre.mermaid svg').length >= 1,
          { timeout: 10000 }
        );
      }
      if (fx.expectCytoscape) {
        // Cytoscape mounts 3 stacked <canvas> layers inside #cy; presence of any
        // one canvas is the cheapest "the graph painted" predicate. The flow
        // graph widgets (.flow-canvas[data-flow-graph]) also use canvas — either
        // mount path satisfies the cytoscape-rendered assertion.
        await page.waitForFunction(
          () => !!document.querySelector('#cy canvas, .flow-canvas canvas, [data-graph] canvas'),
          { timeout: 10000 }
        );
      }
      // Even when neither diagram is expected, the page must finish loading.
      await page.waitForFunction(() => document.readyState === 'complete', { timeout: 5000 });

      // Assertions
      assert.deepStrictEqual(pageErrors, [], `page errors during smoke ${fx.name}: ${pageErrors.join('\n')}`);

      // Strip incidental favicon 404s before the no-console-errors gate.
      const realConsoleErrors = consoleErrors.filter(m => !FAVICON_404_PATTERN.test(m));
      assert.deepStrictEqual(realConsoleErrors, [], `console errors during smoke ${fx.name}: ${realConsoleErrors.join('\n')}`);
    } finally {
      await browser.close();
      await close();
    }
  });
}
