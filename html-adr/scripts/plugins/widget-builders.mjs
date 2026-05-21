function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function textOf(node) {
  if (!node) return '';
  if (node.type === 'text') return node.value || '';
  if (!node.children) return '';
  return node.children.map(textOf).join('');
}

function flatBullets(list) {
  if (!list || list.type !== 'list') return [];
  return list.children.map(li => textOf(li).trim()).filter(Boolean);
}

function firstList(content, predicate = () => true) {
  return content.find(n => n.type === 'list' && predicate(n)) || null;
}

// Section-level click trigger for the side panel. Runtime's delegated click
// listener dispatches on data-item-type — adding it to widget heads makes
// "click the section card to drill" work end-to-end. The payload mirrors
// what runtime's buildSection consumes.
function widgetHead({ id, icon, iconClass, headingText, countLabel }) {
  const payload = JSON.stringify({
    title: headingText,
    eyebrow: `#${id} · section detail`,
  }).replace(/'/g, '&#39;');
  const count = countLabel != null
    ? `<div class="widget-count">${escapeHtml(countLabel)}</div>`
    : '';
  return `<div class="widget-head" data-section="${escapeHtml(id)}" data-item-type="section" data-item-payload='${payload}'>
    <div class="widget-icon ${iconClass}">${icon}</div>
    <div class="widget-title">${escapeHtml(headingText)}</div>
    ${count}
  </div>`;
}

// Parse an ASCII box-drawing flow diagram into { nodes, edges } suitable for
// Cytoscape. Heuristic but conservative:
//   - A "box" is a region delimited by ┌─┐/└─┘ horizontals on its top and
//     bottom edges, with │…│ content rows between.
//   - The first non-empty content row is the node label; remaining rows
//     accumulate into a description shown in the side panel.
//   - Boxes are connected in document order (top→bottom). Authors can add
//     explicit edge syntax in v0.2 via a frontmatter `flow:` block; for v0.1
//     a single linear chain matches every diagram in our reference corpus.
// Returns null if fewer than 2 boxes are detected — the caller falls back
// to raw ASCII rendering.
function parseAsciiFlow(text) {
  const lines = String(text).split('\n');
  // Allow tee glyphs (┬ ┴) and double-line equivalents inside the horizontal
  // run — boxes whose edges have an outgoing/incoming arrow attach point use
  // these in place of a plain ─ (e.g. `└─┬─┘` for the down-arrow stem). Without
  // tees in the char class, those boxes silently fail to parse.
  const TOP = /[┌╔╭┏][─═┬┴]+[┐╗╮┓]/;
  const BOT = /[└╚╰┗][─═┬┴]+[┘╝╯┛]/;
  const ROW = /^\s*[│║┃]\s*(.*?)\s*[│║┃]\s*$/;

  const boxes = [];
  let current = null;
  for (const line of lines) {
    if (TOP.test(line)) { current = { content: [] }; continue; }
    if (BOT.test(line)) {
      if (current && current.content.length) boxes.push(current);
      current = null;
      continue;
    }
    if (current) {
      const m = line.match(ROW);
      if (m && m[1]) current.content.push(m[1]);
    }
  }
  if (boxes.length < 2) return null;
  const nodes = boxes.map((b, i) => ({
    id: 'n' + i,
    label: b.content[0],
    description: b.content.slice(1).join('\n'),
  }));
  const edges = nodes.slice(0, -1).map((n, i) => ({
    source: n.id,
    target: nodes[i + 1].id,
  }));
  return { nodes, edges };
}

function parseListFlow(content) {
  const list = firstList(content);
  if (!list || !list.children?.length) return null;
  const steps = list.children
    .map(li => textOf(li).trim())
    .filter(Boolean);
  if (steps.length < 2) return null;
  const nodes = steps.map((s, i) => {
    const [label, ...rest] = s.split('\n');
    return { id: 'n' + i, label: label.trim(), description: rest.join('\n').trim() };
  });
  const edges = nodes.slice(0, -1).map((n, i) => ({
    source: n.id,
    target: nodes[i + 1].id,
  }));
  return { nodes, edges };
}

function flowGraphFrom(content) {
  // ASCII box-drawn diagrams are a strong, intentional signal — prefer them
  // over a bullet list that happens to live elsewhere in the section (e.g.
  // "Pipeline invariants:" enumerations that aren't actually a flow).
  const code = content.find(n => n.type === 'code');
  if (code) {
    const fromAscii = parseAsciiFlow(code.value || '');
    if (fromAscii) return { graph: fromAscii, source: 'ascii', raw: code.value || '' };
  }
  const fromList = parseListFlow(content);
  if (fromList) return { graph: fromList, source: 'list', raw: '' };
  return { graph: null, source: null, raw: code?.value || '' };
}

export function buildDataFlow({ headingText, content }) {
  const { graph, source, raw } = flowGraphFrom(content);

  // No detectable structure — emit head + raw ASCII (if any) and stop.
  if (!graph) {
    const fallback = raw
      ? `<pre class="ascii-block">${escapeHtml(raw)}</pre>`
      : `<div class="empty-state">No flow detected. Add a bullet list of steps or an ASCII box-drawn diagram.</div>`;
    return `
<section id="flow" class="widget">
  ${widgetHead({ id: 'flow', icon: '↳', iconClass: 'flow', headingText })}
  <div class="widget-body">${fallback}</div>
</section>`;
  }

  const graphJson = JSON.stringify(graph).replace(/'/g, '&#39;');
  const pills = graph.nodes.map(n => {
    const payload = JSON.stringify({
      title: n.label,
      role: n.description || '',
    }).replace(/'/g, '&#39;');
    return `<span class="pipe-step" data-item-type="step" data-step="${escapeHtml(n.label)}" data-item-payload='${payload}'>${escapeHtml(n.label)}</span>`;
  }).join('<span class="pipe-arrow">→</span>');

  const rawBlock = source === 'ascii' && raw
    ? `<pre class="ascii-block flow-raw" hidden>${escapeHtml(raw)}</pre>`
    : '';
  const rawToggle = source === 'ascii' && raw
    ? `<button class="flow-view-btn" data-flow-view="raw" type="button">Raw</button>`
    : '';

  return `
<section id="flow" class="widget">
  ${widgetHead({ id: 'flow', icon: '↳', iconClass: 'flow', headingText, countLabel: `${graph.nodes.length} steps` })}
  <div class="widget-body">
    <div class="flow-toolbar" role="tablist" aria-label="Flow view">
      <button class="flow-view-btn active" data-flow-view="graph" type="button">Graph</button>
      <button class="flow-view-btn" data-flow-view="pipeline" type="button">Pipeline</button>
      ${rawToggle}
    </div>
    <div class="flow-canvas" data-flow-graph='${graphJson}'></div>
    <div class="pipeline flow-pipeline" hidden>${pills}</div>
    ${rawBlock}
  </div>
</section>`;
}

function severityFor(text) {
  const lower = text.toLowerCase();
  if (/\b(must|fail|crash|abort|critical)\b/.test(lower)) return 'high';
  if (/\b(should|warn|may|might)\b/.test(lower)) return 'med';
  return 'low';
}

export function buildEdgeCases({ headingText, content }) {
  const list = firstList(content);
  const cases = list ? list.children : [];
  const cards = cases.map((li, i) => {
    const lines = textOf(li).split('\n');
    const title = lines[0].trim();
    const handling = lines.slice(1).join(' ').trim();
    const sev = severityFor(title);
    return `
    <div class="edge-card severity-${sev}" data-item-type="case" data-case="${i}">
      <div class="edge-title">${escapeHtml(title)}</div>
      <div class="edge-handling">${escapeHtml(handling)}</div>
    </div>`;
  }).join('');
  return `
<section id="edge" class="widget">
  ${widgetHead({ id: 'edge', icon: '⚠', iconClass: 'edge', headingText, countLabel: `${cases.length} cases` })}
  <div class="widget-body">
    <div class="edge-grid">${cards}</div>
  </div>
</section>`;
}

const PKG_RE = /^([@a-z0-9][\w./-]+?)(?:@([\d.x*-]+))?\s*$/i;

export function buildDepsRisks({ headingText, content }) {
  const list = firstList(content);
  const bullets = list ? list.children.map(li => textOf(li).trim()) : [];
  const chips = [];
  const risks = [];
  for (const b of bullets) {
    if (/^risk\s*:/i.test(b) || /\brisk\b/i.test(b.split(/[\s:]/)[0])) {
      risks.push(b.replace(/^risk\s*:\s*/i, ''));
    } else if (PKG_RE.test(b)) {
      const [, name, version = ''] = b.match(PKG_RE);
      chips.push({ name, version });
    } else {
      risks.push(b);
    }
  }
  const chipHtml = chips.map(c =>
    `<span class="dep-chip" data-item-type="dep" data-name="${escapeHtml(c.name)}" data-version="${escapeHtml(c.version)}">${escapeHtml(c.name + (c.version ? '@' + c.version : ''))}</span>`
  ).join('\n');
  const riskHtml = risks.map((r, i) =>
    `<div class="risk-callout" data-item-type="risk" data-risk="${i}">${escapeHtml(r)}</div>`
  ).join('\n');
  return `
<section id="deps" class="widget">
  ${widgetHead({ id: 'deps', icon: '⬡', iconClass: 'deps', headingText })}
  <div class="widget-body">
    ${chips.length ? `<div class="section-eyebrow">Vendored / referenced</div><div class="deps-chips">${chipHtml}</div>` : ''}
    ${risks.length ? `<div class="section-eyebrow">Risks</div>${riskHtml}` : ''}
  </div>
</section>`;
}

export function buildRollback({ headingText, content }) {
  const list = firstList(content);
  const steps = list ? list.children.map(li => textOf(li).trim()) : [];
  const stepHtml = steps.map((s, i) => `
    <div class="rollback-step" data-item-type="rollback-step" data-step="${i + 1}">
      <div class="rollback-num">${String(i + 1).padStart(2, '0')}</div>
      <div class="rollback-text">${escapeHtml(s)}</div>
    </div>`).join('');
  return `
<section id="rollback" class="widget">
  ${widgetHead({ id: 'rollback', icon: '↶', iconClass: 'rollback', headingText, countLabel: `${steps.length} steps` })}
  <div class="widget-body">
    <div class="rollback-card">${stepHtml}</div>
  </div>
</section>`;
}

export function buildTesting({ headingText, content }) {
  const categories = [];
  let current = null;
  for (const n of content) {
    if (n.type === 'heading' && n.depth === 3) {
      current = { name: textOf(n), items: [] };
      categories.push(current);
    } else if (n.type === 'list' && current) {
      current.items = n.children.map(li => textOf(li).trim());
    } else if (n.type === 'list' && !current) {
      current = { name: 'Tests', items: n.children.map(li => textOf(li).trim()) };
      categories.push(current);
    }
  }
  const catHtml = categories.map(c => `
    <div class="test-cat">
      <div class="test-cat-head">${escapeHtml(c.name)}</div>
      <ul class="test-list">
        ${c.items.map((t, i) => `<li data-item-type="test" data-test="${escapeHtml(c.name)}-${i}">${escapeHtml(t)}</li>`).join('')}
      </ul>
    </div>`).join('');
  return `
<section id="test" class="widget">
  ${widgetHead({ id: 'test', icon: '✓', iconClass: 'test', headingText })}
  <div class="widget-body">${catHtml}</div>
</section>`;
}

function nodeToHtml(node) {
  if (node.type === 'paragraph') return `<p>${node.children.map(nodeToHtml).join('')}</p>`;
  if (node.type === 'text') return escapeHtml(node.value || '');
  if (node.type === 'strong') return `<strong>${node.children.map(nodeToHtml).join('')}</strong>`;
  if (node.type === 'emphasis') return `<em>${node.children.map(nodeToHtml).join('')}</em>`;
  if (node.type === 'inlineCode') return `<code>${escapeHtml(node.value || '')}</code>`;
  if (node.type === 'code') return `<pre><code>${escapeHtml(node.value || '')}</code></pre>`;
  if (node.type === 'list') {
    const tag = node.ordered ? 'ol' : 'ul';
    return `<${tag}>${node.children.map(nodeToHtml).join('')}</${tag}>`;
  }
  if (node.type === 'listItem') return `<li>${node.children.map(nodeToHtml).join('')}</li>`;
  if (node.children) return node.children.map(nodeToHtml).join('');
  return '';
}

export function buildGenericProse({ id, headingText, content }) {
  return `
<section id="${escapeHtml(id)}" class="widget">
  ${widgetHead({ id, icon: '◇', iconClass: 'generic', headingText })}
  <div class="widget-body">${content.map(nodeToHtml).join('')}</div>
</section>`;
}

export function buildMermaidBlock({ source }) {
  return `<div class="mermaid-wrap"><pre class="mermaid">${escapeHtml(source)}</pre></div>`;
}
