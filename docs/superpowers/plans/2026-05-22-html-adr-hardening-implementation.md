# html-adr v0.2 hardening — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land five hardenings (per-bundle markers + `<!--`/`<script` validator + Mermaid `securityLevel` guard + Puppeteer smoke + CLAUDE.md docs) as 7 reversible commits on `feat/html-adr`, so the class of bugs that surfaced in the 2026-05-21 debugging session fails at render or test time, not view time.

**Architecture:** All five interventions go through `html-adr/scripts/plugins/inline-assets.mjs` (the existing inlining chokepoint) and the test surface. No new pipeline stages. Default `npm test` stays sub-2s; opt-in `npm run test:smoke` adds a ~14s Puppeteer gate over 7 fixtures including the renderer's own design spec.

**Tech Stack:** Node 20+, `node:test`, `node:crypto`, `node:http`, Puppeteer 23 (Chromium-only), the existing unified/remark/rehype pipeline.

**Spec:** `docs/superpowers/specs/2026-05-22-html-adr-hardening-design.md` (commit `bfffcbe` on `feat/html-adr`).

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `html-adr/tests/helpers/serve-on-ephemeral-port.mjs` | Tiny `http.createServer` wrapper that serves a directory on an OS-assigned port; returns `{ port, close }`. |
| `html-adr/tests/render-runtime.smoke.mjs` | Puppeteer smoke covering 7 fixtures; opt-in via `npm run test:smoke`. |
| `html-adr/tests/fixtures-smoke/self-render-spec.md` | Copy of the renderer's own design spec; smoke-only (not picked up by golden tests). |

### Modified files

| Path | What changes |
|---|---|
| `html-adr/scripts/plugins/inline-assets.mjs` | Add `wrapBundle`, `validateScriptBody`, `stripMarkers` (exported). Wire `validateScriptBody` + `wrapBundle` into the bundle-replacement loop. |
| `html-adr/assets/runtime.js` | Promote the existing `securityLevel: 'loose'` comment to a 6-line policy block citing the assertion that guards it. |
| `html-adr/tests/inline-assets.test.mjs` | 5 new tests (markers + validator + stripMarkers). |
| `html-adr/tests/render-templates.test.mjs` | 1 new test asserting rendered HTML contains `securityLevel: 'loose'`. |
| `html-adr/tests/render-e2e.test.mjs` | Extend `normalize()` to strip marker lines. |
| `html-adr/package.json` | Add `puppeteer` devDependency + `test:smoke` script. |
| `html-adr/CLAUDE.md` | Three new short sections: Bundle markers, Mermaid security policy, Smoke gate. |

### NOT modified (deviation from spec)

- `html-adr/templates/shell.html` — `wrapBundle()`'s leading/trailing newlines achieve script-tag-isolation without touching the template. Documenting in CLAUDE.md.
- `html-adr/tests/render-adr.test.mjs` — doesn't golden-compare; no normalization wiring needed.
- `html-adr/tests/golden/*.html` — `normalize()` strips markers from both sides; no regeneration.

---

## Pre-flight checks (all commits)

Before starting any commit, verify:

- [ ] On branch `feat/html-adr`, clean working tree.

```bash
cd /Users/apurvbazari/Desktop/projects/claude-plugins
git rev-parse --abbrev-ref HEAD
# Expected: feat/html-adr
git status --short
# Expected: empty output
```

- [ ] Plugin installs cleanly and baseline tests pass.

```bash
cd /Users/apurvbazari/Desktop/projects/claude-plugins/html-adr
npm install --silent
npm test 2>&1 | tail -5
# Expected: tests N pass / 0 fail (baseline green)
```

---

# Commit A — prep: export stripMarkers (no-op) + wire render-e2e normalize

**Goal:** Land the `stripMarkers` export and the `normalize()` call site so when commit B emits markers, goldens still pass. This commit changes ZERO observable behavior — `stripMarkers` is a no-op until B lands.

**Files:**
- Modify: `html-adr/scripts/plugins/inline-assets.mjs`
- Modify: `html-adr/tests/render-e2e.test.mjs`
- Modify: `html-adr/tests/inline-assets.test.mjs` (new test for stripMarkers)

### Task A.1: Add `stripMarkers` export to inline-assets.mjs

- [ ] **Step 1: Write the failing test in `html-adr/tests/inline-assets.test.mjs`**

Append after the existing tests (after line ~93, the last test):

```js
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd html-adr
node --test tests/inline-assets.test.mjs 2>&1 | grep -E '(stripMarkers|fail|pass)' | head
```
Expected: `stripMarkers removes only marker lines, preserves everything else` test fails with `stripMarkers is not a function` (or undefined import).

- [ ] **Step 3: Add `stripMarkers` to `html-adr/scripts/plugins/inline-assets.mjs`**

Append at end of file (after the existing `inlineAssets` export, after line 59):

```js
/**
 * Remove per-bundle marker comment lines from a rendered HTML string.
 *
 * Used by golden-compare tests to keep goldens byte-stable across vendored-asset
 * updates: the marker lines carry SHA-256 of the bundle bytes, which changes
 * every time an asset is bumped. Without this normalization, every asset bump
 * would fail every golden test for no real-behavior reason.
 *
 * No-op when the input contains no marker lines (commit A baseline).
 */
export function stripMarkers(html) {
  return html.replace(/\n\/\/ === bundle: [^\n]+\n/g, '\n');
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
node --test tests/inline-assets.test.mjs 2>&1 | tail -10
```
Expected: all `inline-assets` tests pass, including the new `stripMarkers` case.

### Task A.2: Wire stripMarkers into render-e2e normalize()

- [ ] **Step 5: Modify `html-adr/tests/render-e2e.test.mjs`**

Change the import line at the top (currently only imports `render`) to also import `stripMarkers`:

```js
import { render } from '../scripts/render-adr.mjs';
import { stripMarkers } from '../scripts/plugins/inline-assets.mjs';
```

Replace the `normalize()` function (currently lines 14–19):

```js
function normalize(html) {
  return stripMarkers(html)
    .replace(/<script id="extraction-log"[\s\S]*?<\/script>/g, '<script id="extraction-log"></script>')
    .replace(/<script id="graph-data"[\s\S]*?<\/script>/g, '<script id="graph-data"></script>')
    .replace(/\s+\n/g, '\n');
}
```

Order matters: `stripMarkers` runs first because marker lines are inside `<script>` tags whose contents we then collapse in the next two regexes; running stripMarkers first keeps its regex predictable. With current goldens (no markers), this is a no-op.

- [ ] **Step 6: Run all tests to verify no regression**

```bash
npm test 2>&1 | tail -5
```
Expected: all tests pass (including the 6 golden tests, unchanged).

### Task A.3: Commit A

- [ ] **Step 7: Stage and commit**

```bash
git add scripts/plugins/inline-assets.mjs tests/inline-assets.test.mjs tests/render-e2e.test.mjs
git commit -m "$(cat <<'EOF'
test(html-adr): export stripMarkers, wire into render-e2e normalize

Prep for v0.2 bundle-marker emission (commit B). stripMarkers is a no-op
in this commit (no markers in current output); landing it now means
commit B does not need to regenerate any golden files. Goldens stay
byte-stable across vendored-asset bumps via the marker-stripping path.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Verify commit landed**

```bash
git log -1 --oneline
# Expected: <hash> test(html-adr): export stripMarkers, wire into render-e2e normalize
git status --short
# Expected: empty
```

---

# Commit B — feat: per-bundle markers in inlined scripts

**Goal:** Emit `// === bundle: <name> sha256:<16hex> ===` as the first non-empty line of every inlined vendored bundle. Each `<script id="...">` block ends up isolated on its own line in the rendered HTML, so V8 console line numbers become useful again.

**Files:**
- Modify: `html-adr/scripts/plugins/inline-assets.mjs`
- Modify: `html-adr/tests/inline-assets.test.mjs` (2 new tests)

### Task B.1: Write failing tests for marker emission

- [ ] **Step 1: Add two tests to `html-adr/tests/inline-assets.test.mjs`**

Append after the `stripMarkers` test from Commit A:

```js
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
node --test tests/inline-assets.test.mjs 2>&1 | grep -E '(marker|fail|pass)' | head
```
Expected: both new tests fail with `expected match` errors — the marker comment isn't being emitted yet.

### Task B.2: Implement `wrapBundle` and wire into the inliner

- [ ] **Step 3: Modify `html-adr/scripts/plugins/inline-assets.mjs`**

Add this import at the top (after the existing imports on lines 1–2):

```js
import { createHash } from 'node:crypto';
```

Add `wrapBundle` between `escapeScriptClose` (current line 24–26) and the existing `export function inlineAssets`:

```js
/**
 * Wrap a vendored bundle body with a leading newline + marker comment +
 * trailing newline. Effect on rendered output: every <script id="…">{{X}}</script>
 * occupies multiple lines, so V8 console errors carry meaningful line numbers
 * instead of column-into-a-100KB-minified-line gibberish.
 *
 * The SHA-256 is computed over the POST-escapeScriptClose body — i.e. the exact
 * bytes that land in the rendered HTML. This is the useful fingerprint for
 * downstream verification (e.g. SRI-style checksums); it differs from the
 * on-disk asset's SHA-256, which lives in scripts/update-vendored-assets.sh.
 *
 * 16-hex prefix is a compromise: long enough to be collision-resistant for the
 * handful of bundles we ship, short enough to keep the marker line readable.
 */
function wrapBundle(filename, body) {
  const hash = createHash('sha256').update(body).digest('hex').slice(0, 16);
  return `\n// === bundle: ${filename} sha256:${hash} ===\n${body}\n`;
}
```

Update the bundle-replacement loop (currently lines 42–51 in the existing file). Find:

```js
    for (const [placeholder, filename] of Object.entries(PLACEHOLDER_TO_FILE)) {
      const token = '{{' + placeholder + '}}';
      if (out.includes(token)) {
        // All entries in PLACEHOLDER_TO_FILE land inside <script> tags in
        // shell.html — escape </script> so JS comments containing it don't
        // close the host tag and leak into the page as HTML.
        const body = escapeScriptClose(read(assetsDir, filename));
        out = out.replace(token, () => body);
      }
    }
```

Replace with:

```js
    for (const [placeholder, filename] of Object.entries(PLACEHOLDER_TO_FILE)) {
      const token = '{{' + placeholder + '}}';
      if (out.includes(token)) {
        // All entries in PLACEHOLDER_TO_FILE land inside <script> tags in
        // shell.html — escape </script> so JS comments containing it don't
        // close the host tag and leak into the page as HTML.
        const body = escapeScriptClose(read(assetsDir, filename));
        // Wrap with marker comment for debuggability + provenance.
        // wrapBundle adds leading/trailing newlines, so <script id="X">{{X}}</script>
        // renders as <script id="X">\nMARKER\nBODY\n</script> — each script tag
        // ends up isolated on its own line.
        out = out.replace(token, () => wrapBundle(filename, body));
      }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
node --test tests/inline-assets.test.mjs 2>&1 | tail -15
```
Expected: all inline-assets tests pass — both new marker tests + all existing tests.

- [ ] **Step 5: Run full test suite to verify goldens still pass via stripMarkers**

```bash
npm test 2>&1 | tail -5
```
Expected: all tests pass. The 6 golden tests pass because `normalize()` from commit A now strips the new marker lines on both sides of the comparison.

If goldens fail, double-check `normalize()` in `render-e2e.test.mjs` has `stripMarkers(html)` as the first call in the chain.

### Task B.3: Verify markers appear in a real render

- [ ] **Step 6: Render a fixture and grep for markers**

```bash
node scripts/render-adr.mjs tests/fixtures/minimal-h1-only.md --out /tmp/marker-check.html
grep -E '^// === bundle:' /tmp/marker-check.html
```
Expected: 6 lines of output, one per bundle:
```
// === bundle: cytoscape-3.30.4.min.js sha256:<hex> ===
// === bundle: cytoscape-dagre-2.5.0.min.js sha256:<hex> ===
// === bundle: dagre-0.8.5.min.js sha256:<hex> ===
// === bundle: mermaid-11.4.1.min.js sha256:<hex> ===
// === bundle: highlight-11.10.0.min.js sha256:<hex> ===
// === bundle: runtime.js sha256:<hex> ===
```

- [ ] **Step 7: Verify script tags now open at column 1 of their own line**

```bash
grep -nE '^<script id=' /tmp/marker-check.html | head -10
```
Expected: each `<script id="…">` is on its own line, starting at column 1.

### Task B.4: Commit B

- [ ] **Step 8: Stage and commit**

```bash
git add scripts/plugins/inline-assets.mjs tests/inline-assets.test.mjs
git commit -m "$(cat <<'EOF'
feat(html-adr): per-bundle sha256 marker comments

Wrap every inlined vendored bundle in a marker line of the form
`// === bundle: <filename> sha256:<16hex> ===`. Each <script id="…">
block now occupies multiple lines in the rendered HTML, so V8 console
errors at "line N" of a 3.3MB page now point at a meaningful neighborhood
(the marker line names the offending bundle).

The hash is over the post-escapeScriptClose body — i.e. the bytes that
actually ship in the HTML — useful as an SRI-style fingerprint for
downstream verification. Differs from the on-disk asset SHA (which
update-vendored-assets.sh tracks).

Goldens stay byte-stable: stripMarkers (commit A) removes marker lines
from both sides before comparison.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 9: Verify commit landed**

```bash
git log -1 --oneline
# Expected: <hash> feat(html-adr): per-bundle sha256 marker comments
```

---

# Commit C — feat: script-data-state validator for `<!--` + `<script` pair

**Goal:** Add a `validateScriptBody` function that hard-fails the render if any vendored bundle contains `<!--` followed (anywhere) by `<script`. Today's bundles don't trip this, but a future vendored-asset bump might — we want fail-fast at render time, not silent corruption at view time.

**Files:**
- Modify: `html-adr/scripts/plugins/inline-assets.mjs`
- Modify: `html-adr/tests/inline-assets.test.mjs` (2 new tests)

### Task C.1: Write failing tests for the validator

- [ ] **Step 1: Add two tests to `html-adr/tests/inline-assets.test.mjs`**

Append after the marker tests from Commit B:

```js
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
node --test tests/inline-assets.test.mjs 2>&1 | grep -E '(validateScriptBody|fail|pass)' | head
```
Expected: the first test (rejection) fails because no throw happens; the second test (acceptance) actually passes already (no validator exists). The rejection test is the one we need to make pass.

### Task C.2: Implement validateScriptBody and wire it in

- [ ] **Step 3: Add `validateScriptBody` to `html-adr/scripts/plugins/inline-assets.mjs`**

Add between the existing `escapeScriptClose` function and the new `wrapBundle` function:

```js
/**
 * Reject vendored bundles that would trigger HTML5 script-data-double-escape.
 *
 * When the HTML parser's script-data state sees a `<!--`, it enters
 * "script-data-escaped state". If it then sees `<script` (a tag-name start)
 * before any `-->`, it enters "script-data-double-escaped state". In that
 * state, the next `</script>` is treated as text, not as the closing tag.
 * Effect: the real outer </script> in shell.html no longer closes the host
 * tag, the bundle "leaks" into HTML context, and downstream parsing breaks
 * in non-obvious ways.
 *
 * Today's Mermaid bundle contains three `<!--` substrings inside DOMPurify
 * string literals (`"<!-->"`, `"<!---->"`) but no `<script` substrings — so
 * it's safe. A future vendored update that adds a `<script` literal anywhere
 * after a `<!--` would silently break. This validator turns that into a
 * loud render-time error.
 *
 * Recovery for a maintainer who hits this: re-vendor the asset with the
 * offending string literals escaped (e.g. "<\\!--" or "<\\script>"), bump
 * the on-disk SHA, commit. Or extend the validator with an allowlist if
 * the pattern is determined to be benign in context.
 */
function validateScriptBody(body, filename) {
  const commentOpen = body.indexOf('<!--');
  if (commentOpen === -1) return;
  const trailer = body.slice(commentOpen);
  if (/<script[\s/>]/i.test(trailer)) {
    throw new Error(
      `inline-assets: ${filename} contains '<!--' before '<script' — ` +
      `would trigger HTML5 script-data-double-escape. Bundle must be ` +
      `re-vendored with the offending strings escaped, or the inliner ` +
      `must be extended with an allowlist.`
    );
  }
}
```

Update the bundle loop body to call the validator. Find (in the inner block of the for-loop):

```js
        const body = escapeScriptClose(read(assetsDir, filename));
        // Wrap with marker comment for debuggability + provenance.
```

Replace with:

```js
        const raw = read(assetsDir, filename);
        validateScriptBody(raw, filename);
        const body = escapeScriptClose(raw);
        // Wrap with marker comment for debuggability + provenance.
```

The validator runs on the RAW body (pre-escape) because that's the source-of-truth content the maintainer would need to fix.

- [ ] **Step 4: Run tests to verify they pass**

```bash
node --test tests/inline-assets.test.mjs 2>&1 | tail -10
```
Expected: all inline-assets tests pass, including the two new validator cases.

- [ ] **Step 5: Run full test suite**

```bash
npm test 2>&1 | tail -5
```
Expected: all tests pass — real Mermaid bundle today contains `<!--` but no `<script` follow-up, so the validator is a no-op on real bundles.

### Task C.3: Commit C

- [ ] **Step 6: Stage and commit**

```bash
git add scripts/plugins/inline-assets.mjs tests/inline-assets.test.mjs
git commit -m "$(cat <<'EOF'
feat(html-adr): validate vendored bundles for HTML5 double-escape trigger

Hard-fail the render if any inlined bundle contains '<!--' followed
anywhere by '<script' — the trigger that puts the HTML parser into
script-data-double-escaped state, preventing the real </script> from
closing the host tag.

Today's Mermaid bundle has three legitimate '<!--' substrings inside
DOMPurify string literals (e.g. "<!-->", "<!---->") and no '<script'
substrings — validator is a no-op on real-world inputs. The check is
defensive against future vendored-asset bumps that introduce the
pattern silently.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Verify**

```bash
git log -1 --oneline
# Expected: <hash> feat(html-adr): validate vendored bundles for HTML5 double-escape trigger
```

---

# Commit D — feat: codify Mermaid `securityLevel: 'loose'` policy + test guard

**Goal:** Promote the existing inline comment in `runtime.js` (line 789–791) to a 6-line policy block, and add a `render-templates.test.mjs` assertion that the rendered HTML contains `securityLevel: 'loose'` — so any future drift to `'sandbox'` or removal trips a test.

**Files:**
- Modify: `html-adr/assets/runtime.js`
- Modify: `html-adr/tests/render-templates.test.mjs`

### Task D.1: Write failing test for the securityLevel assertion

- [ ] **Step 1: Add a test to `html-adr/tests/render-templates.test.mjs`**

Append at the end of the file (after the last existing test):

```js
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
```

The test uses dynamic `await import` for `render` because the rest of the file's top-level imports don't include it; this keeps the new test self-contained without disturbing the existing imports.

- [ ] **Step 2: Run test to verify it passes (today's runtime.js already has 'loose')**

```bash
node --test tests/render-templates.test.mjs 2>&1 | grep -E '(securityLevel|fail|pass)' | tail -5
```
Expected: the new test PASSES today, because `runtime.js` line 795 already contains `securityLevel: 'loose'`. This is intentional — the test is a guard against future regression, not a TDD-driven new behavior. We're checking the guard fires correctly NOW so any future change to that line breaks the test.

- [ ] **Step 3: Sanity-check the guard fires on the failure case**

Temporarily edit `html-adr/assets/runtime.js` line 795 to change `'loose'` to `'sandbox'`:

```bash
node -e "const fs = require('fs'); const p = 'assets/runtime.js'; const s = fs.readFileSync(p, 'utf8'); fs.writeFileSync(p, s.replace(\"securityLevel: 'loose'\", \"securityLevel: 'sandbox'\"));"
node --test tests/render-templates.test.mjs 2>&1 | grep -E '(securityLevel|fail)' | tail -3
```
Expected: the test now FAILS with `expected Mermaid securityLevel: "loose" in rendered HTML`.

- [ ] **Step 4: Revert the sanity-check edit**

```bash
node -e "const fs = require('fs'); const p = 'assets/runtime.js'; const s = fs.readFileSync(p, 'utf8'); fs.writeFileSync(p, s.replace(\"securityLevel: 'sandbox'\", \"securityLevel: 'loose'\"));"
node --test tests/render-templates.test.mjs 2>&1 | tail -5
```
Expected: tests pass again.

### Task D.2: Promote the runtime.js comment to a policy block

- [ ] **Step 5: Modify `html-adr/assets/runtime.js` around line 787–795**

Find the current `initMermaid` function:

```js
  function initMermaid() {
    if (typeof window.mermaid === 'undefined' || !window.mermaid.initialize) return;
    // securityLevel:'loose' lets click bindings + inline styles render — these
    // diagrams come from the spec author, not arbitrary user input, so the
    // tradeoff is right for the audience.
    window.mermaid.initialize({
      startOnLoad: true,
      theme: 'neutral',
      securityLevel: 'loose',
```

Replace the comment block (lines 789–791 in current file) with this expanded policy comment:

```js
  function initMermaid() {
    if (typeof window.mermaid === 'undefined' || !window.mermaid.initialize) return;
    // SECURITY POLICY: Mermaid securityLevel = 'loose'.
    // Trade-off:
    //   - 'sandbox' renders each diagram inside a sandboxed iframe. The iframe
    //     does NOT inherit page CSS, so our --accent / --ink CSS variables and
    //     fonts don't reach Mermaid's SVG. We lose theming.
    //   - 'loose' lets diagrams render inline with full page CSS and supports
    //     click bindings + inline styles. Authors are trusted (specs are
    //     hand-written by the dev; not user-input).
    // Guard: tests/render-templates.test.mjs asserts this literal stays as
    // 'loose'. Changing it intentionally requires editing that test too,
    // which forces explicit acknowledgement of the security trade-off in
    // the diff.
    window.mermaid.initialize({
      startOnLoad: true,
      theme: 'neutral',
      securityLevel: 'loose',
```

- [ ] **Step 6: Run tests to verify still green**

```bash
npm test 2>&1 | tail -5
```
Expected: all tests pass — the comment change is purely textual; the `securityLevel: 'loose'` literal is unchanged.

### Task D.3: Commit D

- [ ] **Step 7: Stage and commit**

```bash
git add assets/runtime.js tests/render-templates.test.mjs
git commit -m "$(cat <<'EOF'
feat(html-adr): codify Mermaid securityLevel='loose' as policy + add guard

Promote the existing inline comment in runtime.js initMermaid() to a
named SECURITY POLICY block explaining the loose-vs-sandbox trade-off
(loose keeps page CSS inheritance; sandbox would isolate diagrams in
iframes that don't get our themeVariables / fonts).

Add render-templates.test.mjs assertion that the rendered HTML contains
the literal securityLevel: 'loose'. Future drift to 'sandbox' or
removal breaks this test, forcing the change to be deliberate and
visible in the diff.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Verify**

```bash
git log -1 --oneline
# Expected: <hash> feat(html-adr): codify Mermaid securityLevel='loose' as policy + add guard
```

---

# Commit E — chore: add puppeteer dep + test:smoke script

**Goal:** Add Puppeteer as a devDependency and create the `test:smoke` npm script. No test files yet — that's commit F. This commit is infrastructure only.

**Files:**
- Modify: `html-adr/package.json`

### Task E.1: Install puppeteer

- [ ] **Step 1: Run `npm install --save-dev puppeteer`**

```bash
cd html-adr
npm install --save-dev puppeteer@^23.0.0 2>&1 | tail -10
```
Expected: `added N packages` and no errors. This downloads ~30MB including the bundled Chromium.

If Chromium download fails (corporate network etc.), the command fails. The fallback is documented in CLAUDE.md commit G. For now, treat any failure here as a blocker — retry on a network that allows the download.

- [ ] **Step 2: Verify puppeteer landed in package.json**

```bash
node -e "console.log(JSON.stringify(JSON.parse(require('fs').readFileSync('package.json','utf8')).devDependencies, null, 2))"
```
Expected: output includes `"puppeteer": "^23.0.0"` (or whatever current major).

### Task E.2: Add `test:smoke` script

- [ ] **Step 3: Modify `html-adr/package.json` scripts block**

Find the existing scripts block:

```json
  "scripts": {
    "test": "node --test 'tests/**/*.test.mjs'",
    "test:update-golden": "UPDATE_GOLDEN=1 node --test 'tests/**/*.test.mjs'"
  },
```

Replace with:

```json
  "scripts": {
    "test": "node --test 'tests/**/*.test.mjs'",
    "test:update-golden": "UPDATE_GOLDEN=1 node --test 'tests/**/*.test.mjs'",
    "test:smoke": "node --test 'tests/**/*.smoke.mjs'"
  },
```

The `.smoke.mjs` extension is naturally excluded by the default `npm test` glob (`*.test.mjs`).

- [ ] **Step 4: Verify scripts**

```bash
npm run 2>&1 | head -10
```
Expected: lists `test`, `test:update-golden`, and `test:smoke`.

- [ ] **Step 5: Verify `npm test` is unchanged**

```bash
npm test 2>&1 | tail -3
```
Expected: all existing tests pass; no smoke tests yet so the glob picks up nothing matching `*.smoke.mjs`.

- [ ] **Step 6: Verify `test:smoke` runs (but finds nothing yet)**

```bash
npm run test:smoke 2>&1 | tail -5
```
Expected: Node test runner reports `tests 0` or similar (no `*.smoke.mjs` files yet). Exit 0.

### Task E.3: Commit E

- [ ] **Step 7: Stage and commit**

```bash
git add package.json package-lock.json
git commit -m "$(cat <<'EOF'
chore(html-adr): add puppeteer devDependency + test:smoke script

Infrastructure for the v0.2 Puppeteer smoke gate (commit F adds the
actual smoke tests). The .smoke.mjs extension is naturally excluded by
the default `npm test` glob (`*.test.mjs`), so `npm test` stays fast
and `npm run test:smoke` is opt-in.

Puppeteer 23 (Chromium-only) chosen for ~30MB footprint vs Playwright.
CI integration deferred to v0.3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Verify**

```bash
git log -1 --oneline
# Expected: <hash> chore(html-adr): add puppeteer devDependency + test:smoke script
```

---

# Commit F — feat: puppeteer smoke covering 7 fixtures + self-render fixture

**Goal:** Add the runtime smoke test covering 6 existing fixtures + the renderer's own design spec (7th fixture). For each fixture: render → serve over local HTTP → headless navigate → assert no console errors + diagrams rendered.

**Files:**
- Create: `html-adr/tests/helpers/serve-on-ephemeral-port.mjs`
- Create: `html-adr/tests/render-runtime.smoke.mjs`
- Create: `html-adr/tests/fixtures-smoke/self-render-spec.md`

### Task F.1: Create the HTTP server helper

- [ ] **Step 1: Create `html-adr/tests/helpers/serve-on-ephemeral-port.mjs`**

```bash
mkdir -p tests/helpers
```

Write the file with this content:

```js
/**
 * Serve a directory over HTTP on an OS-assigned port.
 *
 * Returns { port, close } where:
 *   - port:  the port the OS assigned (use http://127.0.0.1:${port}/<file>)
 *   - close: async function that shuts the server down
 *
 * Used by render-runtime.smoke.mjs to exercise rendered HTML in a browser
 * over http:// (rather than file://), matching how reviewers actually open
 * the files via Live Server / a dev preview server.
 *
 * Listening on 127.0.0.1 only — never bind to all interfaces from a test.
 */
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { join, extname } from 'node:path';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg':  'image/svg+xml',
};

export async function serveOnEphemeralPort(rootDir) {
  const server = createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://127.0.0.1');
      let path = url.pathname;
      if (path === '/' || path.endsWith('/')) path += 'index.html';
      const filePath = join(rootDir, path);
      const st = await stat(filePath);
      if (!st.isFile()) { res.writeHead(404); res.end('not file'); return; }
      const body = await readFile(filePath);
      res.writeHead(200, { 'content-type': MIME[extname(filePath)] || 'application/octet-stream' });
      res.end(body);
    } catch (e) {
      res.writeHead(404);
      res.end(String(e?.message || e));
    }
  });

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  const close = () => new Promise((resolve) => server.close(resolve));
  return { port, close };
}
```

- [ ] **Step 2: Sanity-check the helper compiles**

```bash
node -e "import('./tests/helpers/serve-on-ephemeral-port.mjs').then(m => console.log('ok', typeof m.serveOnEphemeralPort))"
```
Expected: `ok function`

### Task F.2: Create the self-render fixture

- [ ] **Step 3: Copy the design spec into fixtures-smoke**

```bash
mkdir -p tests/fixtures-smoke
cp ../docs/superpowers/specs/2026-05-20-adr-renderer-plugin-design.md tests/fixtures-smoke/self-render-spec.md
ls -lh tests/fixtures-smoke/
```
Expected: `self-render-spec.md` exists (~50–100KB markdown).

- [ ] **Step 4: Verify it renders cleanly with the current renderer**

```bash
node scripts/render-adr.mjs tests/fixtures-smoke/self-render-spec.md --out /tmp/self-render-check.html
ls -lh /tmp/self-render-check.html
```
Expected: file rendered (~3–6MB). No errors.

### Task F.3: Write the smoke test

- [ ] **Step 5: Create `html-adr/tests/render-runtime.smoke.mjs`**

```js
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
import { mkdtempSync, copyFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, basename, dirname } from 'node:path';
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

// Per-fixture expectations. Each entry names how to assert "this rendered
// correctly" beyond zero-console-errors.
const FIXTURES = [
  { name: 'well-formed-spec',       dir: fixturesDir,      expectMermaid: true,  expectCytoscape: true,                                            },
  { name: 'minimal-h1-only',        dir: fixturesDir,      expectMermaid: false, expectCytoscape: false,                                           },
  { name: 'no-alternatives-spec',   dir: fixturesDir,      expectMermaid: false, expectCytoscape: true,                                            },
  { name: 'malformed-mermaid',      dir: fixturesDir,      expectMermaid: false, expectCytoscape: false, allowConsoleErrorMatching: /Parse error|Lexical error|mermaid/i },
  { name: 'frontmatter-override',   dir: fixturesDir,      expectMermaid: false, expectCytoscape: false,                                           },
  { name: 'ascii-flow-detection',   dir: fixturesDir,      expectMermaid: false, expectCytoscape: false,                                           },
  { name: 'self-render-spec',       dir: smokeFixturesDir, expectMermaid: true,  expectCytoscape: true,                                            },
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
        await page.waitForFunction(
          () => !!document.querySelector('#overview-graph svg, .overview-graph svg, [data-graph] svg'),
          { timeout: 10000 }
        );
      }
      // Even when neither diagram is expected, the page must finish loading.
      await page.waitForFunction(() => document.readyState === 'complete', { timeout: 5000 });

      // Assertions
      assert.deepStrictEqual(pageErrors, [], `page errors during smoke ${fx.name}: ${pageErrors.join('\n')}`);
      if (fx.allowConsoleErrorMatching) {
        // Some errors are expected (e.g. malformed-mermaid's parse error); allow them
        // but only if every console error matches the documented pattern.
        const unexpected = consoleErrors.filter(m => !fx.allowConsoleErrorMatching.test(m));
        assert.deepStrictEqual(unexpected, [], `unexpected console errors in ${fx.name}: ${unexpected.join('\n')}`);
      } else {
        assert.deepStrictEqual(consoleErrors, [], `console errors during smoke ${fx.name}: ${consoleErrors.join('\n')}`);
      }
    } finally {
      await browser.close();
      await close();
    }
  });
}
```

- [ ] **Step 6: Run the smoke suite**

```bash
npm run test:smoke 2>&1 | tail -40
```
Expected: 7 tests run; all 7 pass; total time ~10–20s (Chromium launch + 7× navigation).

If any fixture fails, the error message names the fixture and the captured console/page errors. Investigate by:
1. Rendering the offending fixture manually: `node scripts/render-adr.mjs tests/fixtures/<name>.md --out /tmp/debug.html`
2. Opening `/tmp/debug.html` in Chrome and watching DevTools console.
3. Comparing against what the smoke test asserts.

Common adjustment: if a fixture's diagram selector differs (e.g. graph rendered into a different element ID), update the `document.querySelector('#overview-graph svg, …')` selectors in the `waitForFunction` to match the actual DOM.

### Task F.4: Commit F

- [ ] **Step 7: Stage and commit**

```bash
git add tests/helpers/serve-on-ephemeral-port.mjs \
        tests/render-runtime.smoke.mjs \
        tests/fixtures-smoke/self-render-spec.md
git commit -m "$(cat <<'EOF'
feat(html-adr): puppeteer smoke gate covering 7 fixtures

Render each fixture, serve over http://127.0.0.1:<ephemeral>, navigate
in headless Chromium, assert no console errors and diagrams rendered.
The 7th fixture is a copy of the renderer's own design spec at
docs/superpowers/specs/2026-05-20-adr-renderer-plugin-design.md, so
the self-bootstrapping dogfood path is exercised under the same gate
(folds learning #2 into learning #5; spec section "Decision" item 1).

Opt-in via `npm run test:smoke` — the .smoke.mjs extension is naturally
excluded by the default `npm test` glob. Per-fixture pass criteria are
listed in the FIXTURES table; malformed-mermaid allows console errors
matching /Parse error|Lexical error|mermaid/i because that fixture
deliberately exercises Mermaid's parse-error widget.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Verify**

```bash
git log -1 --oneline
# Expected: <hash> feat(html-adr): puppeteer smoke gate covering 7 fixtures
```

---

# Commit G — docs: CLAUDE.md hardening conventions

**Goal:** Document the four new conventions (bundle markers, Mermaid security policy, smoke gate, smoke-fixture dir) in `html-adr/CLAUDE.md` so future-me + future Claude sessions can rely on them.

**Files:**
- Modify: `html-adr/CLAUDE.md`

### Task G.1: Append new sections to CLAUDE.md

- [ ] **Step 1: Modify `html-adr/CLAUDE.md`**

Append at the end of the file (after the existing "Tests" section):

```markdown

## Bundle markers

Every inlined vendored bundle in the rendered HTML carries a marker line:

```
// === bundle: <filename> sha256:<16hex> ===
```

The marker is emitted by `wrapBundle()` in `scripts/plugins/inline-assets.mjs`.
The SHA is computed over the post-`escapeScriptClose` body — i.e. the exact
bytes that ship in the rendered HTML. Two effects:

1. **Debuggability:** V8 console errors at "line N" of a 3.3MB rendered file
   now land near a meaningful marker line that names the offending bundle.
2. **Provenance:** anyone auditing a rendered ADR can verify which version of
   each library was inlined.

The marker is invisible to golden-compare tests because `stripMarkers()`
(exported from `inline-assets.mjs`, used by `tests/render-e2e.test.mjs`'s
`normalize()`) removes marker lines from both sides before string-diff.
This keeps goldens byte-stable across vendored-asset bumps.

`shell.html` itself is NOT modified to put `<script>` tags on their own lines —
`wrapBundle`'s leading/trailing newlines achieve the same isolation in
rendered output without changing the source template.

## Mermaid security policy

`assets/runtime.js` initializes Mermaid with `securityLevel: 'loose'`. The
trade-off (vs. `'sandbox'`):

| Mode | Page CSS reaches Mermaid SVG | Click bindings / inline styles |
|---|---|---|
| `loose` | yes | yes |
| `sandbox` | no (iframe-isolated) | limited |

Spec authors are trusted (single-author dev tool, no user-input rendering).
`'loose'` keeps themed diagrams legible.

A test in `tests/render-templates.test.mjs` asserts that the rendered HTML
contains the literal `securityLevel: 'loose'`. Changing the policy requires
editing the runtime AND the test — making the diff explicit and reviewable.

## Smoke gate

`npm run test:smoke` runs `tests/**/*.smoke.mjs` — a Puppeteer suite that
renders each fixture, serves it over an ephemeral local HTTP server, opens
it in headless Chromium, and asserts:

- Zero `pageerror` events
- Zero console errors (or only matching a fixture-specific allowlist, e.g.
  malformed-mermaid)
- Diagrams rendered when the fixture expects them

This gate is **not** part of `npm test` — adding ~30MB of Puppeteer +
Chromium to every save-cycle is too heavy. Run it manually before pushing
to a feature branch and let release CI run it on the release branch.

CI integration is deferred to v0.3 (there is no CI in `html-adr/` today).

If the Puppeteer Chromium download is blocked by your network:

```
PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1 npm install
PUPPETEER_EXECUTABLE_PATH=/path/to/system-chrome npm run test:smoke
```

## Smoke-only fixtures

Fixtures under `tests/fixtures-smoke/` are picked up by `render-runtime.smoke.mjs`
but **not** by `render-e2e.test.mjs` (which only scans `tests/fixtures/`).
Use this directory for large fixtures (e.g. `self-render-spec.md`, a copy of
the plugin's own design spec) whose ~3MB rendered output would bloat the
golden suite.
```

- [ ] **Step 2: Verify the file parses as Markdown**

```bash
wc -l CLAUDE.md
grep -c '^## ' CLAUDE.md
```
Expected: line count increased by ~80; H2 heading count = 7 (original 4 + new 4).

### Task G.2: Final pre-commit pass

- [ ] **Step 3: Run BOTH gates to confirm everything works end-to-end**

```bash
npm test 2>&1 | tail -5
npm run test:smoke 2>&1 | tail -10
```
Expected: `npm test` all pass; `npm run test:smoke` all 7 pass.

### Task G.3: Commit G

- [ ] **Step 4: Stage and commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(html-adr): CLAUDE.md hardening conventions (markers, security, smoke)

Four new sections capturing v0.2 conventions for future-me + future
Claude sessions:

- Bundle markers — what wrapBundle() emits, why it helps debugging, and
  how stripMarkers() keeps goldens byte-stable.
- Mermaid security policy — loose vs sandbox trade-off and the
  render-templates.test.mjs guard.
- Smoke gate — when to run npm run test:smoke and how to handle blocked
  Chromium downloads.
- Smoke-only fixtures — tests/fixtures-smoke/ lives outside the golden
  scan so large self-render fixtures don't bloat the golden suite.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Verify all 7 commits landed in order**

```bash
git log --oneline -8
# Expected (top to bottom):
#   <G> docs(html-adr): CLAUDE.md hardening conventions (markers, security, smoke)
#   <F> feat(html-adr): puppeteer smoke gate covering 7 fixtures
#   <E> chore(html-adr): add puppeteer devDependency + test:smoke script
#   <D> feat(html-adr): codify Mermaid securityLevel='loose' as policy + add guard
#   <C> feat(html-adr): validate vendored bundles for HTML5 double-escape trigger
#   <B> feat(html-adr): per-bundle sha256 marker comments
#   <A> test(html-adr): export stripMarkers, wire into render-e2e normalize
#   bfffcbe docs(html-adr): hardening design spec for v0.2
```

---

## Post-implementation checklist

- [ ] All 7 commits present on `feat/html-adr`.
- [ ] `npm test` green.
- [ ] `npm run test:smoke` green.
- [ ] No `*.actual.html` files staged accidentally (`git status` clean).
- [ ] CHANGELOG.md NOT updated in this work (separate v0.2 release commit will roll up all of v0.2's changes; this hardening is one input among others).
- [ ] No version bump in `package.json` (still 0.1.0 in this branch; v0.2.0 bump is a separate release commit).

## Rollback path

Each commit is reversible. Dependencies:

```
A ── B ── (independent: C, D, E)
          E ── F ── G
```

To revert the whole v0.2 hardening:

```bash
git revert <G> <F> <E> <D> <C> <B> <A>
```

(reverts in reverse order to avoid intermediate conflicts.)
