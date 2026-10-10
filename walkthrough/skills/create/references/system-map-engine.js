/* walkthrough system-map engine v1 */
/* Reads a .sysmap block, places its boxes and draws its wires. Layout is pure and runs under node;
   init() is the page code. Any error leaves the plain view in place and one line in the console. */
(function (G) {
'use strict';
const ROOT = '\u0000';
const K = { GAP_LR: 24, GAP_TB: 20, NODE_GAP: 16, MIX_GAP: 11, SLOT: 10, SLOT_GAP: 5, PADX: 16, PADY: 14,
  LABEL_H: 14, LABEL_PAD: 10, HEAD_PAD: 12, CLOSED_PAD: 20, BUDGET: 16, PASS2: true };
const O = () => Object.create(null);
const last = a => a[a.length - 1];

/* ---- model ---- */
// nodes: [{id, parent, group, open}]   edges: [{from, to, label, flow, change, inferred}]
function buildModel(nodes, edges) {
  const m = { ids: [], parent: O(), kids: O(), group: O(), forced: O(), edges: edges || [] };
  m.kids[ROOT] = [];
  (nodes || []).forEach(n => {
    if (n.id == null || n.id === ROOT || n.id in m.parent) return;  // first declaration of an id wins
    m.ids.push(n.id); m.parent[n.id] = n.parent == null ? ROOT : n.parent; m.group[n.id] = !!n.group; m.kids[n.id] = [];
    if (n.open === true || n.open === false) m.forced[n.id] = n.open;
  });
  m.ids.forEach(id => { if (!(m.parent[id] in m.kids)) m.parent[id] = ROOT; });
  m.ids.forEach(id => {  // a parent loop cannot reach the root: cut it
    let p = m.parent[id], steps = 0;
    while (p !== ROOT && steps <= m.ids.length) { p = m.parent[p]; steps++; }
    if (p !== ROOT) m.parent[id] = ROOT;
  });
  m.ids.forEach(id => { m.kids[m.parent[id]].push(id); });
  m.ids.forEach(id => { if (m.kids[id].length) m.group[id] = true; });
  return m;
}

// boxes on show under g when the groups in `open` are open (no `open`: every group open, so the leaf count)
function visible(m, open, g) { let n = 0; m.kids[g].forEach(c => { n += m.group[c] && (!open || open[c] === true) ? visible(m, open, c) : 1; }); return n; }
const leaves = (m, g) => visible(m, null, g);

// Which groups start open: forced ones as set; all, if every leaf fits the budget; else breadth-first within it.
function defaultOpen(m, budget) {
  const open = O(), groups = m.ids.filter(id => m.group[id]);
  groups.forEach(g => { if (m.forced[g] === true) open[g] = true; });
  if (leaves(m, ROOT) <= budget) { groups.forEach(g => { if (m.forced[g] !== false) open[g] = true; }); return open; }
  const q = m.kids[ROOT].filter(id => m.group[id]);
  while (q.length) {
    const g = q.shift();
    if (m.forced[g] === false) continue;
    if (open[g] !== true) { open[g] = true; if (visible(m, open, ROOT) > budget) { delete open[g]; continue; } }
    m.kids[g].forEach(c => { if (m.group[c]) q.push(c); });
  }
  return open;
}

// Least-squares fit that keeps the order (pool adjacent violators).
function monotone(d) {
  const v = [], c = [], out = [];
  d.forEach(x => {
    v.push(x); c.push(1);
    while (v.length > 1 && v[v.length - 2] > v[v.length - 1]) {
      const a = v.pop(), ca = c.pop(), k = v.length - 1;
      v[k] = (v[k] * c[k] + a * ca) / (c[k] + ca); c[k] += ca;
    }
  });
  v.forEach((x, i) => { for (let j = 0; j < c[i]; j++) out.push(x); });
  return out;
}

/* ---- layout ---- */
// size(id, header) -> {w, h}: a leaf or closed group, or (header) an open group's title strip.
// textW(label) -> width of a wire label. dir: 'LR' or 'TB'. Returns boxes and routed wires.
function layout(m, open, size, textW, dir) {
  const TB = dir === 'TB', GAP = TB ? K.GAP_TB : K.GAP_LR, par = m.parent;
  const main = s => TB ? s.h : s.w, cross = s => TB ? s.w : s.h;
  const isOpen = id => open[id] === true;
  const rep = id => { let r = id, p = par[id]; while (p !== ROOT) { if (!isOpen(p)) r = p; p = par[p]; } return r; };
  const up = id => { const a = [id]; let p = par[id]; while (p !== ROOT) { a.push(p); p = par[p]; } a.push(ROOT); return a; };
  const same = (items, k) => items.every(e => (e[k] || '') === (items[0][k] || '')) ? (items[0][k] || '') : '';
  const labelOf = v => {
    if (v.items.length > 1) return v.items.length + ' links';
    const t = v.items[0].label || '';
    return v.items[0].inferred ? (t ? t + ' ?' : '?') : t;
  };
  const loc = O();
  const at = g => loc[g] || (loc[g] = { edges: [], E: O(), W: O(), chE: O(), chW: O() });

  // 1. visible wires: one per pair of visible ends, owned by the lowest group that holds both ends
  const wires = [], byKey = O();
  m.edges.forEach(e => {
    if (!(e.from in par) || !(e.to in par)) return;
    const a = rep(e.from), b = rep(e.to);
    if (a === b) return;
    const pa = up(a), pb = up(b);
    if (pa.indexOf(b) > -1 || pb.indexOf(a) > -1) return;
    const key = a + '\u0001' + b;
    let v = byKey[key];
    if (!v) {
      let ia = 1; while (pb.indexOf(pa[ia]) < 0) ia++;
      const L = pa[ia];
      v = byKey[key] = { key, a, b, L, pa: pa.slice(0, ia), pb: pb.slice(0, pb.indexOf(L)), items: [], rev: false };
      wires.push(v); at(L).edges.push(v);
    }
    v.items.push(e);
  });

  // 2. per shown group: a wire that closes a cycle is reversed for ranking only; it is still drawn
  const shown = [ROOT].concat(m.ids.filter(id => m.group[id] && isOpen(id) && rep(id) === id));
  shown.forEach(g => {
    const out = O(), col = O();
    at(g).edges.forEach(v => { const s = last(v.pa); (out[s] || (out[s] = [])).push(v); });
    const dfs = u => {
      col[u] = 1;
      (out[u] || []).forEach(v => { const t = last(v.pb); if (col[t] === 1) v.rev = true; else if (!col[t]) dfs(t); });
      col[u] = 2;
    };
    m.kids[g].forEach(u => { if (!col[u]) dfs(u); });
  });

  // 3. where a wire has to cross a group border: a reserved exit (E) or entry (W) per item
  wires.forEach(v => {
    v.wp = v.rev ? v.pb : v.pa; v.ep = v.rev ? v.pa : v.pb;
    for (let i = 0; i < v.wp.length - 1; i++) at(v.wp[i + 1]).E[v.wp[i]] = true;
    for (let i = 0; i < v.ep.length - 1; i++) at(v.ep[i + 1]).W[v.ep[i]] = true;
  });

  // 4. one layered layout for the children of a single group
  function flat(items, sz, lo) {
    const rank = O(), ins = O(), outs = O(), memo = O();
    items.forEach(id => { ins[id] = []; outs[id] = []; });
    lo.edges.forEach(v => {
      const s = last(v.pa), t = last(v.pb);
      v.wI = v.rev ? t : s; v.eI = v.rev ? s : t;
      outs[v.wI].push(v.eI); ins[v.eI].push(v.wI);
    });
    const rk = id => {
      if (id in memo) return memo[id];
      memo[id] = 0; let r = 0;
      ins[id].forEach(p => { r = Math.max(r, rk(p) + 1); });
      return (memo[id] = r);
    };
    let maxR = 0;
    items.forEach(id => { rank[id] = rk(id); if (rank[id] > maxR) maxR = rank[id]; });
    items.forEach(id => {
      if (!ins[id].length && outs[id].length && !lo.W[id]) {  // a source sits next to its nearest target
        let mn = Infinity; outs[id].forEach(s => { mn = Math.min(mn, rank[s]); }); rank[id] = mn - 1;
      } else if (!ins[id].length && !outs[id].length) {  // no wire inside this group
        const E = lo.E[id], W = lo.W[id];
        rank[id] = E && !W ? maxR : W && !E ? 0 : E && W ? Math.round(maxR / 2) : -1;
      }
    });
    const iso = items.filter(id => rank[id] === -1);
    if (iso.length) {  // unwired boxes go in a grid
      const all = iso.length === items.length, cols = all ? Math.ceil(Math.sqrt(iso.length)) : maxR + 1;
      iso.forEach((id, i) => { rank[id] = i % cols; });
      if (all) maxR = Math.min(cols, iso.length) - 1;
    }

    // boxes sit on even layers; odd layers hold wire labels and pass-through slots
    const nL = 2 * maxR + 1, layers = [], ent = O();
    for (let r = 0; r < nL; r++) layers.push([]);
    items.forEach(id => {
      const e = { id, m: main(sz[id]), c: cross(sz[id]), L: [], R: [], r: 2 * rank[id] };
      ent[id] = e; layers[e.r].push(e);
    });
    const slot = (r, lw) => {
      const d = { d: 1, lab: lw ? 1 : 0, L: [], R: [], r, m: 0, c: K.SLOT };
      if (lw) { d.m = TB ? K.LABEL_H : lw + K.LABEL_PAD; d.c = TB ? lw + K.LABEL_PAD : K.LABEL_H; }
      layers[r].push(d); return d;
    };
    const link = (a, b) => { a.R.push(b); b.L.push(a); };
    lo.edges.forEach(v => {
      let prev = ent[v.wI]; const ch = [], lw = textW(labelOf(v)); v.lab = null;
      for (let r = 2 * rank[v.wI] + 1; r < 2 * rank[v.eI]; r++) {
        const d = slot(r, ch.length ? 0 : lw);
        if (d.lab) v.lab = d;
        link(prev, d); prev = d; ch.push(d);
      }
      link(prev, ent[v.eI]); v.mid = ch;
    });
    items.forEach(id => {
      if (lo.E[id]) {
        let prev = ent[id]; const ch = [];
        for (let r = 2 * rank[id] + 1; r < nL; r++) { const d = slot(r, 0); link(prev, d); prev = d; ch.push(d); }
        lo.chE[id] = ch;
      }
      if (lo.W[id]) {
        let next = ent[id]; const ch = [];
        for (let r = 2 * rank[id] - 1; r >= 0; r--) { const d = slot(r, 0); link(d, next); next = d; ch.unshift(d); }
        lo.chW[id] = ch;
      }
    });

    // order inside each layer: neighbour-average sweeps, declaration order as the tie-break
    const index = ly => ly.forEach((e, i) => { e.i = i; });
    layers.forEach(index);
    const sweep = (r, side) => {
      const ly = layers[r];
      ly.forEach(e => {
        const nb = e[side];
        if (nb.length) { let t = 0; nb.forEach(n => { t += n.i; }); e.b = t / nb.length; } else e.b = e.i;
      });
      ly.sort((a, b) => a.b - b.b || a.i - b.i); index(ly);
    };
    for (let it = 0; it < 4; it++) {
      for (let r = 1; r < nL; r++) sweep(r, 'L');
      for (let r = nL - 2; r >= 0; r--) sweep(r, 'R');
    }
    if (hint) {  // second pass: entries follow where their sources ended up
      const heads = [];
      items.forEach(id => {
        if (!lo.W[id] || !(id in hint)) return;
        const hd = lo.chW[id].length ? lo.chW[id][0] : ent[id];
        hd.h = hint[id]; heads.push(hd);
      });
      if (heads.length > 1) {
        const spots = heads.map(e => e.i).sort((a, b) => a - b), ly = layers[0];
        heads.sort((a, b) => a.h - b.h || a.i - b.i).forEach((e, k) => { ly[spots[k]] = e; });
        index(ly);
        for (let r = 1; r < nL; r++) sweep(r, 'L');
      }
    }

    // main axis: one column (or row) per layer
    const colM = [], colU = []; let u = 0;
    for (let r = 0; r < nL; r++) {
      let w = 0; layers[r].forEach(e => { if (e.m > w) w = e.m; });
      colM.push(w); colU.push(u); u += w + (r < nL - 1 ? GAP : 0);
    }

    // cross axis: pull each entry toward its neighbours while keeping the order and the gaps
    const gapOf = (a, b) => a.d && b.d ? K.SLOT_GAP : (a.d || b.d) ? K.MIX_GAP : K.NODE_GAP;
    layers.forEach(ly => { let y = 0; ly.forEach((e, i) => { if (i) y += gapOf(ly[i - 1], e); e.v = y; y += e.c; }); });
    const place = (r, sides) => {
      const ly = layers[r]; if (!ly.length) return;
      const off = [], want = []; let o = 0;
      ly.forEach((e, i) => {
        if (i) o += ly[i - 1].c + gapOf(ly[i - 1], e);
        off.push(o);
        let t = 0, n = 0;
        sides.forEach(sd => e[sd].forEach(nb => { t += nb.v + nb.c / 2; n++; }));
        want.push((n ? t / n - e.c / 2 : e.v) - o);
      });
      const z = monotone(want);
      ly.forEach((e, i) => { e.v = z[i] + off[i]; });
    };
    for (let it = 0; it < 3; it++) {
      for (let r = 1; r < nL; r++) place(r, ['L']);
      for (let r = nL - 2; r >= 0; r--) place(r, ['R']);
    }
    for (let r = 0; r < nL; r++) place(r, ['L', 'R']);
    let mn = Infinity, mx = -Infinity;
    layers.forEach(ly => ly.forEach(e => { mn = Math.min(mn, e.v); mx = Math.max(mx, e.v + e.c); }));
    if (!items.length) { mn = 0; mx = 0; }
    const pos = O();
    layers.forEach((ly, r) => ly.forEach(e => {
      e.v -= mn; e.cv = e.v + e.c / 2; e.u0 = colU[r]; e.u1 = colU[r] + colM[r];
      if (!e.d) pos[e.id] = { u: colU[r] + (colM[r] - e.m) / 2, v: e.v, r };
    }));
    return { m: u, c: mx - mn, pos, colU, colM, sz };
  }

  // 5. inside-out: lay out the children, then treat the group as one box in its parent
  const res = O();
  let boxes = O(), hint = null;
  function lay(g) {
    const items = m.kids[g], sz = O();
    items.forEach(id => {
      if (m.group[id] && isOpen(id)) { lay(id); sz[id] = { w: res[id].W, h: res[id].H }; } else sz[id] = size(id, false);
    });
    const R = flat(items, sz, at(g)), root = g === ROOT;
    const head = root ? { w: 0, h: 0 } : size(g, true), px = root ? 0 : K.PADX, py = root ? 0 : K.PADY;
    R.ox = px; R.oy = head.h + py;
    R.W = Math.max(TB ? R.c : R.m, head.w) + 2 * px; R.H = head.h + (TB ? R.m : R.c) + 2 * py;
    res[g] = R;
  }
  function put(g, gx, gy) {
    const R = res[g];
    R.ax = gx + R.ox; R.ay = gy + R.oy; R.au = TB ? R.ay : R.ax; R.av = TB ? R.ax : R.ay;
    m.kids[g].forEach(id => {
      const p = R.pos[id];
      const b = boxes[id] = { x: R.ax + (TB ? p.v : p.u), y: R.ay + (TB ? p.u : p.v), w: R.sz[id].w, h: R.sz[id].h };
      if (m.group[id] && isOpen(id)) put(id, b.x, b.y);
    });
  }

  // 6. routes: straight runs through the reserved slots, joined by curves that stay in the gaps
  const f = n => Math.round(n * 10) / 10;
  const P = (u, v) => TB ? f(v) + ' ' + f(u) : f(u) + ' ' + f(v);
  const A = id => { const b = boxes[id]; return TB ? { u: b.y, m: b.h, v: b.x, c: b.w } : { u: b.x, m: b.w, v: b.y, c: b.h }; };
  function route(v) {
    const runs = [], wp = v.wp, ep = v.ep, R = res[v.L];
    const add = (u0, u1, y) => {
      const l = last(runs);
      if (l && Math.abs(l.v - y) < 0.01 && u0 <= l.u1 + 0.01) { if (u1 > l.u1) l.u1 = u1; } else runs.push({ u0, u1, v: y });
    };
    const wb = A(wp[0]); let y = wb.v + wb.c / 2;
    add(wb.u + wb.m, wb.u + wb.m, y);
    for (let i = 0; i < wp.length - 1; i++) {  // climb out of the groups around the source
      const it = wp[i], g = wp[i + 1], Rg = res[g], p = Rg.pos[it], gb = A(g);
      add(last(runs).u1, Rg.au + Rg.colU[p.r] + Rg.colM[p.r], y);
      (loc[g].chE[it] || []).forEach(d => { y = Rg.av + d.cv; add(Rg.au + d.u0, Rg.au + d.u1, y); });
      add(last(runs).u1, gb.u + gb.m, y);
    }
    const pw = R.pos[last(wp)], pe = R.pos[last(ep)];
    add(last(runs).u1, R.au + R.colU[pw.r] + R.colM[pw.r], y);
    v.mid.forEach(d => add(R.au + d.u0, R.au + d.u1, R.av + d.cv));
    v.hy = last(runs).v;  // where the wire runs just before it reaches its target
    const eb = A(ep[0]), yin = []; let cur = eb.v + eb.c / 2;
    for (let i = 0; i < ep.length - 1; i++) {
      const g = ep[i + 1], ch = loc[g].chW[ep[i]] || [];
      if (ch.length) cur = res[g].av + ch[0].cv;
      yin[i] = cur;
    }
    add(R.au + R.colU[pe.r], A(last(ep)).u, cur);
    for (let i = ep.length - 2; i >= 0; i--) {  // descend into the groups around the target
      const g = ep[i + 1], it = ep[i], Rg = res[g], p = Rg.pos[it];
      add(A(g).u, Rg.au, yin[i]);
      (loc[g].chW[it] || []).forEach(d => add(Rg.au + d.u0, Rg.au + d.u1, Rg.av + d.cv));
      add(Rg.au + Rg.colU[p.r], A(it).u, i ? yin[i - 1] : eb.v + eb.c / 2);
    }
    let d = 'M' + P(runs[0].u0, runs[0].v);
    runs.forEach((s, k) => {
      if (k) {
        const p = runs[k - 1], du = (s.u0 - p.u1) / 2;
        d += ' C' + P(p.u1 + du, p.v) + ' ' + P(s.u0 - du, s.v) + ' ' + P(s.u0, s.v);
      }
      if (s.u1 > s.u0) d += ' L' + P(s.u1, s.v);
    });
    const lab = v.lab, lu = lab ? R.au + (lab.u0 + lab.u1) / 2 : 0, lv = lab ? R.av + lab.cv : 0;
    const segs = runs.map(s => TB ? { x0: s.v, y0: s.u0, x1: s.v, y1: s.u1 } : { x0: s.u0, y0: s.v, x1: s.u1, y1: s.v });
    return { d, runs: segs, lx: f(TB ? lv : lu), ly: f(TB ? lu : lv), hasLabel: !!lab };
  }

  // 7. how often the routed wires cross each other (touching ends and shared runs do not count)
  const turn = (a, b, c) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
  const cuts = (a, b, c, d) => turn(a, b, c) * turn(a, b, d) < -1e-6 && turn(c, d, a) * turn(c, d, b) < -1e-6;
  function tangle(rs) {
    const ln = rs.map(r => { const p = []; r.runs.forEach(s => { p.push([s.x0, s.y0], [s.x1, s.y1]); }); return p; });
    let n = 0;
    for (let i = 0; i < ln.length; i++) for (let j = i + 1; j < ln.length; j++) {
      const a = ln[i], b = ln[j];
      for (let p = 0; p + 1 < a.length; p++) for (let q = 0; q + 1 < b.length; q++) if (cuts(a[p], a[p + 1], b[q], b[q + 1])) n++;
    }
    return n;
  }

  lay(ROOT); put(ROOT, 0, 0);
  let pick = { boxes, routed: wires.map(route), W: res[ROOT].W, H: res[ROOT].H };
  pick.cross = tangle(pick.routed);
  // second pass: order each group's entries by where their sources ended up; keep it only if it crosses less
  if (K.PASS2 && pick.cross && wires.length < 200 && wires.some(v => v.ep.length > 1)) {
    const sum = O(), cnt = O();
    wires.forEach(v => {
      for (let i = 0; i < v.ep.length - 1; i++) { const id = v.ep[i]; sum[id] = (sum[id] || 0) + v.hy; cnt[id] = (cnt[id] || 0) + 1; }
    });
    hint = O(); Object.keys(sum).forEach(id => { hint[id] = sum[id] / cnt[id]; });
    boxes = O(); lay(ROOT); put(ROOT, 0, 0);
    const second = { boxes, routed: wires.map(route), W: res[ROOT].W, H: res[ROOT].H };
    second.cross = tangle(second.routed);
    if (second.cross < pick.cross) pick = second;
  }
  const edges = wires.map((v, k) => {
    const r = pick.routed[k];
    return { key: v.key, a: v.a, b: v.b, d: r.d, runs: r.runs, lx: r.lx, ly: r.ly, label: r.hasLabel ? labelOf(v) : '',
      n: v.items.length, items: v.items, async: v.items.every(e => e.flow === 'async'), inferred: v.items.every(e => !!e.inferred),
      change: same(v.items, 'change'), rev: v.rev, path: up(v.a).concat(up(v.b)) };
  });
  return { boxes: pick.boxes, W: pick.W, H: pick.H, edges, cross: pick.cross, dir: TB ? 'TB' : 'LR' };
}

// Checks a layout result. Returns a list of problems; empty means it is safe to paint.
function verify(out, m) {
  const errs = [], B = out.boxes, ids = Object.keys(B), fin = Number.isFinite, T = 0.5;
  if (!fin(out.W) || !fin(out.H)) errs.push('size');
  ids.forEach(id => { const b = B[id]; if (!(fin(b.x) && fin(b.y) && fin(b.w) && fin(b.h))) errs.push('box ' + id); });
  ids.forEach((a, i) => {
    for (let j = i + 1; j < ids.length; j++) {
      const b = ids[j]; if (m.parent[a] !== m.parent[b]) continue;
      const p = B[a], q = B[b];
      if (p.x < q.x + q.w - T && q.x < p.x + p.w - T && p.y < q.y + q.h - T && q.y < p.y + p.h - T) errs.push('overlap ' + a + ' ' + b);
    }
  });
  ids.forEach(id => {
    const g = m.parent[id]; if (g === ROOT || !B[g]) return;
    const b = B[id], q = B[g];
    if (b.x < q.x - T || b.y < q.y - T || b.x + b.w > q.x + q.w + T || b.y + b.h > q.y + q.h + T) errs.push('escape ' + id);
  });
  out.edges.forEach(e => { if (/NaN|Infinity/.test(e.d)) errs.push('wire ' + e.key); });
  return errs;
}

/* ---- page ---- */
let seq = 0;
const warn = e => console.warn('walkthrough system-map engine: fell back to the plain view: ' + e);
function init(el) {
  if (el.__wtsm) return;
  const stage = el.querySelector('.sys-stage'), svg = el.querySelector('.sys-wires');
  if (!stage || !svg) return;
  el.__wtsm = true;
  const NS = 'http://www.w3.org/2000/svg', uid = 'wtsm' + (seq++), els = O(), nodes = [];
  const mk = (tag, attrs, host) => {
    const n = document.createElementNS(NS, tag);
    Object.keys(attrs).forEach(k => n.setAttribute(k, attrs[k]));
    if (host) host.appendChild(n);
    return n;
  };
  stage.querySelectorAll('.sys-node[data-id],.sys-group[data-id]').forEach(n => {
    const id = n.dataset.id; if (id in els) return;
    const p = n.parentElement.closest('.sys-group[data-id]'), o = n.dataset.open;
    els[id] = n;
    nodes.push({ id, parent: p ? p.dataset.id : null, group: n.classList.contains('sys-group'),
      open: o === 'true' ? true : o === 'false' ? false : undefined });
  });
  const rows = Array.from(el.querySelectorAll('.sys-links li'));
  const edges = rows.map(li => ({ from: li.dataset.from, to: li.dataset.to, label: li.dataset.label || '', flow: li.dataset.flow || 'sync',
    change: li.dataset.change || '', inferred: li.hasAttribute('data-inferred'), li }));
  const m = buildModel(nodes, edges), conn = el.querySelector('details.sys-conn');
  let open = defaultOpen(m, K.BUDGET), shown = null, dead = false, ready = false, width = -1, tw = O();
  const box = O(), head = O(), headC = O();

  // wire layer: arrowheads, a hidden probe that measures label text, and a group that holds the wires
  while (svg.firstChild) svg.removeChild(svg.firstChild);
  const defs = mk('defs', {}, svg);
  ['', '-hot', '-added', '-modified', '-deleted'].forEach(s => {
    const mkr = mk('marker', { id: uid + s, viewBox: '0 0 8 8', refX: '7.2', refY: '4', markerWidth: '7', markerHeight: '7',
      orient: 'auto-start-reverse' }, defs);
    mk('path', { 'class': 'sys-arr' + (s ? ' sys-arr' + s : ''), d: 'M0,0.6 L8,4 L0,7.4 z' }, mkr);
  });
  const probe = mk('text', { 'class': 'sys-wl', visibility: 'hidden' }, svg), wg = mk('g', {}, svg);
  const textW = s => {
    if (!s) return 0;
    if (!(s in tw)) { probe.textContent = s; tw[s] = probe.getComputedTextLength(); }
    return tw[s];
  };
  const rect = n => { const r = n.getBoundingClientRect(); return { w: Math.ceil(r.width), h: Math.ceil(r.height) }; };
  const groupHead = id => els[id].querySelector(':scope > .sys-ghead');
  function measure() {  // natural sizes: every box; each group title open, then closed alone (a closed parent would hide it)
    const gs = m.ids.filter(id => m.group[id]);
    el.classList.remove('anim');
    m.ids.forEach(id => { const n = els[id]; n.style.width = ''; n.style.height = ''; n.classList.remove('closed'); });
    m.ids.forEach(id => { if (m.group[id]) head[id] = rect(groupHead(id)); else box[id] = rect(els[id]); });
    gs.forEach(id => { const c = els[id].classList; c.add('closed'); headC[id] = rect(groupHead(id)); c.remove('closed'); });
  }
  const size = (id, header) => header ? { w: head[id].w, h: head[id].h + K.HEAD_PAD }
    : m.group[id] ? { w: headC[id].w + 2 * K.PADX, h: headC[id].h + K.CLOSED_PAD } : box[id];

  function draw(out, anim) {
    while (wg.firstChild) wg.removeChild(wg.firstChild);
    svg.setAttribute('width', Math.ceil(out.W)); svg.setAttribute('height', Math.ceil(out.H));
    out.edges.forEach(e => {
      const cls = 'sys-w' + (e.async ? ' async' : '') + (e.inferred ? ' inferred' : '') + (e.n > 1 ? ' multi' : '') +
        (e.change ? ' chg-' + e.change : '');
      const p = mk('path', { d: e.d, 'class': cls }, wg);
      p.setAttribute(e.rev ? 'marker-start' : 'marker-end', 'url(#' + uid + (e.change ? '-' + e.change : '') + ')');
      p.dataset.a = e.a; p.dataset.b = e.b; p.dataset.mk = e.change ? '-' + e.change : '';
    });
    out.edges.forEach(e => {
      if (!e.label) return;
      const t = mk('text', { x: e.lx, y: e.ly + 3.5, 'text-anchor': 'middle', 'class': 'sys-wl' + (e.n > 1 ? ' multi' : '') }, wg);
      t.textContent = e.label; t.dataset.a = e.a; t.dataset.b = e.b; t.dataset.key = e.key;
    });
    if (anim) {  // wires return once the boxes have moved
      wg.style.transition = 'none'; wg.style.opacity = 0;
      setTimeout(() => { wg.style.transition = 'opacity .25s'; wg.style.opacity = 1; }, 400);
    }
  }
  function paint(out, anim) {
    el.dataset.dir = out.dir;
    el.classList.toggle('anim', !!anim);
    stage.style.width = Math.ceil(out.W) + 'px'; stage.style.height = Math.ceil(out.H) + 'px';
    m.ids.forEach(id => {
      const n = els[id], b = out.boxes[id];
      if (m.group[id]) {
        n.classList.toggle('closed', open[id] !== true);
        const t = n.querySelector(':scope > .sys-ghead .sys-tog');
        if (t) t.setAttribute('aria-expanded', open[id] === true ? 'true' : 'false');
      }
      if (!b) return;
      const g = m.parent[id], pb = g === ROOT ? { x: 0, y: 0 } : out.boxes[g], bw = g === ROOT ? 0 : 1;
      n.style.left = (b.x - pb.x - bw) + 'px'; n.style.top = (b.y - pb.y - bw) + 'px';
      n.style.width = b.w + 'px'; n.style.height = b.h + 'px';
    });
    draw(out, anim);
  }
  function off(e) {  // back to the plain view, for good
    dead = true; el.classList.remove('on', 'anim'); el.removeAttribute('data-dir');
    stage.style.width = ''; stage.style.height = '';
    m.ids.forEach(id => {
      const n = els[id]; n.classList.remove('closed', 'peer');
      n.style.left = ''; n.style.top = ''; n.style.width = ''; n.style.height = '';
    });
    while (wg.firstChild) wg.removeChild(wg.firstChild);
    if (conn) conn.open = true;
    warn(e);
  }
  function run(anim) {
    if (dead) return;
    try {
      const cs = getComputedStyle(el), avail = el.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
      if (!(avail > 0)) return;  // not shown yet (a closed sheet): wait for a width
      if (!ready) { el.classList.add('on'); measure(); ready = true; if (conn) conn.open = false; }
      let out = layout(m, open, size, textW, 'LR');
      if (out.W > avail) out = layout(m, open, size, textW, 'TB');
      const bad = verify(out, m);
      if (bad.length) throw new Error('layout check failed: ' + bad.join(', '));
      const still = G.matchMedia && G.matchMedia('(prefers-reduced-motion: reduce)').matches;
      paint(out, anim && !still); shown = out; width = el.clientWidth;
    } catch (e) { off(e); }
  }

  function hot(id) {
    const set = O(), mark = x => { set[x] = 1; m.kids[x].forEach(mark); };
    if (id != null && id in m.kids) mark(id); else id = null;
    svg.classList.toggle('dimmed', id != null);
    m.ids.forEach(x => els[x].classList.remove('peer'));
    [].forEach.call(wg.children, p => {
      const on = id != null && (p.dataset.a in set || p.dataset.b in set);
      p.classList.toggle('hot', on);
      if (p.tagName !== 'path') return;
      p.setAttribute(p.hasAttribute('marker-start') ? 'marker-start' : 'marker-end', 'url(#' + uid + (on ? '-hot' : p.dataset.mk) + ')');
      if (on) [p.dataset.a, p.dataset.b].forEach(x => { if (!(x in set) && els[x]) els[x].classList.add('peer'); });
    });
  }
  const idAt = t => { const n = t.closest('.sys-node[data-id],.sys-group[data-id]'); return n ? n.dataset.id : null; };
  ['mouseover', 'focusin'].forEach(k => stage.addEventListener(k, e => { if (!dead) hot(idAt(e.target)); }));
  ['mouseleave', 'focusout'].forEach(k => stage.addEventListener(k, () => { if (!dead) hot(null); }));
  stage.addEventListener('click', e => {
    if (dead) return;
    const wired = e.target.closest('[onclick]');
    if (wired && stage.contains(wired)) return;  // a wired label or box opens its detail instead
    const t = e.target.closest('.sys-tog'), g = t ? t.closest('.sys-group') : e.target.closest('.sys-group.closed');
    if (!g) return;
    const id = g.dataset.id;
    if (open[id] === true) delete open[id]; else open[id] = true;
    hot(null); run(true);
  });
  el.querySelectorAll('.sys-bar [data-act]').forEach(b => b.addEventListener('click', () => {
    if (dead) return;
    const a = b.dataset.act;
    if (a === 'auto') open = defaultOpen(m, K.BUDGET);
    else { open = O(); if (a === 'all') m.ids.forEach(id => { if (m.group[id]) open[id] = true; }); }
    hot(null); run(true);
  }));
  svg.addEventListener('click', e => {  // "N links": show which rows it stands for
    const t = e.target.closest('.sys-wl.multi');
    if (dead || !t || !shown) return;
    const w = shown.edges.filter(x => x.key === t.dataset.key)[0];
    if (!w) return;
    rows.forEach(li => li.classList.remove('hot'));
    w.items.forEach(x => { if (x.li) x.li.classList.add('hot'); });
    if (conn) { conn.open = true; if (conn.scrollIntoView) conn.scrollIntoView({ block: 'nearest' }); }
  });

  let queued = false;
  const again = () => {
    if (queued || dead) return;
    queued = true;
    requestAnimationFrame(() => { queued = false; if (el.clientWidth !== width) run(false); });
  };
  if (G.ResizeObserver) new G.ResizeObserver(again).observe(el); else G.addEventListener('resize', again);
  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(() => { if (dead || !ready) return; tw = O(); try { measure(); } catch (e) { off(e); return; } run(false); });
  }
  run(false);
}

const api = { ROOT, K, buildModel, leaves, defaultOpen, layout, verify, init };
if (typeof module !== 'undefined' && module.exports) module.exports = api;
else if (typeof document !== 'undefined') {
  G.WtSysMap = api;
  const boot = () => document.querySelectorAll('.sysmap').forEach(el => { try { init(el); } catch (e) { el.classList.remove('on', 'anim'); warn(e); } });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
}
})(typeof window !== 'undefined' ? window : globalThis);
/* end walkthrough system-map engine */
