---
title: html-adr v0.2 hardening — encode debugging learnings as prevention
status: proposed
date: 2026-05-22
authors:
  - Apurv Bazari
drivers:
  - "A multi-hour debug of \"diagrams don't render in Live Server\" surfaced 6 latent gotchas that the v0.1.0 test surface couldn't catch."
  - "html-adr is the renderer for design specs going forward; silent runtime regressions are particularly costly because they only surface when a reviewer opens the HTML."
  - "v0.1.0 was shipped 2026-05-21; v0.2 is the natural release window to capture these learnings before they're forgotten."
---

# html-adr v0.2 hardening

Encode five learnings from the 2026-05-21 debugging session as automated
prevention mechanisms. One learning (Chrome extension injection on `http://`
origins) was deliberately scoped out: the plugin cannot prevent users from
having content-modifying extensions, and tamper-detect runtime banners would
add complexity disproportionate to the benefit.

The remaining five are addressed as code, test, and policy changes that make
the same class of bug fail at render time or test time rather than at view
time.

## Status

Proposed. Targets `html-adr@0.2.0`. Branch: `feat/html-adr` (currently
identical to `origin/develop` at `a4e2c49`).

## Decision

Adopt five hardening interventions:

1. **(L2 + L5 merged)** Add a Puppeteer-based runtime smoke gate that opens
   each rendered fixture in headless Chromium and asserts zero console errors,
   diagrams rendered, and page navigation completion. Promote the renderer's
   own design spec (`docs/superpowers/specs/2026-05-20-adr-renderer-plugin-design.md`)
   to a seventh smoke fixture, so the dogfood path is exercised under the
   same gate. This eliminates the "self-bootstrapping trap" without requiring
   a standalone baseline file.
2. **(L3)** Modify `inline-assets.mjs` and `templates/shell.html` so each
   inlined library bundle is wrapped with a `// === bundle: <name> sha256:<h> ===`
   marker on its own line, and each `<script id="...">` block opens at column
   1 of its own line. Console errors at "line N" of a 3.4MB rendered file
   then point at a meaningful neighborhood.
3. **(L4)** Codify the Mermaid `securityLevel: 'loose'` choice with an
   inline policy comment in `assets/runtime.js`, plus a `render-templates.test.mjs`
   assertion that the rendered output contains the literal `securityLevel: 'loose'`.
4. **(L6)** Add a `validateScriptBody` function in `inline-assets.mjs` that
   hard-fails the render if any vendored bundle contains a `<!--` token before
   a `<script` token (the HTML5 script-data-double-escape trigger). Existing
   `escapeScriptClose` already handles the simpler `</script>` case; this
   complements it.
5. **(L1 dropped)** No runtime tamper detection. README and CLAUDE.md will
   not document Chrome extension injection as a known issue, because doing
   so would normalize a user-side problem the plugin has no agency over.

## Drivers (expanded)

The 2026-05-21 debug session traced the symptom "Mermaid + Cytoscape diagrams
fail to render when the file is served via Live Server, but work via
`file://`" through:

- A `SyntaxError` at HTML line 5939 inside the 115KB-long minified Mermaid
  bundle, reported with no usable column information.
- Iframe attribute errors with literal `${iat}` placeholders, suggesting
  Mermaid's internal template literals never evaluated.
- 404s on URL paths that were obviously JavaScript source code
  (`'+Jt.escape(this.src)+'`), suggesting library code leaked into URL
  contexts.
- A `discountcodes-extension-backend` outbound request from a Chrome
  extension active on the user's machine.

Root cause: a Chrome extension's content script was modifying the page at
load time on `http://` origins (Live Server). The extension did not run on
`file://` origins, which is why direct file opens worked. The plugin and
its output were correct; the user's environment was the variable.

The debugging path was painful because:

1. Browser line numbers were useless (single 115KB minified line).
2. Node `--check` parses the same bundle cleanly, so the JS itself isn't
   wrong — diagnostic disagreement between Node and V8 cost time.
3. The rendered HTML being debugged was the renderer's own design spec,
   creating an instinct to suspect the renderer when the renderer was fine.
4. Existing goldens passed because they only compare emitted bytes, not
   runtime behavior.

Each of the five hardenings below addresses one of those pain points so
the next instance of a similar bug is faster to triage or impossible to
ship.

## Architecture

### Pipeline impact

The render pipeline gains one validation gate and one wrapping step inside
the existing `inline-assets` stage:

```
spec.md
  → remark-parse → remark-frontmatter → remark-gfm
  → extract-adr → recognize-sections → build-graph
  → remark-rehype → rehype-slug → rehype-autolink-headings → rehype-highlight
  → render-templates
  → inline-assets ──────────────────────────────┐
       │  for each bundle:                      │
       │    read body                           │
       │    validateScriptBody(body) ◄── L6     │
       │    escapeScriptClose(body)             │
       │    wrapBundle(filename, body) ◄── L3   │
       │  emit                                  │
  → rehype-stringify                            │
  → spec.html ◄────────────────────────────────┘
```

No new stages, no reordering. The inliner becomes the chokepoint for all
five hardening assertions (because every output path goes through it).

### Test gate split

`npm test` (default, fast, ~1–2s) — unit tests, golden comparisons
(normalized via `stripMarkers`), and the `securityLevel` assertion.

`npm run test:smoke` (opt-in, ~14s) — Puppeteer smoke over 7 fixtures.
Run locally before push and in release CI. Not part of regular CI.

Default `npm test` stays cheap enough to run on save; the smoke gate is
the heavyweight catch.

### Test-surface delta

| Regression class | Before v0.2 | After v0.2 |
|---|---|---|
| Section/widget extraction breaks | ✓ unit tests | ✓ unit tests |
| Golden HTML differs from expected | ✓ string-compare | ✓ string-compare (marker-normalized) |
| Inlined bundle corrupted (silent) | ✗ | ✓ validateScriptBody + smoke |
| Bundle update breaks runtime | ✗ | ✓ smoke (every fixture) |
| Mermaid securityLevel drifts | ✗ | ✓ render-templates assertion |
| Console errors at view time | ✗ | ✓ smoke |
| Self-render regression | ✗ | ✓ smoke (7th fixture) |
| Bundle markers missing/wrong | n/a | ✓ inline-assets unit |
| `<!-- … <script` HTML5 trap | ✗ | ✓ validateScriptBody |

## Affected files

### New

- `html-adr/tests/render-runtime.smoke.mjs` — Puppeteer smoke covering 7 fixtures.
- `html-adr/tests/fixtures/self-render-spec.md` — copy of the design spec taken when commit F lands; used as the 7th smoke fixture.
- `html-adr/tests/helpers/serve-on-ephemeral-port.mjs` — small `http.createServer` wrapper returning `{ port, close }`.

### Modified

- `html-adr/scripts/plugins/inline-assets.mjs` — add `wrapBundle()` (markers), `validateScriptBody()` (script-data check), `stripMarkers()` (exported helper).
- `html-adr/templates/shell.html` — newline-isolate each `<script id="X">{{xxxBundle}}</script>` block.
- `html-adr/assets/runtime.js` — codified policy comment + explicit `securityLevel: 'loose'`.
- `html-adr/tests/inline-assets.test.mjs` — 5 new cases (markers + validator + stripMarkers).
- `html-adr/tests/render-templates.test.mjs` — 1 new assertion (`securityLevel: 'loose'` present), plus `stripMarkers()` normalization on existing golden compare.
- `html-adr/tests/render-e2e.test.mjs` — `stripMarkers()` normalization.
- `html-adr/tests/render-adr.test.mjs` — `stripMarkers()` normalization.
- `html-adr/package.json` — `puppeteer` devDependency + `test:smoke` script + glob exclusion so `npm test` skips `*.smoke.mjs`.
- `html-adr/CLAUDE.md` — three new short sections: Bundle markers, Mermaid security policy, Smoke gate.

### Untouched but worth listing

- `html-adr/scripts/render-adr.mjs` — no public API change.
- `html-adr/skills/render/SKILL.md` — no user-facing CLI flag change.
- `html-adr/assets/*` (bundles other than `runtime.js`) — no vendored asset changes.
- `html-adr/tests/golden/*.html` — no regeneration needed (stripMarkers handles diffs).

## Data flow

### Render-time (inliner addition)

For each `{{xxxBundle}}` placeholder in the stringified HTML:

```
filename = PLACEHOLDER_TO_FILE[placeholder]
body     = read(assetsDir, filename)
         ↓
validateScriptBody(body, filename)
         ↓ throws if <!-- precedes <script anywhere in body
body     = escapeScriptClose(body)          # already in v0.1
         ↓
hash     = sha256(body).slice(0, 16)
wrapped  = "\n// === bundle: ${filename} sha256:${hash} ===\n${body}\n"
         ↓
out.replace(token, () => wrapped)
```

The hash is computed over the body *after* `escapeScriptClose` so the
marker reflects the exact bytes that land in the rendered HTML. (Decision:
hashing post-escape is more useful for downstream verification — e.g. SRI
calculations — even though it differs from the on-disk asset's SHA-256.)

### Test-time (smoke loop)

For each smoke fixture:

```
1. render( fixtures/<name>.md ) → in-memory HTML string
2. write to a temp file under a temp dir
3. http.createServer serving the temp dir on port 0; capture port
4. puppeteer.launch({ headless: true })
5. page.goto(http://127.0.0.1:${port}/<name>.html, { timeout: 15000 })
6. wait for fixture-specific predicate
   • diagram fixtures:  window.mermaid?.contentLoaded === true
                       AND  document.querySelectorAll('.mermaid svg').length >= expected
   • graph fixtures:    document.querySelector('#overview-graph svg').children.length > 0
   • minimal fixtures:  just page load
7. assert page.on('console', 'error') and page.on('pageerror') are empty
8. browser.close(); server.close()
```

Per-fixture pass criteria are listed in the test plan section below.

## Edge cases

### EC1 — Vendored asset legitimately contains `<!--`
The Mermaid bundle today contains three `<!--` occurrences inside DOMPurify
string literals (e.g. `"<!-->"`). None are followed by `<script`. The
`validateScriptBody` check correctly passes today and would correctly fail
a future Mermaid version that added a `"<script>"` string literal. The
maintainer's recovery path is documented in error-handling below.

### EC2 — Asset SHA changes break golden compare
Without normalization, every vendored asset bump (e.g. Mermaid 11.4.1 →
11.5.0) would change the SHA in every marker, which would change every
rendered HTML's bytes, which would break every golden. `stripMarkers()`
removes marker lines from both sides of every golden comparison, so asset
updates don't trigger spurious test failures. Real rendering changes
(widget HTML, ADR header structure) still surface.

### EC3 — Puppeteer not installed
`render-runtime.smoke.mjs` starts with a preflight `await import('puppeteer')`
inside a try/catch that prints "Run `npm install` in html-adr/" with exit 1
before the test framework reports a confusing module-resolution error.

### EC4 — Puppeteer Chromium download blocked
Some networks/CI environments block the Puppeteer install-time Chromium
download. CLAUDE.md will document the `PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1`
+ `PUPPETEER_EXECUTABLE_PATH=<system-chrome>` workaround.

### EC5 — Console error from a Mermaid parse-failure fixture
`malformed-mermaid.md` deliberately contains invalid Mermaid syntax to
exercise the renderer's error widget. Mermaid will emit a parse error to
the console. The smoke test for this fixture asserts *zero `pageerror`
events* (thrown JS) but allows console errors of type `error` whose text
matches `/Parse error|Lexical error/`. All other fixtures require zero
console errors.

### EC6 — Self-render fixture diverges from canonical design spec
The 7th smoke fixture is a *copy* of `docs/superpowers/specs/2026-05-20-adr-renderer-plugin-design.md`
taken at the time commit F lands, stored at `html-adr/tests/fixtures/self-render-spec.md`.
Future edits to the canonical spec do not propagate to the fixture, and
the fixture does not propagate back. This is deliberate: the test is a
"does the renderer handle a known-realistic large input cleanly" gate,
not a "render the currently-current design doc" check. Documented in
CLAUDE.md.

### EC7 — `validateScriptBody` false positive
A future bundle might legitimately contain `<!--` followed by a string
literal `"<script>"` without any HTML-parsing concern (because both are
inside JS string literals). The validator flags this conservatively.
Recovery path: either re-vendor with the offending strings escaped
(`"<\\!--"`, `"<\\script>"`), or extend the validator with an
allowlist mechanism. The conservative default is correct: today's HTML
parser does not respect JS string boundaries, so the warning is real even
if the runtime impact happens to be benign.

## Error handling

### Render-time errors

| Source | Trigger | Presentation |
|---|---|---|
| `read()` | Missing vendored asset file | `inline-assets: cannot read <file> from <dir>: <fsError>` (existing) |
| `validateScriptBody` | `<!--` before `<script` in any bundle | `inline-assets: <file> contains '<!--' before '<script' — would trigger HTML5 script-data-double-escape. Bundle must be re-vendored with the offending strings escaped, or the inliner must be extended.` |
| `wrapBundle` | n/a — pure function over strings | n/a |

All render-time failures exit `render-adr.mjs` non-zero with the message
on stderr. No partial output is written.

### Test-time errors

| Source | Trigger | Presentation |
|---|---|---|
| `render-templates.test.mjs` | `securityLevel: 'loose'` absent in rendered HTML | `AssertionError: expected rendered HTML to contain "securityLevel: 'loose'"` |
| `inline-assets.test.mjs` | Marker missing, hash nondeterministic, or validator silent on tainted input | Per-case AssertionError with the failing fixture |
| `render-runtime.smoke.mjs` | Console errors, page errors, or diagrams not rendered for a smoke fixture | `AssertionError: smoke <fixture>: <reason>` with captured console / page messages |
| `render-runtime.smoke.mjs` | Puppeteer not installed | Preflight prints "Run `npm install` in html-adr/" and exits 1 before the test framework starts |
| `render-runtime.smoke.mjs` | Local server `EADDRINUSE` | Cannot happen — port 0 (OS-assigned) is used |
| `render-runtime.smoke.mjs` | Puppeteer navigation timeout (15s) | `TimeoutError` from Puppeteer with the fixture name in the test title |

### View-time errors

After v0.2 the rendered HTML still produces no view-time errors when
rendered cleanly. Tamper detection is not implemented (L1 dropped).

## Rollback path

The work lands in 7 commits, each independently revertable. Commit
dependencies:

```
A ── B ── (independent: C, D, E)
          E ── F ── G
```

- **Reverting G** (docs only): no behavioral impact.
- **Reverting F**: removes smoke test file. `test:smoke` script remains but
  has nothing to run. No effect on `npm test`.
- **Reverting E**: removes puppeteer dep and `test:smoke` script. Requires
  reverting F first.
- **Reverting D**: removes the `securityLevel: 'loose'` assertion and the
  policy comment. The render still works; just no longer guarded.
- **Reverting C**: removes the `<!-- … <script` validator. Renderer no
  longer hard-fails on tainted bundles.
- **Reverting B**: removes bundle markers. With A still in place,
  `stripMarkers` becomes a no-op again. All goldens still pass because the
  markers stopped being emitted.
- **Reverting A**: removes the `stripMarkers` wrapping. Requires reverting
  B first (otherwise markers would break golden compares).

Full v0.1.0 behavior is recoverable in one `git revert A^..G` if the
entire v0.2 hardening turns out to be regrettable.

## Testing

### Unit tests (run by `npm test`)

#### `tests/inline-assets.test.mjs` — 5 new cases

1. `emits per-bundle marker with sha256 prefix` — for each of the 6 bundle
   placeholders, rendered output contains `// === bundle: <filename> sha256:<16hex> ===` exactly once.
2. `marker hash is deterministic across renders` — render twice, SHA
   segments match.
3. `validateScriptBody rejects <!-- before <script` — feed a tainted fake
   bundle through, assert throws with the documented message.
4. `validateScriptBody accepts <!-- alone` — fake bundle with `<!-- foo -->`
   but no `<script` follow-up, assert no throw. Locks the today's-Mermaid
   case as legitimate.
5. `stripMarkers removes only marker lines` — round-trip an input with
   mixed marker + body content; output has marker lines removed and
   nothing else changed.

#### `tests/render-templates.test.mjs` — 1 new assertion

6. `mermaid securityLevel is locked to 'loose'` — render any fixture;
   assert rendered HTML contains the literal `securityLevel: 'loose'`.
   Fails on accidental drift.

#### Modified golden compares (no new cases)

In `render-templates.test.mjs`, `render-e2e.test.mjs`, `render-adr.test.mjs`
every `assert.strictEqual(actual, golden)` becomes
`assert.strictEqual(stripMarkers(actual), stripMarkers(golden))`. Behavior
change: zero, because current goldens contain no markers.

### Smoke tests (run by `npm run test:smoke`)

#### `tests/render-runtime.smoke.mjs` — 7 cases, one per fixture

| Fixture | Pass criteria |
|---|---|
| `well-formed-spec.md` | 0 console errors; ≥1 `.mermaid svg`; ≥1 cytoscape node in `#overview-graph`; navigation < 15s |
| `minimal-h1-only.md` | 0 console errors; page loads. No diagrams expected. |
| `no-alternatives-spec.md` | 0 console errors; ≥1 cytoscape node; no Mermaid required. |
| `malformed-mermaid.md` | 0 page errors. Mermaid parse error console messages allowed (matched against `/Parse error|Lexical error/`). |
| `frontmatter-override.md` | 0 console errors; rendered title matches frontmatter `title:`. |
| `ascii-flow-detection.md` | 0 console errors; ASCII flow widget rendered. |
| `self-render-spec.md` | 0 console errors; ≥1 `.mermaid svg`; ≥1 cytoscape node. **The dogfood gate.** |

Per-test shape (skeleton):

```js
test('smoke: <fixture-name>', async () => {
  const html = await renderToString(`fixtures/${fixture}.md`);
  const { port, close } = await serveOnEphemeralPort(html);
  const browser = await puppeteer.launch({ headless: true });
  try {
    const page = await browser.newPage();
    const consoleErrors = [];
    const pageErrors = [];
    page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
    page.on('pageerror', e => pageErrors.push(e.message));
    await page.goto(`http://127.0.0.1:${port}/`, { timeout: 15000, waitUntil: 'networkidle0' });
    await page.waitForFunction(() => /* fixture-specific predicate */, { timeout: 5000 });
    /* fixture-specific assertions on consoleErrors / pageErrors / DOM state */
  } finally {
    await browser.close();
    await close();
  }
});
```

### Implementation order

Seven commits on `feat/html-adr`, with verification checkpoints:

- **A — prep.** Export `stripMarkers()` (currently no-op). Wrap golden-compare tests in it. `npm test` still green; behavior unchanged.
- **B — feat: bundle markers.** Emit `wrapBundle()` output and update `shell.html` to newline-isolate scripts. `stripMarkers()` now does real work. `npm test` still green.
- **C — feat: script-data validator.** Add `validateScriptBody()`. Add unit tests for tainted and clean bundles. `npm test` still green; new tests pass.
- **D — feat: codify Mermaid securityLevel.** Add policy comment + assertion. `npm test` still green; assertion guards the choice.
- **E — chore: add puppeteer + test:smoke script.** No test changes yet. `npm test` unchanged; `npm run test:smoke` exists but bare.
- **F — feat: puppeteer smoke covering 7 fixtures.** Add `render-runtime.smoke.mjs` + `self-render-spec.md` fixture. `npm run test:smoke` runs 7 cases (~14s).
- **G — docs: CLAUDE.md hardening conventions.** Three new short sections; no behavior change.

Each commit is reverable in isolation (A is the only one B depends on; F is the only one E gates; G is purely additive).

## Open questions

None. All design decisions resolved during brainstorm:

- L1 (Chrome extensions): dropped.
- L2 (self-bootstrap): merged into L5 as 7th smoke fixture.
- L3 (line numbers): markers + newline isolation.
- L4 (securityLevel): codify 'loose' + assertion.
- L5 (runtime check): Puppeteer over 7 fixtures, opt-in via `test:smoke`.
- L6 (script-data state): `validateScriptBody` hard-fails on `<!-- … <script` pair.
- Goldens: `stripMarkers` normalization (no regeneration needed).
- CI integration: out of scope for v0.2; flagged as v0.3 follow-up.

## References

- Debugging session that surfaced the learnings: 2026-05-21 (no formal write-up; conversation only).
- Existing renderer pipeline doc: `html-adr/CLAUDE.md`.
- v0.1.0 release notes: `html-adr/CHANGELOG.md`.
- Renderer's own design spec (the dogfood input for L2/L5): `docs/superpowers/specs/2026-05-20-adr-renderer-plugin-design.md`.
- HTML5 script-data state machine (L6 background): https://html.spec.whatwg.org/multipage/parsing.html#script-data-state
