import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  buildDataFlow, buildEdgeCases, buildDepsRisks, buildRollback,
  buildTesting, buildGenericProse, buildMermaidBlock,
} from './widget-builders.mjs';
import { buildAdrHeader } from './adr-header-builder.mjs';
// TODO Task 27 dogfood: mermaid auto-detect pass

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
    .replace(/\{\{(\w+)\}\}/g, (m, key) => (key in vars ? vars[key] : m));
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

function affectedFilesList(items, crossMentions = {}) {
  return items.map(it => {
    const mentions = crossMentions[it.path] || 0;
    return `<li data-item-type="file" data-path="${escapeHtml(it.path)}" data-status="${escapeHtml(it.status)}" data-cross-mentions="${mentions}">` +
      `<span class="file-icon">▢</span>${escapeHtml(it.path)}` +
      `<span class="file-status ${escapeHtml(it.status)}">${escapeHtml(it.status)}</span></li>`;
  }).join('\n');
}

function renderSection(section, dir) {
  switch (section.type) {
    case 'AFFECTED_FILES': {
      const items = section.items ?? affectedFilesItems(section.content);
      const tpl = loadTemplate(dir, 'widgets/affected-files.html');
      const itemPayload = JSON.stringify({
        title: section.headingText,
        eyebrow: '#files · section detail',
      }).replace(/'/g, '&#39;');
      return fill(tpl, {
        headingText: escapeHtml(section.headingText),
        itemCount: `${items.length} files`,
        items: affectedFilesList(items),
        itemPayload,
      });
    }
    case 'DATA_FLOW': return buildDataFlow(section);
    case 'EDGE_CASES': return buildEdgeCases(section);
    case 'DEPS_RISKS': return buildDepsRisks(section);
    case 'ROLLBACK': return buildRollback(section);
    case 'TESTING': return buildTesting(section);
    case 'GENERIC_PROSE': return buildGenericProse({
      ...section,
      id: section.headingText.toLowerCase().replace(/\s+/g, '-'),
    });
    default: return '';
  }
}

function renderHeader(adr) { return buildAdrHeader(adr); }

// Section-id mapping must mirror what widget-builders.mjs / affected-files.html
// emit for the <section id="..."> attribute, so TOC anchors actually scroll to
// the rendered widget. Canonical types use short, hard-coded IDs; GENERIC_PROSE
// derives from heading text (matching buildGenericProse's id slugifier).
const SECTION_ANCHOR_BY_TYPE = {
  AFFECTED_FILES: 'files',
  DATA_FLOW: 'flow',
  EDGE_CASES: 'edge',
  DEPS_RISKS: 'deps',
  ROLLBACK: 'rollback',
  TESTING: 'test',
};

function sectionAnchor(section) {
  if (SECTION_ANCHOR_BY_TYPE[section.type]) return SECTION_ANCHOR_BY_TYPE[section.type];
  return section.headingText.toLowerCase().replace(/\s+/g, '-');
}

function buildToc(adr, sections) {
  const items = [];
  if (adr?.title?.value && adr?.considered_options?.value?.length >= 2) {
    items.push({ id: 'adr-header', label: 'Decision' });
  }
  let n = items.length;
  for (const s of sections) {
    n += 1;
    items.push({ id: sectionAnchor(s), label: s.headingText, num: n });
  }
  return items.map((it, i) => {
    const num = String(i + 1).padStart(2, '0');
    return `<li><a href="#${escapeHtml(it.id)}"><span class="toc-num">${num}</span>${escapeHtml(it.label)}</a></li>`;
  }).join('\n');
}

export function renderTemplates({ templatesDir, meta = {} }) {
  return {
    renderShell(tree) {
      const adr = tree.data?.adr ?? {};
      const sections = tree.data?.sections ?? [];

      const shell = loadTemplate(templatesDir, 'shell.html');
      const adrHeader = renderHeader(adr);
      const sectionsHtml = sections.map(s => renderSection(s, templatesDir)).join('\n');
      const toc = buildToc(adr, sections);

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
        toc,
        graphSection: '',
        sidePanel: loadTemplate(templatesDir, 'side-panel.html'),
        graphDataJson: JSON.stringify(tree.data?.graph ?? { nodes: [], edges: [] }),
        extractionLogJson: JSON.stringify({}),
      });
    },
  };
}
