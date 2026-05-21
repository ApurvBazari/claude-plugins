import { basename } from 'node:path';

function textOf(node) {
  if (!node) return '';
  if (node.type === 'text') return node.value || '';
  if (!node.children) return '';
  return node.children.map(textOf).join('');
}

function findFirstHeading(tree, depth) {
  return tree.children.find(n => n.type === 'heading' && n.depth === depth) ?? null;
}

function deriveTitleFromFilename(filePath) {
  const base = basename(filePath).replace(/^\d{4}-\d{2}-\d{2}-/, '').replace(/-design\.md$/, '').replace(/\.md$/, '');
  return base.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
}

function extractTitle(tree, filePath) {
  const h1 = findFirstHeading(tree, 1);
  if (h1) return { value: textOf(h1), confidence: 'high', provenance: 'first H1' };
  return { value: deriveTitleFromFilename(filePath), confidence: 'high', provenance: 'filename' };
}

function extractDate(tree, filePath, frontmatter, gitProv) {
  const m = basename(filePath).match(/^(\d{4}-\d{2}-\d{2})-/);
  if (m) return { value: m[1], confidence: 'high', provenance: 'filename prefix' };
  if (frontmatter?.date) return { value: String(frontmatter.date), confidence: 'high', provenance: 'frontmatter' };
  if (gitProv?.date) return { value: gitProv.date, confidence: 'high', provenance: 'git log first-add' };
  return { value: new Date().toISOString().slice(0, 10), confidence: 'low', provenance: 'today (fallback)' };
}

function extractStatus(tree, frontmatter, gitProv) {
  if (frontmatter?.status) return { value: frontmatter.status, confidence: 'high', provenance: 'frontmatter' };
  for (const node of tree.children) {
    if (node.type === 'blockquote') {
      const t = textOf(node);
      const m = t.match(/^\s*Status:\s*(\w+)/i);
      if (m) return { value: m[1].toLowerCase(), confidence: 'high', provenance: 'blockquote' };
    }
    if (node.type === 'paragraph') {
      const t = textOf(node);
      const m = t.match(/^\*\*Status:\*\*\s*(\w+)/i);
      if (m) return { value: m[1].toLowerCase(), confidence: 'high', provenance: 'inline strong' };
    }
  }
  if (gitProv?.branch) {
    const accepted = ['main', 'master'].includes(gitProv.branch);
    return {
      value: gitProv.dirty ? 'draft' : (accepted ? 'accepted' : 'proposed'),
      confidence: gitProv.dirty ? 'low' : 'medium',
      provenance: gitProv.dirty ? 'git dirty' : `branch=${gitProv.branch}`,
    };
  }
  return { value: 'proposed', confidence: 'low', provenance: 'default' };
}

function extractAuthors(frontmatter, gitProv) {
  if (frontmatter?.decision_makers) return { value: frontmatter.decision_makers, confidence: 'high', provenance: 'frontmatter' };
  if (gitProv?.authors?.length) return { value: gitProv.authors, confidence: 'high', provenance: 'git log' };
  return null; // omitted
}

const CONTEXT_RE = /^(context|background|goal|problem|why)/i;

function indexBy(tree, predicate) {
  return tree.children.map((n, i) => ({ n, i })).filter(({ n }) => predicate(n));
}

function nodesBetween(tree, fromIdx, untilPred) {
  const out = [];
  for (let i = fromIdx + 1; i < tree.children.length; i++) {
    if (untilPred(tree.children[i])) break;
    out.push(tree.children[i]);
  }
  return out;
}

function extractContext(tree) {
  const ctxH = indexBy(tree, n => n.type === 'heading' && n.depth === 2 && CONTEXT_RE.test(textOf(n)));
  if (ctxH.length > 0) {
    const body = nodesBetween(tree, ctxH[0].i, n => n.type === 'heading' && n.depth <= 2);
    return { value: body.map(textOf).join('\n\n').trim(), confidence: 'high', provenance: `H2 "${textOf(ctxH[0].n)}"` };
  }
  // Fallback: prose between H1 and first H2 of any kind
  const h1Idx = tree.children.findIndex(n => n.type === 'heading' && n.depth === 1);
  if (h1Idx >= 0) {
    const body = nodesBetween(tree, h1Idx, n => n.type === 'heading' && n.depth === 2);
    const text = body.filter(n => n.type === 'paragraph').map(textOf).join('\n\n').trim();
    if (text) return { value: text, confidence: 'medium', provenance: 'prose between H1 and first H2' };
  }
  return null;
}

const DRIVERS_H3_RE = /^(drivers?|constraints?|requirements?|must.?haves?|forces)/i;

function listItemsAfter(tree, idx) {
  const list = tree.children[idx + 1];
  if (!list || list.type !== 'list') return [];
  return list.children.map(li => textOf(li).trim()).filter(Boolean);
}

function extractDrivers(tree, frontmatter) {
  if (frontmatter?.drivers) return { value: frontmatter.drivers, confidence: 'high', provenance: 'frontmatter' };
  const h3 = tree.children.findIndex(n => n.type === 'heading' && n.depth === 3 && DRIVERS_H3_RE.test(textOf(n)));
  if (h3 >= 0) {
    const items = listItemsAfter(tree, h3);
    if (items.length) return { value: items, confidence: 'high', provenance: `H3 "${textOf(tree.children[h3])}"` };
  }
  return null;
}

export function extractAdr({ filePath = '', frontmatter = null, gitProvenance = null } = {}) {
  return function transformer(tree) {
    tree.data = tree.data ?? {};
    tree.data.adr = {
      title: extractTitle(tree, filePath),
      date: extractDate(tree, filePath, frontmatter, gitProvenance),
      status: extractStatus(tree, frontmatter, gitProvenance),
      decision_makers: extractAuthors(frontmatter, gitProvenance),
      context: extractContext(tree),
      decision_drivers: extractDrivers(tree, frontmatter),
    };
  };
}
