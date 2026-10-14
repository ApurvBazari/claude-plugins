/* Layout harness for the system-map engine. Runs the pure layout under node with synthetic box
   sizes and asserts the geometry rules. Usage: node check.js <path-to-system-map-engine.js>
   Prints one "ok:" line per group of assertions and exits 1 if any group failed. */
'use strict';
const path = require('path');
const S = require(path.resolve(process.argv[2]));
const F = require('./fixtures.js');

let failed = 0, states = 0;
function group(name, fn) {
  const errs = [];
  try { fn(msg => errs.push(msg)); } catch (err) { errs.push('threw: ' + err.message); }
  if (errs.length) { failed++; console.log('FAIL: ' + name); errs.slice(0, 6).forEach(e => console.log('  - ' + e)); }
  else console.log('ok: ' + name);
}

function prep(f) {
  const m = S.buildModel(f.nodes, f.edges), lab = Object.create(null);
  f.nodes.forEach(x => { lab[x.id] = x.label || String(x.id); });
  const size = (id, header) => header ? { w: 7 * lab[id].length + 40, h: 30 }
    : m.group[id] ? { w: 7 * lab[id].length + 72, h: 40 } : { w: 44 + 6.6 * lab[id].length, h: 52 };
  const textW = s => s.length * 6;
  return { m, size, textW, groups: m.ids.filter(id => m.group[id]) };
}
const openSet = o => Object.keys(o).filter(k => o[k] === true).sort().join(',');
const mask2open = (groups, mask) => { const o = Object.create(null); groups.forEach((g, i) => { if (mask & (1 << i)) o[g] = true; }); return o; };
const plain = () => ({ w: 60, h: 40 }), six = s => s.length * 6;

// Wire crossings, counted independently of the engine: each wire is the polyline through its runs.
const turn = (a, b, c) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
const cuts = (a, b, c, d) => turn(a, b, c) * turn(a, b, d) < -1e-6 && turn(c, d, a) * turn(c, d, b) < -1e-6;
function crossings(out) {
  const ln = out.edges.map(e => { const p = []; e.runs.forEach(r => { p.push([r.x0, r.y0], [r.x1, r.y1]); }); return p; });
  let n = 0;
  for (let i = 0; i < ln.length; i++) for (let j = i + 1; j < ln.length; j++) {
    for (let p = 0; p + 1 < ln[i].length; p++) for (let q = 0; q + 1 < ln[j].length; q++) if (cuts(ln[i][p], ln[i][p + 1], ln[j][q], ln[j][q + 1])) n++;
  }
  return n;
}

// The geometry rules, checked independently of the engine's own verify().
function rules(out, m) {
  const errs = [], B = out.boxes, ids = Object.keys(B);
  ids.forEach(id => { const b = B[id]; if (![b.x, b.y, b.w, b.h].every(Number.isFinite)) errs.push('non-finite box ' + id); });
  ids.forEach((a, i) => ids.slice(i + 1).forEach(b => {
    if (m.parent[a] !== m.parent[b]) return; const p = B[a], q = B[b];
    if (p.x < q.x + q.w - 0.01 && q.x < p.x + p.w - 0.01 && p.y < q.y + q.h - 0.01 && q.y < p.y + p.h - 0.01) errs.push('overlap ' + a + '/' + b);
  }));
  ids.forEach(id => {
    const g = m.parent[id]; if (g === S.ROOT) return; const b = B[id], q = B[g];
    if (b.x < q.x - 0.01 || b.y < q.y - 0.01 || b.x + b.w > q.x + q.w + 0.01 || b.y + b.h > q.y + q.h + 0.01) errs.push('escape ' + id);
  });
  out.edges.forEach(e => {
    const own = new Set(e.path);
    if (e.runs.length < 2) errs.push('short wire ' + e.key);
    e.runs.forEach(r => {
      if (![r.x0, r.y0, r.x1, r.y1].every(Number.isFinite)) errs.push('non-finite wire ' + e.key);
      const lx = Math.min(r.x0, r.x1), hx = Math.max(r.x0, r.x1), ly = Math.min(r.y0, r.y1), hy = Math.max(r.y0, r.y1);
      ids.forEach(id => {
        if (own.has(id)) return; const b = B[id];
        if (hx > b.x + 0.01 && lx < b.x + b.w - 0.01 && hy > b.y + 0.01 && ly < b.y + b.h - 0.01) errs.push('wire through ' + id);
      });
    });
  });
  return errs;
}

const all = F.graphs.concat([F.pair.before, F.pair.after]);
const totals = { off: 0, on: 0, better: 0 };

// 1. every fixture, every open/closed combination, both directions, with the second pass off and on
all.forEach(f => group(f.slug + ': every open/closed state in both directions', bad => {
  const { m, size, textW, groups } = prep(f);
  for (const dir of ['LR', 'TB']) for (let mask = 0; mask < (1 << groups.length); mask++) {
    const open = mask2open(groups, mask), where = dir + ' mask ' + mask.toString(2) + ': ';
    S.K.PASS2 = false; const base = S.layout(m, open, size, textW, dir);
    S.K.PASS2 = true; const out = S.layout(m, open, size, textW, dir), again = S.layout(m, open, size, textW, dir);
    states++;
    rules(base, m).forEach(x => bad(where + 'first pass: ' + x));
    rules(out, m).forEach(x => bad(where + x));
    S.verify(out, m).forEach(x => bad(where + 'verify: ' + x));
    if (JSON.stringify(out.boxes) !== JSON.stringify(again.boxes) || out.edges.map(e => e.d).join() !== again.edges.map(e => e.d).join()) {
      bad(where + 'the same input gave two different pictures');
    }
    if (out.dir !== dir) bad(where + 'dir is ' + out.dir);
    if (crossings(out) !== out.cross) bad(where + 'engine counts ' + out.cross + ' crossings, the harness counts ' + crossings(out));
    if (out.cross > base.cross) bad(where + 'the second pass added crossings: ' + base.cross + ' -> ' + out.cross);
    totals.off += base.cross; totals.on += out.cross; if (out.cross < base.cross) totals.better++;
  }
}));

// 2. the second pass must help where it was meant to: two open sibling groups with crossed wires
group('second pass removes crossings between two open sibling groups', bad => {
  const { m, size, textW, groups } = prep(F.graphs.filter(f => f.slug === 'twogroups')[0]), open = mask2open(groups, 3);
  ['LR', 'TB'].forEach(dir => {
    S.K.PASS2 = false; const base = S.layout(m, open, size, textW, dir);
    S.K.PASS2 = true; const out = S.layout(m, open, size, textW, dir);
    if (!(base.cross > 0)) bad(dir + ': the fixture no longer crosses without the second pass, so it proves nothing');
    if (!(out.cross < base.cross)) bad(dir + ': ' + base.cross + ' -> ' + out.cross);
  });
});

// 3. which groups start open at the budget
group('default open sets at budget 16, and open overrides', bad => {
  const want = { small: 'svc', medium: 'data,edge,shop', large: 'edge', chain: '', twogroups: 'cons,prod', deps: '', before: 'data,shop', after: 'shop' };
  all.forEach(f => {
    const got = openSet(S.defaultOpen(prep(f).m, S.K.BUDGET));
    if (got !== want[f.slug]) bad(f.slug + ': got [' + got + '] want [' + want[f.slug] + ']');
  });
  if (S.K.BUDGET !== 16) bad('budget is ' + S.K.BUDGET + ', the spec fixes 16');
  const big = F.graphs[2], small = F.graphs[0], set = (list, id, open) => list.map(x => x.id === id ? Object.assign({}, x, { open }) : x);
  const o = S.defaultOpen(S.buildModel(set(set(big.nodes, 'trips', true), 'edge', false), big.edges), 16);
  if (o.trips !== true) bad('open:true is not honoured');
  if (o.edge === true) bad('open:false is not honoured');
  const tops = big.nodes.map(x => x.parent == null && !x.kind ? Object.assign({}, x, { open: true }) : x);
  const o2 = openSet(S.defaultOpen(S.buildModel(tops, big.edges), 16));
  if (o2 !== 'analytics,core,data,edge,rt') bad('forced-open groups alone pass the budget, so no other group may open: got [' + o2 + ']');
  if (openSet(S.defaultOpen(S.buildModel(set(small.nodes, 'svc', false), small.edges), 16)) !== '') bad('open:false must hold even when every leaf fits');
  if (openSet(S.defaultOpen(S.buildModel(big.nodes, big.edges), 100)) !== 'analytics,core,data,edge,identity,pay,rt,trips') bad('every group opens when all leaves fit');
});

// 4. what a merged, inferred, async or changed wire reports
group('merged, inferred, async and changed wires', bad => {
  const nodes = [{ id: 'g', label: 'G' }, { id: 'a', label: 'A', parent: 'g' }, { id: 'b', label: 'B', parent: 'g' }, { id: 'x', label: 'X' }];
  const edges = [{ from: 'a', to: 'x', label: 'one', flow: 'async', change: 'added' }, { from: 'b', to: 'x', label: 'two', flow: 'async', change: 'added' },
    { from: 'x', to: 'g', label: 'back', flow: 'sync', inferred: true }, { from: 'x', to: 'a', label: '', inferred: true }];
  const m = S.buildModel(nodes, edges), shut = S.layout(m, Object.create(null), plain, six, 'LR'), by = (o, k) => o.edges.filter(w => w.key === k)[0];
  const merged = by(shut, 'g\u0001x'), back = by(shut, 'x\u0001g');
  if (!merged || merged.n !== 2 || merged.label !== '2 links' || !merged.async || merged.change !== 'added' || merged.items.length !== 2) {
    bad('two edges between the same visible ends must merge into one "2 links" wire that keeps its items');
  }
  if (!back || back.n !== 2 || back.label !== '2 links' || !back.inferred) bad('a merged wire is inferred when every edge in it is');
  const open = Object.create(null); open.g = true;
  const wide = S.layout(m, open, plain, six, 'LR');
  if (by(wide, 'x\u0001g').label !== 'back ?') bad('an inferred wire label must end in " ?"');
  if (by(wide, 'x\u0001a').label !== '?') bad('an inferred wire with no label shows "?"');
  const mixed = S.buildModel(nodes, [{ from: 'a', to: 'x', flow: 'async', change: 'added' }, { from: 'b', to: 'x', flow: 'sync', change: 'deleted' }]);
  const w = S.layout(mixed, Object.create(null), plain, six, 'LR').edges[0];
  if (w.async || w.change !== '' || w.inferred) bad('a merged wire is async, changed or inferred only when every edge in it is');
  const own = S.buildModel(nodes, [{ from: 'a', to: 'g', label: 'up' }, { from: 'g', to: 'b', label: 'down' }, { from: 'a', to: 'a', label: 'self' }]);
  if (S.layout(own, open, plain, six, 'LR').edges.length || S.layout(own, Object.create(null), plain, six, 'LR').edges.length) {
    bad('a self-edge and an edge between a group and its own child are not drawn');
  }
});

// 5. verify() must reject a broken result, not only accept a good one
group('verify() rejects five kinds of broken layout', bad => {
  const { m, size, textW } = prep(F.graphs[0]), open = Object.create(null); open.svc = true;
  const fresh = () => S.layout(m, open, size, textW, 'LR');
  if (S.verify(fresh(), m).length) bad('verify flags a good layout');
  const a = fresh(); a.boxes.api.x = NaN;
  const b = fresh(); b.boxes.api.x = b.boxes.web.x; b.boxes.api.y = b.boxes.web.y;
  const c = fresh(); c.boxes.db.x = c.boxes.svc.x + c.boxes.svc.w + 50;
  const d = fresh(); d.W = Infinity;
  const e = fresh(); e.edges[0].d = 'MNaN 0';
  [['a non-finite box', a], ['overlapping siblings', b], ['a child outside its group', c], ['a non-finite size', d], ['a non-finite wire', e]]
    .forEach(([name, out]) => { if (!S.verify(out, m).length) bad('verify does not catch ' + name); });
});

// 6. inputs that must not throw or hang
group('12 degenerate inputs neither throw nor hang', bad => {
  const cases = [
    ['empty', [], []],
    ['self edge', [{ id: 'a' }], [{ from: 'a', to: 'a' }]],
    ['edge to a missing node, and a two-node cycle', [{ id: 'a' }, { id: 'b' }], [{ from: 'a', to: 'ghost' }, { from: 'a', to: 'b' }, { from: 'b', to: 'a' }]],
    ['edge between a group and its child', [{ id: 'g' }, { id: 'a', parent: 'g' }], [{ from: 'a', to: 'g' }]],
    ['group with no children', [{ id: 'g', group: true }], []],
    ['parent loop', [{ id: 'a', parent: 'b' }, { id: 'b', parent: 'a' }, { id: 'c', parent: 'a' }], [{ from: 'a', to: 'c' }]],
    ['node that is its own parent', [{ id: 'a', parent: 'a' }, { id: 'b' }], [{ from: 'a', to: 'b' }]],
    ['parent that does not exist', [{ id: 'a', parent: 'nope' }, { id: 'b' }], [{ from: 'a', to: 'b' }]],
    ['duplicate ids', [{ id: 'a' }, { id: 'a' }, { id: 'b' }], [{ from: 'a', to: 'b' }]],
    ['ids named like Object members', [{ id: 'constructor' }, { id: '__proto__' }, { id: 'toString', parent: '__proto__' }, { id: 'hasOwnProperty' }],
      [{ from: 'constructor', to: 'toString' }, { from: 'hasOwnProperty', to: '__proto__' }, { from: 'valueOf', to: 'constructor' }]],
    ['ids with spaces and quotes', [{ id: 'a b' }, { id: 'c"d' }, { id: "e'f" }], [{ from: 'a b', to: 'c"d' }, { from: 'c"d', to: "e'f" }]],
    ['null arguments', null, null],
  ];
  cases.forEach(([name, nodes, edges]) => {
    try {
      const m = S.buildModel(nodes, edges), groups = m.ids.filter(id => m.group[id]);
      if (new Set(m.ids).size !== m.ids.length) throw new Error('duplicate id kept');
      const reach = new Set(); (function walk(g) { m.kids[g].forEach(c => { reach.add(c); walk(c); }); })(S.ROOT);
      if (reach.size !== m.ids.length) throw new Error('a node cannot be reached from the root');
      S.defaultOpen(m, 16);
      for (const dir of ['LR', 'TB']) for (let mask = 0; mask < (1 << groups.length); mask++) {
        const out = S.layout(m, mask2open(groups, mask), plain, six, dir), errs = rules(out, m).concat(S.verify(out, m));
        if (errs.length) throw new Error(errs[0]);
        states++;
      }
      // a plain {} for `open` must behave like an empty set, whatever the ids are called
      const loose = S.layout(m, {}, plain, six, 'LR');
      if (Object.keys(loose.boxes).length !== m.kids[S.ROOT].length) throw new Error('a plain {} open map opened a group');
    } catch (err) { bad('"' + name + '": ' + err.message); }
  });
});

console.log('info: crossings over all fixture states: ' + totals.off + ' without the second pass, ' + totals.on + ' with it (fewer in ' + totals.better + ' states, more in none)');
all.forEach(f => {
  const { m, size, textW, groups } = prep(f), open = mask2open(groups, (1 << groups.length) - 1);
  const lr = S.layout(m, open, size, textW, 'LR'), tb = S.layout(m, open, size, textW, 'TB');
  console.log('info: ' + f.slug + ' with every group open: LR ' + Math.round(lr.W) + 'x' + Math.round(lr.H) + ' (' + lr.cross + ' crossings), TB ' +
    Math.round(tb.W) + 'x' + Math.round(tb.H) + ' (' + tb.cross + ')');
});
console.log(failed ? 'FAILED: ' + failed + ' group(s)' : 'PASS: system-map engine layout (' + states + ' states)');
process.exit(failed ? 1 : 0);
