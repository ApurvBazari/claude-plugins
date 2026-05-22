import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';

const PLACEHOLDER_TO_FILE = {
  cytoscapeBundle: 'cytoscape-3.30.4.min.js',
  cytoscapeDagreBundle: 'cytoscape-dagre-2.5.0.min.js',
  dagreBundle: 'dagre-0.8.5.min.js',
  mermaidBundle: 'mermaid-11.4.1.min.js',
  highlightBundle: 'highlight-11.10.0.min.js',
  runtime: 'runtime.js',
};

function read(assetsDir, filename) {
  try { return readFileSync(join(assetsDir, filename), 'utf8'); }
  catch (e) { throw new Error(`inline-assets: cannot read ${filename} from ${assetsDir}: ${e.message}`); }
}

// Any literal </script> sequence inside content that lands in a <script> tag
// will terminate the tag prematurely — the rest of the body then parses as
// HTML, producing stray elements and breaking the embedded JS. The HTML spec
// allows escaping with a backslash before the slash; the JS parser ignores
// the backslash inside the script body. Case-insensitive because the parser
// matches </SCRIPT>, </Script>, etc. equivalently.
function escapeScriptClose(s) {
  return s.replace(/<\/script/gi, '<\\/script');
}

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

export function inlineAssets({ assetsDir, stylesPath = null }) {
  return function transform(html) {
    let out = html;
    // 1. replace vendored: hrefs with inlined <style>
    out = out.replace(/<link[^>]+href="vendored:([^"]+)"[^>]*>/g, (_, filename) => {
      const body = read(assetsDir, filename);
      return `<style data-vendored="${filename}">${body}</style>`;
    });
    // 2. replace {{xxxBundle}} placeholders with file contents.
    //    Use a function callback so special replacement patterns ($&, $`, $', $$, $n)
    //    inside minified vendored bundles are NOT interpreted by String.replace.
    //    Minified bundles routinely contain literal $& and $` substrings (regex escapes,
    //    template strings), and pattern expansion can multiply the output and bleed
    //    earlier-inlined content into later substitutions.
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
    // 3. styles.css inlined into {{styles}} (same callback safeguard).
    if (stylesPath && out.includes('{{styles}}')) {
      const css = readFileSync(stylesPath, 'utf8');
      out = out.replace('{{styles}}', () => css);
    }
    return out;
  };
}

/**
 * Remove per-bundle marker comment lines from a rendered HTML string.
 *
 * Two-pass design — both passes are needed because stripMarkers must reverse
 * what wrapBundle does in real renders AND continue to behave sensibly on
 * hand-crafted inputs that don't include a wrapping <script> tag:
 *
 *   1. Reverse the full wrapBundle wrapper inside <script> tags. wrapBundle
 *      emits `\n// === bundle: X ===\nBODY\n` so that a shell.html line like
 *      `<script id="X">{{X}}</script>` renders as
 *      `<script id="X">\n// === bundle: X ===\nBODY\n</script>` — opener,
 *      marker, body, and closer each on their own line. Stripping only the
 *      marker line would leave the two extra `\n` characters and break the
 *      goldens. So when a marker is bounded by a `<script ...>` opener and a
 *      `</script>` closer, we rewrite the whole span back to
 *      `<script id="X">BODY</script>`.
 *
 *   2. Multiline strip of any remaining standalone marker lines. Handles
 *      markers not nested inside a <script> tag — used by this module's unit
 *      tests and reserved as future-proofing.
 *
 * Used by golden-compare tests to keep goldens byte-stable across vendored-asset
 * updates: the marker lines carry SHA-256 of the bundle bytes, which changes
 * every time an asset is bumped. Without this normalization, every asset bump
 * would fail every golden test for no real-behavior reason.
 *
 * No-op when the input contains no marker lines (commit A baseline).
 */
export function stripMarkers(html) {
  let out = html.replace(
    /(<script[^>]*>)\n\/\/ === bundle: [^\n]+\n([\s\S]*?)\n(<\/script>)/g,
    '$1$2$3'
  );
  out = out.replace(/^\/\/ === bundle: [^\n]+\n/gm, '');
  return out;
}
