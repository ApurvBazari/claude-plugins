function escapeHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function confDot(field) {
  if (!field) return '<span class="confidence-dot"></span>';
  return `<span class="confidence-dot ${escapeHtml(field.confidence)}" title="${escapeHtml(field.provenance || '')}"></span>`;
}

function driversChips(field) {
  if (!field?.value?.length) return '';
  return field.value.map(d => `<span class="driver-chip">${escapeHtml(d)}</span>`).join('');
}

function optionCard(opt) {
  const cls = opt.verdict === 'chosen' ? 'option-card chosen' : (opt.verdict === 'rejected' ? 'option-card rejected' : 'option-card');
  const prosHtml = opt.pros?.length ? `
    <div class="option-procon pro">
      <div class="option-procon-label pro">Pros</div>
      <ul>${opt.pros.map(p => `<li>${escapeHtml(p)}</li>`).join('')}</ul>
    </div>` : '';
  const consHtml = opt.cons?.length ? `
    <div class="option-procon con">
      <div class="option-procon-label con">Cons</div>
      <ul>${opt.cons.map(c => `<li>${escapeHtml(c)}</li>`).join('')}</ul>
    </div>` : '';
  return `
  <div class="${cls}">
    <div class="option-name">${escapeHtml(opt.name)}</div>
    <div class="option-summary">${escapeHtml(opt.summary || '')}</div>
    ${prosHtml}${consHtml}
  </div>`;
}

function consequencesBlock(field) {
  if (!field?.value) return '';
  const pos = field.value.positive || [];
  const neg = field.value.negative || [];
  return `
  <div class="adr-field-label">Consequences ${confDot(field)}</div>
  <div class="consequences">
    <div class="cons-box positive">
      <div class="cons-box-label">Positive</div>
      <ul>${pos.map(p => `<li>${escapeHtml(p)}</li>`).join('')}</ul>
    </div>
    <div class="cons-box negative">
      <div class="cons-box-label">Negative</div>
      <ul>${neg.map(n => `<li>${escapeHtml(n)}</li>`).join('')}</ul>
    </div>
  </div>`;
}

export function buildAdrHeader(adr) {
  if (!adr.considered_options || !adr.considered_options.value || adr.considered_options.value.length < 2) {
    return `
<div class="banner banner-info">
  <strong>Rendered as design doc.</strong> This spec doesn't contain a multi-option decision (no <code>## Approach A/B/C</code> headings detected). To force ADR rendering, add an <code>adr:</code> frontmatter block. See <a href="../docs/EXTRACTION-RULES.md">EXTRACTION-RULES.md</a>.
</div>`;
  }
  const decision = adr.decision_outcome?.value || '';
  return `
<section id="adr-header" class="adr-block">
  <h1 class="adr-title">${escapeHtml(adr.title?.value || '')}</h1>

  <div class="adr-decision">
    <div class="adr-decision-label">Decision</div>
    <div class="adr-decision-text">${escapeHtml(decision)}</div>
  </div>

  <div class="adr-grid">
    <div>
      <div class="adr-field-label">Decision drivers ${confDot(adr.decision_drivers)}</div>
      <div class="drivers">${driversChips(adr.decision_drivers)}</div>
    </div>
    <div>
      <div class="adr-field-label">Context ${confDot(adr.context)}</div>
      <div class="context-text">${escapeHtml(adr.context?.value || '')}</div>
    </div>
  </div>

  <div class="options-section">
    <div class="adr-field-label">Considered options ${confDot(adr.considered_options)}</div>
    <div class="options-grid">${adr.considered_options.value.map(optionCard).join('')}</div>
  </div>

  ${consequencesBlock(adr.consequences)}
</section>`;
}
