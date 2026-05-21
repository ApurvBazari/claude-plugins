const CANONICAL = [
  ['AFFECTED_FILES', /^(affected files?|files changed|files affected)$/i],
  ['DATA_FLOW', /^(data flow|flow|pipeline|how (it|this) works)$/i],
  ['EDGE_CASES', /^edge cases?$/i],
  ['DEPS_RISKS', /^(dependencies( & risks)?|risks?|threats?)$/i],
  ['ROLLBACK', /^rollback( path)?$/i],
  ['TESTING', /^(testing|tests|test plan)$/i],
];

const CONSUMED_BY_EXTRACT_ADR = [
  /^(approach|option|alternative)\s*[a-c1-3]\b/i,
  /^(context|background|goal|problem|why)$/i,
  /^(recommendation|decision|chosen approach|outcome|verdict)$/i,
  /^consequences?$/i,
];

function textOf(node) {
  if (!node) return '';
  if (node.type === 'text') return node.value || '';
  if (!node.children) return '';
  return node.children.map(textOf).join('');
}

function classify(heading, sectionsOverride) {
  const text = textOf(heading);
  if (sectionsOverride && sectionsOverride[text]) return sectionsOverride[text];
  for (const [type, re] of CANONICAL) {
    if (re.test(text)) return type;
  }
  if (CONSUMED_BY_EXTRACT_ADR.some(re => re.test(text))) return null;
  return 'GENERIC_PROSE';
}

export function recognizeSections({ sectionsOverride = null } = {}) {
  return function transformer(tree) {
    tree.data = tree.data ?? {};
    const sections = [];
    const seen = new Set();

    for (let i = 0; i < tree.children.length; i++) {
      const n = tree.children[i];
      if (n.type !== 'heading' || n.depth !== 2) continue;
      const type = classify(n, sectionsOverride);
      if (!type) continue;
      const text = textOf(n);
      const key = `${type}::${text}`;
      const isDuplicate = seen.has(key);
      seen.add(key);
      // collect content until next H2
      const content = [];
      for (let j = i + 1; j < tree.children.length; j++) {
        const next = tree.children[j];
        if (next.type === 'heading' && next.depth <= 2) break;
        content.push(next);
      }
      sections.push({
        type: isDuplicate ? 'GENERIC_PROSE' : type,
        heading: n,
        content,
        headingText: text,
        confidence: isDuplicate ? 'low' : 'high',
      });
    }
    tree.data.sections = sections;
  };
}
