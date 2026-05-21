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

export function extractAdr({ filePath = '', frontmatter = null, gitProvenance = null } = {}) {
  return function transformer(tree) {
    tree.data = tree.data ?? {};
    tree.data.adr = {
      title: extractTitle(tree, filePath),
      date: extractDate(tree, filePath, frontmatter, gitProvenance),
      status: extractStatus(tree, frontmatter, gitProvenance),
      decision_makers: extractAuthors(frontmatter, gitProvenance),
    };
  };
}
