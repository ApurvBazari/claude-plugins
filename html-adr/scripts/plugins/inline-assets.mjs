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

export function inlineAssets({ assetsDir, stylesPath = null }) {
  return function transform(html) {
    let out = html;
    // 1. replace vendored: hrefs with inlined <style>
    out = out.replace(/<link[^>]+href="vendored:([^"]+)"[^>]*>/g, (_, filename) => {
      const body = read(assetsDir, filename);
      return `<style data-vendored="${filename}">${body}</style>`;
    });
    // 2. replace {{xxxBundle}} placeholders with file contents
    for (const [placeholder, filename] of Object.entries(PLACEHOLDER_TO_FILE)) {
      if (out.includes('{{' + placeholder + '}}')) {
        out = out.replace('{{' + placeholder + '}}', read(assetsDir, filename));
      }
    }
    // 3. styles.css inlined into {{styles}}
    if (stylesPath && out.includes('{{styles}}')) {
      out = out.replace('{{styles}}', readFileSync(stylesPath, 'utf8'));
    }
    return out;
  };
}
