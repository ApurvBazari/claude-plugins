/* Builds the golden system-map page from the real sources: the page scaffold, the interactivity
   bundle, the system-map recipe's CSS and the fixture graphs. It renders each graph the way the
   recipe tells a producer to, so the page doubles as a worked example of the page contract.

   Usage: node build-sample.js <out.html> [--inserted]
     default      the engine block holds only the marker line (what the assemble stage produces)
     --inserted   the marker line is replaced by the engine file (what the write stage produces)

   The committed fixture tests/walkthrough/fixtures/sysmap-sample.html is the --inserted output.
   Regenerate it after changing the scaffold, the bundle, the recipe CSS, the engine or the fixtures. */
'use strict';
const fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../../..');
const REF = path.join(ROOT, 'walkthrough/skills/create/references');
const F = require('./fixtures.js');
const read = p => fs.readFileSync(path.join(REF, p), 'utf8');
const blocks = (md, lang) => { const out = []; md.replace(new RegExp('```' + lang + '\\n([\\s\\S]*?)\\n```', 'g'), (_, b) => { out.push(b); return ''; }); return out; };
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const MARK = { added: '+ added', modified: '~ modified', deleted: '- deleted' };
const KINDS = ['actor', 'service', 'store', 'queue', 'external'];

// One graph -> the .sysmap block of the page contract. `details` is the set of ids that have a detail.
function renderMap(g, details) {
  const kids = Object.create(null), byId = Object.create(null);
  g.nodes.forEach(n => { byId[n.id] = n; kids[n.id] = []; });
  const top = [];
  g.nodes.forEach(n => { (n.parent != null && kids[n.parent] ? kids[n.parent] : top).push(n); });
  const inside = (id, anc) => { let p = byId[id].parent; while (p != null) { if (p === anc) return true; p = byId[p].parent; } return false; };
  const leafCount = n => kids[n.id].length ? kids[n.id].reduce((s, k) => s + leafCount(k), 0) : 1;
  const marked = n => g.nodes.filter(x => x.change && inside(x.id, n.id)).length +
    g.edges.filter(e => e.change && inside(e.from, n.id) && inside(e.to, n.id)).length;
  const wire = id => details.has(id) ? ' role="button" tabindex="0" aria-label="' + esc(byId[id].label) + '" onclick="openSurface(\'' + id + '\')"' : '';
  const attrs = n => (n.change ? ' data-change="' + n.change + '"' : '') + (n.inferred ? ' data-inferred' : '');
  const mark = n => n.change ? '<span class="sys-mark" data-m="' + n.change + '">' + MARK[n.change] + '</span>' : '';

  function box(n) {
    if (kids[n.id].length) {
      const open = n.open === true || n.open === false ? ' data-open="' + n.open + '"' : '', chg = marked(n);
      return '<div class="sys-group" data-id="' + esc(n.id) + '"' + open + attrs(n) + '><div class="sys-ghead">' +
        '<button class="sys-tog" aria-expanded="true" aria-label="Expand or collapse ' + esc(n.label) + '"></button>' +
        '<span class="sys-label"' + wire(n.id) + '>' + esc(n.label) + '</span>' + mark(n) + (n.inferred ? '<span class="sys-kind">inferred</span>' : '') +
        '<span class="sys-count">' + leafCount(n) + '</span>' + (chg ? '<span class="sys-chg">' + chg + ' changed</span>' : '') +
        '</div><div class="sys-body">' + kids[n.id].map(box).join('') + '</div></div>';
    }
    const kind = n.kind && n.kind !== 'component' ? n.kind : '';
    const kindLine = kind || n.inferred ? '<span class="sys-kind">' + esc(kind) + (kind && n.inferred ? ' &middot; ' : '') + (n.inferred ? 'inferred' : '') + '</span>' : '';
    return '<div class="sys-node" data-id="' + esc(n.id) + '"' + (kind ? ' data-kind="' + kind + '"' : '') + attrs(n) + wire(n.id) + '>' + mark(n) + kindLine +
      '<span class="sys-label">' + esc(n.label) + '</span>' + (n.sub ? '<span class="sys-sub">' + esc(n.sub) + '</span>' : '') + '</div>';
  }
  const rows = g.edges.map(e => {
    const tail = (e.label ? esc(e.label) : '') + (e.flow === 'async' ? ' (async)' : '') + (e.inferred ? ' (inferred)' : '');
    return '<li data-from="' + esc(e.from) + '" data-to="' + esc(e.to) + '" data-label="' + esc(e.label || '') + '" data-flow="' + (e.flow || 'sync') + '"' + attrs(e) + '>' +
      '<b>' + esc(byId[e.from].label) + '</b> &rarr; <b>' + esc(byId[e.to].label) + '</b>' + (tail ? ' <i>' + tail.trim() + '</i>' : '') +
      (e.where || []).map(w => '<code class="sf-loc">' + esc(w) + '</code>').join('') + mark(e) + '</li>';
  }).join('');
  const all = g.nodes.concat(g.edges), key = KINDS.filter(k => g.nodes.some(n => n.kind === k && !kids[n.id].length));
  if (g.edges.some(e => e.flow === 'async')) key.push('async');
  if (all.some(x => x.inferred)) key.push('inferred');
  ['added', 'modified', 'deleted'].forEach(c => { if (all.some(x => x.change === c)) key.push(c); });
  return '<div class="sysmap" data-graph="' + esc(g.slug) + '"' + (g.compareTo ? ' data-compare="' + esc(g.compareTo) + '"' : '') + '>' +
    '<div class="sys-bar"><button data-act="all">expand all</button><button data-act="none">collapse all</button><button data-act="auto">reset</button></div>' +
    '<div class="sys-stage"><svg class="sys-wires" aria-hidden="true"></svg>' + top.map(box).join('') + '</div>' +
    '<details class="sys-conn" open><summary>connections (' + g.edges.length + ')</summary><ol class="sys-links">' + rows + '</ol></details>' +
    (key.length ? '<div class="sys-key">' + key.map(k => '<span><i data-k="' + k + '"></i>' + k + '</span>').join('') + '</div>' : '') + '</div>';
}

function page(inserted) {
  const shop = F.graphs[1], before = F.pair.before, after = F.pair.after, deps = F.graphs[5], nested = F.nested;
  const DET = {}, SURF = {};
  // every leaf with a kind gets a detail, so it is wired; returns the ids for renderMap
  const detailed = (g, name) => new Set(g.nodes.filter(n => n.kind).map(n => {
    DET[n.id] = { k: n.kind, h: n.label, summary: n.label + ' is a ' + n.kind + ' in the ' + name + ' fixture, built on ' + n.sub + '.', where: ['tests/walkthrough/sysmap/fixtures.js'] };
    SURF[n.id] = 'pane';
    return n.id;
  }));
  const sections = [
    ['system', 'the system', 'The <em>system</em>', 'Eighteen boxes in four boundaries, with one cycle: the payments webhook comes back into the gateway.', renderMap(shop, detailed(shop, 'online shop'))],
    ['before', 'before', 'Before the <em>change</em>', 'The shop before search was rebuilt.', renderMap(before, new Set())],
    ['after', 'after', 'After the <em>change</em>', 'The same shop afterwards. Marks show what was added, modified and deleted; dotted items are inferred.', renderMap(after, new Set())],
    ['imports', 'imports', 'Package <em>imports</em>', 'A module dependency graph: unlabelled import wires with shared leaves.', renderMap(deps, new Set())],
    ['nested', 'nested', 'A group inside a <em>group</em>', 'Encoding starts closed inside the open platform and carries a change mark; Recommendations is an inferred boundary; the changed boxes open a detail.', renderMap(nested, detailed(nested, 'video platform'))],
  ];
  const engineBlock = '<script id="wt-sysmap">\n' + (inserted ? fs.readFileSync(path.join(REF, 'system-map-engine.js'), 'utf8').replace(/\n$/, '') : '/*@@SYSMAP-ENGINE@@*/') + '\n</script>';
  const fill = {
    '{{TITLE}}': 'System map sample',
    '{{NAV_LINKS}}': sections.map((s, i) => '<a href="#' + s[0] + '"' + (i ? '' : ' class="on"') + '>' + s[1] + '</a>').join(''),
    '{{KICKER}}': 'FIXTURE &middot; SYSTEM MAP',
    '{{HERO}}': '<div class="eyebrow">golden fixture</div><h1>System map <em>sample</em></h1>' +
      '<p class="lede">Five maps built from the fixture graphs: nested boundaries, a cycle, async and inferred wires, change marks, a plain import graph, ' +
      'and a closed group inside an open one with a marked group, an inferred group and changed boxes that open a detail.</p>',
    '{{SECTIONS}}': sections.map(s => '<section id="' + s[0] + '"><div class="sec-label">' + s[1] + '</div><h2>' + s[2] + '</h2><p class="lede">' + s[3] + '</p>' + s[4] + '</section>').join('\n    '),
    '{{COMPONENT_CSS}}': blocks(read('components/system-map.md'), 'css')[0],
    '{{INTERACTIVITY_JS}}': blocks(read('interactivity.md'), 'js').join('\n'),
    '{{COMPONENT_JS}}': '',
    '{{DATA_JSON}}': JSON.stringify({ DET, SURF }).replace(/<\//g, '<\\/'),
    '{{SHEETS}}': '',
    '{{SYSMAP_ENGINE}}': engineBlock,
  };
  let html = blocks(read('page-scaffold.md'), 'html')[0];
  Object.keys(fill).forEach(slot => {
    if (html.indexOf(slot) < 0) throw new Error('the scaffold has no ' + slot + ' slot');
    html = html.split(slot).join(fill[slot]);
  });
  if (/\{\{[A-Z_]+\}\}/.test(html)) throw new Error('an unfilled slot is left: ' + html.match(/\{\{[A-Z_]+\}\}/)[0]);
  return html + '\n';
}

const out = process.argv[2];
if (!out) { console.error('usage: node build-sample.js <out.html> [--inserted]'); process.exit(2); }
fs.writeFileSync(out, page(process.argv.indexOf('--inserted') > -1));
