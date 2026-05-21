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

test('escapes </script> inside bundle bodies so they do not close the host tag', () => {
  // runtime.js's JSDoc comment legitimately documents the <script id="graph-data">
  // shape, which means it contains the literal string "</script>". When inlined
  // verbatim into <script id="adr-runtime">...</script>, the HTML parser treats
  // the embedded </script> as the closing tag and parses the rest of the JS
  // body as HTML — producing stray elements and SyntaxErrors on the leaked
  // remainder. The escape is backslash-before-slash: <\/script>. The JS parser
  // ignores the backslash inside a comment / string; the HTML parser does not
  // treat it as a closing tag.
  const dir = mkdtempSync(join(tmpdir(), 'adr-inline-scriptclose-'));
  writeFileSync(
    join(dir, 'runtime.js'),
    '/* JSDoc example: <script>{...}</script>\n   case variants </SCRIPT> </Script> */\nconsole.log("ok");'
  );
  const html = '<script id="adr-runtime">{{runtime}}</script>';
  const out = inlineAssets({ assetsDir: dir })(html);

  // The outer <script id="adr-runtime"> must be the ONLY closing </script> the
  // HTML parser sees at the top level. All inlined </script> sequences must
  // appear as <\/script> (escaped) — case-insensitive match for all variants.
  const rawScriptClosers = (out.match(/<\/script>/gi) || []).length;
  const escapedScriptClosers = (out.match(/<\\\/script/gi) || []).length;
  assert.equal(rawScriptClosers, 1, `expected exactly 1 unescaped </script>, got ${rawScriptClosers}`);
  assert.equal(escapedScriptClosers, 3, `expected 3 escaped script-closers (one per JSDoc variant), got ${escapedScriptClosers}`);
});

test('does not interpret String.replace special patterns inside vendored bundles', () => {
  // Minified bundles routinely contain literal $&, $`, $' etc. as part of
  // regex-escape strings or template syntax. If String.replace expands them
  // as special replacement patterns ($` re-injects the entire pre-match
  // content), the inlined content can be duplicated. Real defect observed:
  // mermaid's pattern occurrences multiplied the cytoscape body 8x in the
  // rendered HTML. The fix passes a function replacement, whose return is
  // emitted verbatim.
  const dir = mkdtempSync(join(tmpdir(), 'adr-inline-patterns-'));
  writeFileSync(join(dir, 'cytoscape-3.30.4.min.js'), 'CY_MARKER');
  // Mermaid bundle body containing every special replacement pattern.
  const meBody = "ME_HEAD $& $` $' $$ $1 ME_TAIL";
  writeFileSync(join(dir, 'mermaid-11.4.1.min.js'), meBody);

  const html = '<a>{{cytoscapeBundle}}</a><b>{{mermaidBundle}}</b>';
  const out = inlineAssets({ assetsDir: dir })(html);

  // Cytoscape body should appear exactly once.
  const cyCount = (out.match(/CY_MARKER/g) || []).length;
  assert.equal(cyCount, 1, `expected CY_MARKER once, got ${cyCount} — pattern bleed`);

  // Mermaid body should appear exactly once, with patterns intact verbatim.
  const meHeadCount = (out.match(/ME_HEAD/g) || []).length;
  const meTailCount = (out.match(/ME_TAIL/g) || []).length;
  assert.equal(meHeadCount, 1);
  assert.equal(meTailCount, 1);
  assert.ok(out.includes('$&'));
  assert.ok(out.includes('$`'));
  assert.ok(out.includes("$'"));
  assert.ok(out.includes('$$'));
});
