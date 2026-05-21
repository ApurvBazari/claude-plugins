#!/usr/bin/env node
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { unified } from 'unified';
import remarkParse from 'remark-parse';
import remarkFrontmatter from 'remark-frontmatter';
import remarkGfm from 'remark-gfm';
import yaml from 'js-yaml';
import { extractAdr } from './plugins/extract-adr.mjs';
import { recognizeSections } from './plugins/recognize-sections.mjs';
import { buildGraph } from './plugins/build-graph.mjs';
import { renderTemplates } from './plugins/render-templates.mjs';
import { inlineAssets } from './plugins/inline-assets.mjs';
import { getProvenance } from './git-provenance.mjs';

export function preflight({ src, pluginRoot }) {
  if (!existsSync(src)) return { ok: false, error: `source not found: ${src}` };
  if (!src.endsWith('.md')) return { ok: false, error: `source must end in .md: ${src}` };
  if (!existsSync(join(pluginRoot, 'node_modules'))) return { ok: false, error: `node_modules missing; run: npm install --prefix ${pluginRoot}` };
  for (const a of ['cytoscape-3.30.4.min.js', 'mermaid-11.4.1.min.js', 'runtime.js']) {
    const ap = join(pluginRoot, 'assets', a);
    if (!existsSync(ap)) return { ok: false, error: `asset missing: ${ap} (run scripts/update-vendored-assets.sh)` };
  }
  return { ok: true };
}

function parseFrontmatter(tree) {
  const yamlNode = tree.children.find(n => n.type === 'yaml');
  if (!yamlNode) return null;
  try { return yaml.load(yamlNode.value); }
  catch (e) { throw new Error(`Frontmatter YAML parse error: ${e.message}`); }
}

export async function render({ src, out, pluginRoot, open = false }) {
  if (!existsSync(src)) throw new Error(`source not found: ${src}`);
  const source = readFileSync(src, 'utf8');

  const processor = unified()
    .use(remarkParse)
    .use(remarkFrontmatter, ['yaml'])
    .use(remarkGfm);

  const tree = processor.parse(source);
  await processor.run(tree);

  const frontmatter = parseFrontmatter(tree);
  const adrFm = frontmatter?.adr ?? null;
  const sectionsOverride = frontmatter?.sections_override ?? null;
  const gitProvenance = getProvenance(src);

  extractAdr({ filePath: src, frontmatter: adrFm, gitProvenance })(tree);
  recognizeSections({ sectionsOverride })(tree);
  buildGraph()(tree);

  const meta = {
    sourcePath: resolve(src),
    adrId: `ADR-${(adrFm?.id ?? '0001').toString().padStart(4, '0')}`,
    brand: 'ADR',
    plugin: 'html-adr',
    adrVersion: '0.1.0',
  };

  const renderer = renderTemplates({
    templatesDir: join(pluginRoot, 'templates'),
    meta,
  });
  let html = renderer.renderShell(tree);

  html = inlineAssets({
    assetsDir: join(pluginRoot, 'assets'),
    stylesPath: join(pluginRoot, 'templates', 'styles.css'),
  })(html);

  writeFileSync(out, html, 'utf8');

  if (open) {
    const { spawnSync } = await import('node:child_process');
    const opener = process.platform === 'darwin' ? 'open' : 'xdg-open';
    spawnSync(opener, [out], { stdio: 'ignore' });
  }
}

function parseArgs(argv) {
  const args = { src: null, out: null, open: false, noOverwrite: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--out') { args.out = argv[++i]; continue; }
    if (a === '--open') { args.open = true; continue; }
    if (a === '--no-overwrite') { args.noOverwrite = true; continue; }
    if (!args.src) args.src = a;
  }
  return args;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const __filename = fileURLToPath(import.meta.url);
  const pluginRoot = dirname(dirname(__filename));
  const args = parseArgs(process.argv.slice(2));
  if (!args.src) {
    console.error('usage: render-adr.mjs <path-to-spec.md> [--out <path>] [--open] [--no-overwrite]');
    process.exit(2);
  }
  if (!args.out) args.out = args.src.replace(/\.md$/, '.html');
  const pre = preflight({ src: args.src, pluginRoot });
  if (!pre.ok) { console.error('✗ ' + pre.error); process.exit(1); }
  if (args.noOverwrite && existsSync(args.out)) {
    console.error(`output exists: ${args.out} (use without --no-overwrite to overwrite)`);
    process.exit(3);
  }
  try {
    await render({ src: args.src, out: args.out, pluginRoot, open: args.open });
    console.log(`✓ rendered ${args.src} → ${args.out}`);
  } catch (e) {
    console.error(`✗ ${e.message}`);
    process.exit(1);
  }
}
