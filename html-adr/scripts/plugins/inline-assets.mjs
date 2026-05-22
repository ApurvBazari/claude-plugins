import { readFileSync } from 'node:fs';
import { join } from 'node:path';

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
        out = out.replace(token, () => body);
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
 * Behavior:
 *   - Matches whole lines starting with `// === bundle: ` (multiline anchor),
 *     so markers at the start of the string and consecutive marker lines are
 *     both handled correctly.
 *   - The marker line itself (including its trailing newline) is removed.
 *
 * Used by golden-compare tests to keep goldens byte-stable across vendored-asset
 * updates: the marker lines carry SHA-256 of the bundle bytes, which changes
 * every time an asset is bumped. Without this normalization, every asset bump
 * would fail every golden test for no real-behavior reason.
 *
 * No-op when the input contains no marker lines (commit A baseline).
 */
export function stripMarkers(html) {
  return html.replace(/^\/\/ === bundle: [^\n]+\n/gm, '');
}
