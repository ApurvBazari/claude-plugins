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

test('stripMarkers removes only marker lines, preserves everything else', async () => {
  const { stripMarkers } = await import('../scripts/plugins/inline-assets.mjs');
  const input = [
    '<script id="cytoscape">',
    '// === bundle: cytoscape-3.30.4.min.js sha256:abc123def456789 ===',
    'CYTOSCAPE_BODY_KEEP',
    '</script>',
    '<script id="mermaid">',
    '// === bundle: mermaid-11.4.1.min.js sha256:0123456789abcdef ===',
    'MERMAID_BODY_KEEP',
    '// not a marker — just a regular comment',
    '</script>',
  ].join('\n');

  const out = stripMarkers(input);

  // Marker lines removed.
  assert.doesNotMatch(out, /=== bundle:/);
  // Non-marker content intact, including the regular comment.
  assert.match(out, /CYTOSCAPE_BODY_KEEP/);
  assert.match(out, /MERMAID_BODY_KEEP/);
  assert.match(out, /\/\/ not a marker/);
  // Script tags intact.
  assert.match(out, /<script id="cytoscape">/);
  assert.match(out, /<script id="mermaid">/);
});

test('stripMarkers handles a marker at the start of the input', async () => {
  const { stripMarkers } = await import('../scripts/plugins/inline-assets.mjs');
  const input = '// === bundle: foo.js sha256:abc123def4567890 ===\nBODY\n';
  assert.equal(stripMarkers(input), 'BODY\n');
});

test('stripMarkers handles consecutive marker lines', async () => {
  const { stripMarkers } = await import('../scripts/plugins/inline-assets.mjs');
  const input = [
    'HEAD',
    '// === bundle: a.js sha256:aaaaaaaaaaaaaaaa ===',
    '// === bundle: b.js sha256:bbbbbbbbbbbbbbbb ===',
    'TAIL',
    '',
  ].join('\n');
  const out = stripMarkers(input);
  assert.doesNotMatch(out, /=== bundle:/);
  assert.match(out, /HEAD\nTAIL/);
});

test('emits per-bundle marker with sha256 prefix for every vendored bundle', () => {
  const dir = mkdtempSync(join(tmpdir(), 'adr-inline-markers-'));
  writeFileSync(join(dir, 'cytoscape-3.30.4.min.js'), 'CY_BODY');
  writeFileSync(join(dir, 'cytoscape-dagre-2.5.0.min.js'), 'CYD_BODY');
  writeFileSync(join(dir, 'dagre-0.8.5.min.js'), 'DAG_BODY');
  writeFileSync(join(dir, 'mermaid-11.4.1.min.js'), 'ME_BODY');
  writeFileSync(join(dir, 'highlight-11.10.0.min.js'), 'HL_BODY');
  writeFileSync(join(dir, 'runtime.js'), 'RT_BODY');

  const html = [
    '<script>{{cytoscapeBundle}}</script>',
    '<script>{{cytoscapeDagreBundle}}</script>',
    '<script>{{dagreBundle}}</script>',
    '<script>{{mermaidBundle}}</script>',
    '<script>{{highlightBundle}}</script>',
    '<script>{{runtime}}</script>',
  ].join('\n');

  const out = inlineAssets({ assetsDir: dir })(html);

  // Each bundle has exactly one marker referencing its source filename and a 16-hex sha.
  const markerFor = (file) => new RegExp(`// === bundle: ${file.replace(/\./g, '\\.')} sha256:[0-9a-f]{16} ===`);
  assert.match(out, markerFor('cytoscape-3.30.4.min.js'));
  assert.match(out, markerFor('cytoscape-dagre-2.5.0.min.js'));
  assert.match(out, markerFor('dagre-0.8.5.min.js'));
  assert.match(out, markerFor('mermaid-11.4.1.min.js'));
  assert.match(out, markerFor('highlight-11.10.0.min.js'));
  assert.match(out, markerFor('runtime.js'));

  // Bundle bodies still appear exactly once each.
  assert.equal((out.match(/CY_BODY/g) || []).length, 1);
  assert.equal((out.match(/CYD_BODY/g) || []).length, 1);
  assert.equal((out.match(/DAG_BODY/g) || []).length, 1);
  assert.equal((out.match(/ME_BODY/g) || []).length, 1);
  assert.equal((out.match(/HL_BODY/g) || []).length, 1);
  assert.equal((out.match(/RT_BODY/g) || []).length, 1);
});

test('marker hash is deterministic across renders (same bytes => same hash)', () => {
  const dir = mkdtempSync(join(tmpdir(), 'adr-inline-deterministic-'));
  writeFileSync(join(dir, 'mermaid-11.4.1.min.js'), 'STABLE_BODY_v1');
  const html = '<script>{{mermaidBundle}}</script>';
  const out1 = inlineAssets({ assetsDir: dir })(html);
  const out2 = inlineAssets({ assetsDir: dir })(html);

  // Same input bytes => same hash in the marker.
  const sha = (s) => (s.match(/sha256:([0-9a-f]{16})/) || [])[1];
  assert.equal(sha(out1), sha(out2));
  assert.ok(sha(out1), 'expected a sha256 prefix in marker');
});

test('validateScriptBody rejects bundles where <!-- precedes <script', () => {
  const dir = mkdtempSync(join(tmpdir(), 'adr-inline-tainted-'));
  // Tainted: comment-open before script-tag — would trigger HTML5
  // script-data-double-escape and prevent the real </script> from closing
  // the host tag.
  writeFileSync(
    join(dir, 'mermaid-11.4.1.min.js'),
    'var x = "<!-- something --><script>evil</script>";'
  );
  const html = '<script>{{mermaidBundle}}</script>';
  assert.throws(
    () => inlineAssets({ assetsDir: dir })(html),
    /mermaid-11\.4\.1\.min\.js.*<!--.*<script.*script-data-double-escape/s
  );
});

test('validateScriptBody accepts <!-- without a following <script (the today-Mermaid case)', () => {
  const dir = mkdtempSync(join(tmpdir(), 'adr-inline-clean-comment-'));
  // Mirrors today's real Mermaid bundle: DOMPurify code with "<!-->"
  // string literals and NO <script string-literals.
  writeFileSync(
    join(dir, 'mermaid-11.4.1.min.js'),
    'var x = "<!-->"; var y = "<!---->"; /* no script tags here */'
  );
  const html = '<script>{{mermaidBundle}}</script>';
  // Should not throw.
  const out = inlineAssets({ assetsDir: dir })(html);
  assert.match(out, /<!-->/);
  assert.match(out, /<!---->/);
});
