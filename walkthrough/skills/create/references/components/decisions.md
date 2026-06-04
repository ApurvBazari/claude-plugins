# Component Catalog — Decisions & Comparison

## Tabs + tradeoff bars

**When:** The session weighed two or more options/approaches against each other. Tabs swap the detail pane and the tradeoff bars re-grow. Lifted from `seed.html` — includes the responsive `@media` that collapses tabs and the detail grid on narrow screens (these are NOT in the page scaffold and ship with this entry).

```html
<section id="<id>">
  <div class="sec-label"><decision></div>
  <h2>Tabs + animated <em>tradeoff</em> bars</h2>
  <div class="tabs">
    <div class="tab active" data-app="a" onclick="setTab('a')"><span class="letter">A</span><div class="tt"><Option A></div><div class="tb"><one-liner></div></div>
    <div class="tab chosen" data-app="b" onclick="setTab('b')"><span class="rec">Chosen</span><span class="letter">B</span><div class="tt"><Option B></div><div class="tb"><one-liner></div></div>
    <div class="tab" data-app="c" onclick="setTab('c')"><span class="letter">C</span><div class="tt"><Option C></div><div class="tb"><one-liner></div></div>
  </div>
  <div class="detail show" data-app="a">
    <div><h3 style="font-family:var(--serif);font-weight:400;margin:.1rem 0 .4rem"><Option A></h3><p style="font-size:.86rem;color:var(--ts)"><summary></p>
      <div class="proscons"><div class="p"><b>Pros</b><ul><li><pro></li></ul></div><div class="c"><b>Cons</b><ul><li><con></li></ul></div></div></div>
    <div class="chart">
      <div class="bar"><span><axis></span><div class="trk"><div class="fil" style="background:var(--rose)" data-w="30"></div></div><span>30</span></div>
      <div class="bar"><span><axis></span><div class="trk"><div class="fil" style="background:var(--green)" data-w="95"></div></div><span>95</span></div>
    </div>
  </div>
  <div class="detail" data-app="b"><!-- same shape; data-w drives the bars --></div>
  <div class="detail" data-app="c"><!-- same shape --></div>
</section>
```

```css
.tabs{display:grid;grid-template-columns:repeat(3,1fr);gap:.8rem;margin:1.4rem 0;}
.tab{position:relative;text-align:left;background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1rem 1.1rem;cursor:pointer;transition:all .25s var(--ease);}
.tab:hover{border-color:var(--border-strong);}
.tab.active{border-color:var(--accent);background:var(--bg-card-hover);box-shadow:0 0 0 1px var(--accent),0 8px 32px -8px var(--accent-glow);}
.tab .letter{font-family:var(--serif);font-style:italic;font-size:1.5rem;color:var(--accent);}
.tab .tt{font-weight:600;margin:.2rem 0;}
.tab .tb{font-size:.8rem;color:var(--ts);}
.rec{position:absolute;top:-9px;right:12px;font-family:var(--mono);font-size:.58rem;text-transform:uppercase;letter-spacing:.1em;background:var(--accent);color:var(--bg-deep);padding:.2rem .5rem;border-radius:20px;opacity:0;transition:opacity .3s;}
.tab.chosen .rec{opacity:1;}
.detail{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.3rem;display:none;}
.detail.show{display:grid;grid-template-columns:1.3fr 1fr;gap:1.6rem;animation:fadeUp .4s var(--ease);}
.proscons{display:flex;gap:1.4rem;margin-top:.7rem;font-size:.82rem;}
.proscons .p b,.proscons .c b{font-family:var(--mono);font-size:.6rem;text-transform:uppercase;letter-spacing:.1em;display:block;margin-bottom:.3rem;}
.proscons .p li{color:var(--green);} .proscons .c li{color:var(--rose);}
.proscons ul{margin:0;padding-left:1rem;}
.bar{display:grid;grid-template-columns:90px 1fr 28px;gap:.7rem;align-items:center;margin-bottom:.6rem;font-family:var(--mono);font-size:.66rem;}
.bar .trk{height:9px;background:var(--border);border-radius:5px;overflow:hidden;}
.bar .fil{height:100%;border-radius:5px;width:0;transition:width .8s var(--ease);}
@keyframes fadeUp{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:none}}
/* responsive — ships with the tabs entry (NOT in the scaffold) */
@media(max-width:780px){.tabs{grid-template-columns:1fr}.detail.show{grid-template-columns:1fr}}
```

**Wiring:** tabs → `setTab('<app>')` (toggles `.active`/`.show`, then calls `animate`); bars grow via `animate(scope)` reading `data-w`, re-fired by the IntersectionObserver and the initial-paint `setTimeout`.

## Accordion checklist

**When:** A definition-of-done, list of decisions, or requirements where each row has a verdict and an expandable rationale. Native `<details>` expand/collapse. Lifted from `seed.html`.

```html
<section id="<id>">
  <div class="sec-label"><checklist></div>
  <h2>Decision <em>checklist</em></h2>
  <div class="acc">
    <details open><summary><span class="badge" style="background:var(--green-soft);color:var(--green)">✓</span> <Decision/requirement><span class="chev">›</span></summary>
      <div class="ac-body"><Rationale.><div class="ref"><file:line ref></div></div></details>
    <details><summary><span class="badge" style="background:var(--amber-soft);color:var(--amber)">+</span> <Item><span class="chev">›</span></summary>
      <div class="ac-body"><Rationale.></div></details>
    <details><summary><span class="badge" style="background:var(--purple-soft);color:var(--purple)">·</span> <Deferred item><span class="chev">›</span></summary>
      <div class="ac-body"><Why deferred.></div></details>
  </div>
</section>
```

```css
.acc{border:1px solid var(--border);border-radius:10px;overflow:hidden;margin-top:1rem;}
.acc details{border-bottom:1px solid var(--border);}
.acc details:last-child{border-bottom:none;}
.acc summary{list-style:none;padding:.85rem 1.1rem;cursor:pointer;display:flex;align-items:center;gap:.7rem;background:var(--bg-card);font-size:.9rem;}
.acc summary::-webkit-details-marker{display:none;}
.acc summary .badge{width:18px;height:18px;border-radius:5px;font-size:.7rem;display:flex;align-items:center;justify-content:center;font-family:var(--mono);}
.acc summary .chev{margin-left:auto;color:var(--tm);transition:transform .2s;}
.acc details[open] summary .chev{transform:rotate(90deg);}
.acc .ac-body{padding:.4rem 1.1rem 1rem 2.7rem;font-size:.84rem;color:var(--ts);background:var(--bg-card);}
.acc .ref{font-family:var(--mono);font-size:.66rem;color:var(--accent);margin-top:.4rem;}
```

**Wiring:** No JS — native `<details>` toggling. Revealed by the IntersectionObserver with its section.

## Diff panes

**When:** The session changed code/config and a before/after comparison clarifies it. Two side-by-side panes, collapsing to one column on narrow screens. Built in OUR tokens.

```html
<section id="<id>">
  <div class="sec-label"><diff></div>
  <h2>Before <em>/</em> after</h2>
  <div class="diff-grid">
    <div class="diff-pane"><div class="diff-header before">before · <file></div><pre class="diff-body"><old code></pre></div>
    <div class="diff-pane"><div class="diff-header after">after · <file></div><pre class="diff-body"><new code></pre></div>
  </div>
</section>
```

```css
.diff-grid{display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin:1.2rem 0;}
.diff-pane{background:var(--bg-card);border:1px solid var(--border);border-radius:10px;overflow:hidden;}
.diff-header{background:var(--bg-elevated);padding:.5rem .9rem;font-family:var(--mono);font-size:.66rem;font-weight:600;color:var(--tm);text-transform:uppercase;letter-spacing:.04em;border-bottom:1px solid var(--border);}
.diff-header.before{color:var(--amber);}
.diff-header.after{color:var(--green);}
.diff-body{margin:0;padding:.9rem 1rem;font-family:var(--mono);font-size:.78rem;line-height:1.6;color:var(--ts);white-space:pre;overflow-x:auto;}
@media(max-width:780px){.diff-grid{grid-template-columns:1fr;}}
```

**Wiring:** No handler. Revealed by the IntersectionObserver.

## Comparison table

**When:** Comparing several options across the same set of criteria (feature matrix, before/after capabilities). Status badges (yes/no/upgraded) in cells. Built in OUR tokens.

```html
<section id="<id>">
  <div class="sec-label"><comparison></div>
  <h2>Side-by-side <em>comparison</em></h2>
  <table class="compare-table">
    <thead><tr><th><criterion></th><th><Option A></th><th><Option B></th></tr></thead>
    <tbody>
      <tr><td class="label-cell"><row label></td><td><span class="badge-yes">✓ yes</span></td><td><span class="badge-no">— no</span></td></tr>
      <tr><td class="label-cell"><row label></td><td><span class="badge-upgraded">↑ upgraded</span></td><td><span class="badge-yes">✓ yes</span></td></tr>
    </tbody>
  </table>
</section>
```

```css
.compare-table{width:100%;border-collapse:separate;border-spacing:0;font-size:.82rem;background:var(--bg-card);border:1px solid var(--border);border-radius:12px;overflow:hidden;margin:1.2rem 0;}
.compare-table th{font-family:var(--mono);font-size:.68rem;text-transform:uppercase;letter-spacing:.08em;color:var(--tm);padding:.85rem 1.25rem;text-align:left;background:var(--bg-elevated);border-bottom:1px solid var(--border);font-weight:500;}
.compare-table td{padding:.75rem 1.25rem;border-bottom:1px solid var(--border);color:var(--ts);vertical-align:top;}
.compare-table tr:last-child td{border-bottom:none;}
.compare-table tr:hover td{background:var(--bg-card-hover);}
.compare-table .label-cell{font-weight:500;color:var(--tp);font-size:.82rem;}
.badge-yes{display:inline-flex;align-items:center;gap:.3rem;font-family:var(--mono);font-size:.68rem;color:var(--green);background:var(--green-soft);padding:.2rem .55rem;border-radius:4px;}
.badge-no{display:inline-flex;align-items:center;gap:.3rem;font-family:var(--mono);font-size:.68rem;color:var(--tm);background:var(--bg-inset);padding:.2rem .55rem;border-radius:4px;}
.badge-upgraded{display:inline-flex;align-items:center;gap:.3rem;font-family:var(--mono);font-size:.68rem;color:var(--accent);background:var(--accent-soft);padding:.2rem .55rem;border-radius:4px;}
```

**Wiring:** No handler. Revealed by the IntersectionObserver.

