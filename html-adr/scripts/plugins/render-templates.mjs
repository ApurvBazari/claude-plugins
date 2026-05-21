import { readFileSync } from 'node:fs';
import { join } from 'node:path';

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function fill(template, vars) {
  return template
    .replace(/\{\{#if (\w+)\}\}([\s\S]*?)\{\{\/if\}\}/g, (_, key, body) => (vars[key] ? body : ''))
    .replace(/\{\{(\w+)\}\}/g, (_, key) => (vars[key] != null ? vars[key] : ''));
}

const WIDGET_FOR_TYPE = {
  AFFECTED_FILES: 'affected-files.html',
  DATA_FLOW: 'data-flow.html',
  EDGE_CASES: 'edge-cases.html',
  DEPS_RISKS: 'dependencies-risks.html',
  ROLLBACK: 'rollback-path.html',
  TESTING: 'testing.html',
  GENERIC_PROSE: 'generic-prose.html',
};

function loadTemplate(dir, name) {
  return readFileSync(join(dir, name), 'utf8');
}

function textOf(node) {
  if (!node) return '';
  if (node.type === 'text') return node.value || '';
  if (!node.children) return '';
  return node.children.map(textOf).join('');
}

function affectedFilesItems(content) {
  const list = content.find(n => n.type === 'list');
  if (!list) return [];
  return list.children.map(li => {
    const raw = textOf(li).trim();
    const m = raw.match(/^(.+?)\s*[—-]\s*(new|modified|deleted)\s*$/i);
    if (m) return { path: m[1].trim(), status: m[2].toLowerCase() };
    return { path: raw, status: 'touched' };
  });
}

function affectedFilesList(items) {
  return items.map(it =>
    `<li data-item-type="file" data-path="${escapeHtml(it.path)}" data-status="${escapeHtml(it.status)}">` +
    `<span class="file-icon">▢</span>${escapeHtml(it.path)}` +
    `<span class="file-status ${escapeHtml(it.status)}">${escapeHtml(it.status)}</span></li>`
  ).join('\n');
}

function renderSection(section, dir) {
  if (!WIDGET_FOR_TYPE[section.type]) return '';
  const tpl = loadTemplate(dir, 'widgets/' + WIDGET_FOR_TYPE[section.type]);
  if (section.type === 'AFFECTED_FILES') {
    const items = section.items ?? affectedFilesItems(section.content);
    return fill(tpl, {
      headingText: escapeHtml(section.headingText),
      itemCount: `${items.length} files`,
      items: affectedFilesList(items),
    });
  }
  // Other widgets: simple prose substitution for now (item builders implemented in subsequent tasks)
  return fill(tpl, {
    headingText: escapeHtml(section.headingText),
    itemCount: '',
    id: section.type.toLowerCase(),
    contentHtml: section.content.map(textOf).join('\n').slice(0, 4000),
    items: '',
    steps: '',
    cases: '',
    categories: '',
    depChips: '',
    risks: '',
  });
}

function renderHeader(adr) {
  // Minimal pass — fill the placeholders. Real impl expands further.
  return `<header>${escapeHtml(adr.title?.value ?? '')}</header>`;
}

export function renderTemplates({ templatesDir, meta = {} }) {
  return {
    renderShell(tree) {
      const adr = tree.data?.adr ?? {};
      const sections = tree.data?.sections ?? [];

      const shell = loadTemplate(templatesDir, 'shell.html');
      const adrHeader = renderHeader(adr);
      const sectionsHtml = sections.map(s => renderSection(s, templatesDir)).join('\n');

      return fill(shell, {
        title: escapeHtml(adr.title?.value ?? 'ADR'),
        adrHeader,
        sections: sectionsHtml,
        sourcePath: escapeHtml(meta.sourcePath ?? ''),
        adrId: escapeHtml(meta.adrId ?? ''),
        date: escapeHtml(adr.date?.value ?? ''),
        status: escapeHtml(adr.status?.value ?? 'proposed'),
        brand: escapeHtml(meta.brand ?? 'ADR'),
        plugin: escapeHtml(meta.plugin ?? 'adr'),
        adrVersion: escapeHtml(meta.adrVersion ?? '0.1.0'),
        toc: '',
        graphSection: '',
        sidePanel: '',
        styles: '',
        cytoscapeBundle: '',
        cytoscapeDagreBundle: '',
        dagreBundle: '',
        mermaidBundle: '',
        highlightBundle: '',
        graphDataJson: JSON.stringify(tree.data?.graph ?? { nodes: [], edges: [] }),
        extractionLogJson: JSON.stringify({}),
        runtime: '',
      });
    },
  };
}
