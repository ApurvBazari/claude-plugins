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

export function buildDataFlow({ headingText, content }) {
  const steps = flatBullets(firstList(content));
  const pills = steps.map(s => {
    const key = escapeHtml(s);
    return `<span class="pipe-step" data-item-type="step" data-step="${key}">${escapeHtml(s)}</span>`;
  }).join('<span class="pipe-arrow">→</span>');
  const ascii = content.find(n => n.type === 'code');
  const asciiBlock = ascii ? `<pre class="ascii-block">${escapeHtml(ascii.value || '')}</pre>` : '';
  return `
<section id="flow" class="widget">
  <div class="widget-head" data-section="flow">
    <div class="widget-icon flow">↳</div>
    <div class="widget-title">${escapeHtml(headingText)}</div>
  </div>
  <div class="widget-body">
    <div class="pipeline">${pills}</div>
    ${asciiBlock}
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
  <div class="widget-head" data-section="edge">
    <div class="widget-icon edge">⚠</div>
    <div class="widget-title">${escapeHtml(headingText)}</div>
    <div class="widget-count">${cases.length} cases</div>
  </div>
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
  <div class="widget-head" data-section="deps">
    <div class="widget-icon deps">⬡</div>
    <div class="widget-title">${escapeHtml(headingText)}</div>
  </div>
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
  <div class="widget-head" data-section="rollback">
    <div class="widget-icon rollback">↶</div>
    <div class="widget-title">${escapeHtml(headingText)}</div>
    <div class="widget-count">${steps.length} steps</div>
  </div>
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
  <div class="widget-head" data-section="test">
    <div class="widget-icon test">✓</div>
    <div class="widget-title">${escapeHtml(headingText)}</div>
  </div>
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
  <div class="widget-head" data-section="${escapeHtml(id)}">
    <div class="widget-icon generic">◇</div>
    <div class="widget-title">${escapeHtml(headingText)}</div>
  </div>
  <div class="widget-body">${content.map(nodeToHtml).join('')}</div>
</section>`;
}

export function buildMermaidBlock({ source }) {
  return `<div class="mermaid-wrap"><pre class="mermaid">${escapeHtml(source)}</pre></div>`;
}
