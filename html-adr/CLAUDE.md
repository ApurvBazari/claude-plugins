# html-adr — internal conventions

Single-file static HTML renderer for design specs. Node + unified/remark/rehype.

## Pipeline

`spec.md → remark-parse → remark-frontmatter → remark-gfm → extract-adr → recognize-sections → build-graph → remark-rehype → rehype-slug → rehype-autolink-headings → rehype-highlight → render-templates → inline-assets → rehype-stringify → spec.html`

## Custom plugins (under `scripts/plugins/`)

| Plugin | Role |
|---|---|
| extract-adr | mdast → ADRFields with confidence + provenance, attached as `tree.data.adr` |
| recognize-sections | mdast H2 walk → `tree.data.sections = [{ type, node }]` |
| build-graph | sections + cross-refs → `tree.data.graph = { nodes, edges }` |
| render-templates | hast transformation: wrap each section's hast subtree in its widget template |
| inline-assets | hast pass: replace external `<link>`/`<script>` refs with inlined content from `html-adr/assets/` |

## Vendored assets

Pinned in `html-adr/assets/`. Refreshed via `scripts/update-vendored-assets.sh` with SHA256 verification.

## Tests

Run `npm test`. Update golden files with `npm run test:update-golden`.

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
- Zero console errors (a global filter drops the headless-Chromium
  favicon-404 so a missing favicon never trips the gate; no other
  suppressions)
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
