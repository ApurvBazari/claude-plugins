# Component Catalog

Curated catalog — a floor, not a ceiling. Each entry is copy-and-fill, uses ONLY design-system tokens (never raw hex), and wires to the shared handlers in `interactivity.md`. Render only components with real content (see `authoring-guide.md`). For anything not here, compose a bespoke component per `authoring-guide.md` §"compose a new component".

Every entry below carries **When** (the session content that triggers it), an **HTML** snippet (copy-and-fill — replace `<placeholders>`), a **CSS** block (paste once into the document `<style>`; identical classes can share one paste), and a **Wiring** line naming the shared handler from `interactivity.md`. Component-unique JS, where unavoidable, is flagged as a `{{COMPONENT_JS}}` snippet to append to the shared bundle.

## Hero + stat grid

**When:** Always — the opening section. Eyebrow + serif headline + lede, optional palette strip, and a stat grid summarising the session (counts of files, decisions, stages, etc.).

```html
<section id="top" class="vis" style="padding-top:2.4rem">
  <div class="eyebrow"><eyebrow text · e.g. session walkthrough></div>
  <h1><Headline with an <em>accent</em> word.></h1>
  <p class="lede"><One- or two-sentence summary of what the session was about.></p>
  <div class="hstats">
    <div class="hstat"><div class="v"><em><N></em></div><div class="l"><label></div></div>
    <div class="hstat"><div class="v"><N></div><div class="l"><label></div></div>
    <div class="hstat"><div class="v"><N></div><div class="l"><label></div></div>
    <div class="hstat"><div class="v"><N></div><div class="l"><label></div></div>
  </div>
</section>
```

```css
.eyebrow{font-family:var(--mono);font-size:.68rem;color:var(--accent);text-transform:uppercase;letter-spacing:.18em;display:inline-flex;align-items:center;gap:.6rem;margin-bottom:.8rem;}
.eyebrow::before{content:'';width:26px;height:1px;background:var(--accent);}
h1{font-family:var(--serif);font-size:clamp(2.4rem,6vw,4rem);font-weight:400;line-height:1.04;letter-spacing:-.025em;margin:.2rem 0;max-width:880px;}
h1 em,h2 em{font-style:italic;color:var(--accent);}
.lede{color:var(--ts);font-size:1.08rem;line-height:1.7;max-width:720px;margin:.6rem 0 0;}
.hstats{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:1px;background:var(--border);border:1px solid var(--border);border-radius:12px;overflow:hidden;margin-top:1.8rem;}
.hstat{background:var(--bg-card);padding:1.1rem 1.2rem;}
.hstat .v{font-family:var(--serif);font-size:1.9rem;color:var(--tp);line-height:1;}
.hstat .v em{font-style:italic;color:var(--accent);}
.hstat .l{font-family:var(--mono);font-size:.6rem;color:var(--tm);text-transform:uppercase;letter-spacing:.1em;margin-top:.4rem;}
```

**Wiring:** No click handler. The hero section is revealed by the IntersectionObserver (`.vis`) and feeds the `#prog` scroll bar; start it with `class="vis"` so it paints immediately above the fold.

## Prose section

**When:** Any narrative block — context, summary, rationale, "what happened". The connective tissue between interactive components.

```html
<section id="<id>">
  <div class="sec-label"><NN — section kicker></div>
  <h2><Section heading with an <em>accent</em>.></h2>
  <p class="lede"><Lead sentence.></p>
  <p><Body paragraph. Inline <code>code</code> and <strong>emphasis</strong> are fine.></p>
</section>
```

```css
section{padding:4rem 0 2rem;scroll-margin-top:70px;opacity:0;transform:translateY(24px);transition:opacity .7s var(--ease),transform .7s var(--ease);}
section.vis{opacity:1;transform:none;}
.sec-label{font-family:var(--mono);font-size:.65rem;color:var(--tm);text-transform:uppercase;letter-spacing:.15em;margin-bottom:.5rem;}
h2{font-family:var(--serif);font-size:clamp(1.7rem,3.5vw,2.4rem);font-weight:400;line-height:1.15;margin:.2rem 0 .3rem;}
p{font-size:.92rem;color:var(--ts);max-width:720px;}
p code{font-family:var(--mono);font-size:.8rem;background:var(--accent-soft);color:var(--accent);padding:1px 5px;border-radius:4px;}
```

**Wiring:** Reveal-on-scroll via the IntersectionObserver (`.vis`); the section `id` is picked up by nav scrollspy.

## Tabs + tradeoff bars

**When:** The session weighed two or more options/approaches against each other. Tabs swap the detail pane and the tradeoff bars re-grow. Lifted from `seed.html` — includes the responsive `@media` that collapses tabs and the detail grid on narrow screens (these are NOT in the page scaffold and ship with this entry).

```html
<section id="<id>">
  <div class="sec-label"><NN — decision></div>
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

## Flow / pipeline diagram

**When:** The session described a linear pipeline or staged process. Horizontal nodes with arrows; click a node for detail in the side panel. Lifted from `seed.html`.

```html
<section id="<id>">
  <div class="sec-label"><NN — flow></div>
  <h2>Animated <em>flow</em> diagram</h2>
  <div class="flow">
    <div class="fnode" data-d="<id1>" onclick="openD('<id1>')"><div class="nl"><stage 1></div><Label></div>
    <span class="farr">→</span>
    <div class="fnode accent" data-d="<id2>" onclick="openD('<id2>')"><div class="nl"><stage 2></div><Label></div>
    <span class="farr">→</span>
    <div class="fnode" data-d="<id3>" onclick="openD('<id3>')"><div class="nl"><stage 3></div><Label></div>
  </div>
</section>
```

```css
.flow{display:flex;align-items:center;flex-wrap:wrap;gap:.4rem;background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.5rem;margin:1.2rem 0;}
.fnode{flex:1;min-width:110px;background:var(--bg-elevated);border:1px solid var(--border);border-radius:10px;padding:.8rem .9rem;font-family:var(--mono);font-size:.7rem;cursor:pointer;transition:all .3s var(--ease);}
.fnode:hover{border-color:var(--accent);box-shadow:0 0 20px var(--accent-glow);transform:scale(1.03);}
.fnode .nl{font-size:.55rem;color:var(--tm);text-transform:uppercase;letter-spacing:.1em;}
.fnode.accent{border-color:color-mix(in srgb,var(--accent) 40%,transparent);background:linear-gradient(135deg,var(--bg-elevated),var(--accent-soft));}
.farr{color:var(--border-strong);font-size:1.1rem;}
```

**Wiring:** click → `openD('<id>')` (reads the `DET` object in `interactivity.md` — add a matching `DET` key per node with `{k,h,b}`). Escape closes the panel.

## Architecture map

**When:** The session described a system with components that connect non-linearly (services, layers, a fan-out). Built in OUR tokens as labelled boxes joined by arrows.

```html
<section id="<id>">
  <div class="sec-label"><NN — architecture></div>
  <h2>Component <em>map</em></h2>
  <div class="archmap">
    <div class="flow-node accent" data-d="<id1>" onclick="openD('<id1>')"><span class="node-label"><layer></span><Component A></div>
    <span class="flow-arrow">→</span>
    <div class="flow-node green" data-d="<id2>" onclick="openD('<id2>')"><span class="node-label"><layer></span><Component B></div>
    <span class="flow-arrow">→</span>
    <div class="flow-node amber" data-d="<id3>" onclick="openD('<id3>')"><span class="node-label"><layer></span><Component C></div>
  </div>
</section>
```

```css
.archmap{display:flex;align-items:center;flex-wrap:wrap;gap:.4rem;background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.5rem;margin:1.2rem 0;justify-content:center;}
.flow-node{background:var(--bg-elevated);border:1px solid var(--border);border-radius:10px;padding:.85rem 1.25rem;font-family:var(--mono);font-size:.72rem;color:var(--tp);text-align:center;position:relative;transition:all .3s var(--ease);cursor:pointer;min-width:140px;}
.flow-node:hover{border-color:var(--accent);box-shadow:0 0 20px var(--accent-glow);transform:scale(1.03);}
.flow-node.accent{border-color:color-mix(in srgb,var(--accent) 30%,transparent);background:linear-gradient(135deg,var(--bg-elevated),var(--accent-soft));}
.flow-node.green{border-color:color-mix(in srgb,var(--green) 30%,transparent);background:linear-gradient(135deg,var(--bg-elevated),var(--green-soft));}
.flow-node.amber{border-color:color-mix(in srgb,var(--amber) 30%,transparent);background:linear-gradient(135deg,var(--bg-elevated),var(--amber-soft));}
.flow-node .node-label{font-size:.6rem;color:var(--tm);text-transform:uppercase;letter-spacing:.1em;margin-bottom:.3rem;display:block;}
.flow-arrow{color:var(--tm);font-size:1.2rem;padding:0 .75rem;opacity:.4;flex-shrink:0;}
```

**Wiring:** click → `openD('<id>')` (add `DET` keys per node). Reveal via the IntersectionObserver.

## Dependency graph

**When:** The session is about how modules/packages/files depend on each other. Inline SVG (self-contained, no `<img>`) with token-coloured edges and nodes; hover edges glow.

```html
<section id="<id>">
  <div class="sec-label"><NN — dependencies></div>
  <h2>Dependency <em>graph</em></h2>
  <div class="depgraph">
    <svg viewBox="0 0 600 220" role="img" aria-label="<dependency graph description>">
      <g class="dg-edge"><line x1="120" y1="60" x2="300" y2="60"/><line x1="120" y1="60" x2="300" y2="160"/><line x1="300" y1="60" x2="480" y2="110"/><line x1="300" y1="160" x2="480" y2="110"/></g>
      <g class="dg-node"><rect x="40" y="40" width="160" height="40" rx="8"/><text x="120" y="65" text-anchor="middle"><root module></text></g>
      <g class="dg-node"><rect x="220" y="40" width="160" height="40" rx="8"/><text x="300" y="65" text-anchor="middle"><dep A></text></g>
      <g class="dg-node"><rect x="220" y="140" width="160" height="40" rx="8"/><text x="300" y="165" text-anchor="middle"><dep B></text></g>
      <g class="dg-node leaf"><rect x="400" y="90" width="160" height="40" rx="8"/><text x="480" y="115" text-anchor="middle"><shared leaf></text></g>
    </svg>
  </div>
</section>
```

```css
.depgraph{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.5rem;margin:1.2rem 0;overflow-x:auto;}
.depgraph svg{display:block;min-width:560px;max-width:100%;height:auto;}
.dg-edge line{stroke:var(--border-strong);stroke-width:1.5;transition:stroke .3s var(--ease);}
.depgraph:hover .dg-edge line{stroke:var(--accent);}
.dg-node rect{fill:var(--bg-elevated);stroke:var(--border);transition:all .3s var(--ease);}
.dg-node:hover rect{stroke:var(--accent);}
.dg-node.leaf rect{fill:color-mix(in srgb,var(--bg-elevated),var(--accent-soft));stroke:color-mix(in srgb,var(--accent) 30%,transparent);}
.dg-node text{font-family:var(--mono);font-size:11px;fill:var(--tp);}
```

**Wiring:** No handler required (pure CSS hover glow). Reveal via the IntersectionObserver. Coordinates are placeholders — lay nodes out by hand and connect with `<line>` per real edge.

## Morphing-mode diagram

**When:** The same system behaves two (or more) ways depending on a mode/environment toggle. A pill toggle swaps SVG node text in place. Built in OUR tokens. **Needs a small component-JS snippet** (one of a few entries — alongside the animated bar chart and stepper — that ships its own `{{COMPONENT_JS}}`).

```html
<section id="<id>">
  <div class="sec-label"><NN — modes></div>
  <h2>Request <em>lifecycle</em></h2>
  <div class="mode-toggle" id="mode">
    <button class="active" data-mode="m1"><Mode 1></button>
    <button data-mode="m2"><Mode 2></button>
  </div>
  <div class="mode-stage">
    <svg viewBox="0 0 600 160" id="modeSvg" role="img" aria-label="<mode diagram>">
      <g class="m-node"><rect x="20" y="50" width="150" height="60" rx="8"/><text x="95" y="80" text-anchor="middle" id="mClient"><client></text></g>
      <g class="m-node active"><rect x="225" y="50" width="150" height="60" rx="8"/><text x="300" y="80" text-anchor="middle" id="mEdge"><edge></text></g>
      <g class="m-node"><rect x="430" y="50" width="150" height="60" rx="8"/><text x="505" y="80" text-anchor="middle" id="mServer"><server></text></g>
    </svg>
  </div>
</section>
```

```css
.mode-toggle{display:inline-flex;background:var(--bg-card);border:1px solid var(--border);border-radius:100px;padding:4px;margin:1rem 0 1.2rem;}
.mode-toggle button{background:transparent;border:none;cursor:pointer;padding:.45rem 1.1rem;font-family:var(--mono);font-size:.72rem;color:var(--ts);border-radius:100px;transition:all .3s var(--ease);}
.mode-toggle button.active{background:var(--accent);color:var(--bg-deep);font-weight:600;box-shadow:0 0 0 1px var(--accent),0 4px 12px -4px var(--accent-glow);}
.mode-stage{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.5rem;overflow-x:auto;}
.mode-stage svg{display:block;min-width:560px;max-width:100%;height:auto;}
.m-node rect{fill:var(--bg-elevated);stroke:var(--border-strong);transition:all .6s var(--ease);}
.m-node.active rect{stroke:var(--accent);fill:var(--bg-card-hover);}
.m-node text{font-family:var(--mono);font-size:12px;fill:var(--tp);}
```

**Wiring:** Component-unique — append this `{{COMPONENT_JS}}` to the shared bundle (do not invent global names beyond it):

```js
// {{COMPONENT_JS}} — morphing-mode diagram
const MODES={m1:{client:'<client>',edge:'<edge>',server:'<server>'},m2:{client:'<client2>',edge:'<edge2>',server:'<server2>'}};
function setMode(m){const d=MODES[m];if(!d)return;mClient.textContent=d.client;mEdge.textContent=d.edge;mServer.textContent=d.server;}
document.querySelectorAll('#mode button').forEach(b=>b.addEventListener('click',()=>{document.querySelectorAll('#mode button').forEach(x=>x.classList.toggle('active',x===b));setMode(b.dataset.mode);}));
```

## File tree

**When:** The session created, moved, or touched several files and the directory layout matters. `white-space:pre` preserves the drawn tree; file rows can be clickable. Lifted from `prototype-spec.html`.

```html
<section id="<id>">
  <div class="sec-label"><NN — files></div>
  <h2>File <em>tree</em></h2>
  <div class="tree"><span class="dir"><root>/</span>            <span class="nw"><N new></span>
├── <span class="fl" data-d="<id1>" onclick="openD('<id1>')"><file-a></span> <span class="nw">new</span>
├── <span class="dir"><subdir>/</span>
│   └── <span class="fl" data-d="<id2>" onclick="openD('<id2>')"><file-b></span> <span class="ed">edited</span>
└── <span class="fl"><file-c></span></div>
</section>
```

```css
.tree{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.1rem 1.3rem;font-family:var(--mono);font-size:.72rem;line-height:1.75;color:var(--ts);white-space:pre;overflow-x:auto;margin-top:1rem;}
.tree .dir{color:var(--accent);}
.tree .fl{color:var(--blue);cursor:pointer;}
.tree .fl:hover{color:var(--tp);}
.tree .nw{color:var(--green);font-size:.58rem;}
.tree .ed{color:var(--amber);font-size:.58rem;}
```

**Wiring:** click on a `.fl` → `openD('<id>')` (add a `DET` key per clickable file). Non-clickable files use a plain `.fl` with no handler.

## Filterable cards + pills

**When:** The session produced many discrete items (commits, tests, tools, tasks) that group into categories. Toggle a pill to show/hide a category. Lifted from `seed.html`.

```html
<section id="<id>">
  <div class="sec-label"><NN — catalog></div>
  <h2>Filterable <em>cards</em></h2>
  <div class="pills">
    <div class="pill on" data-f="<catA>" onclick="tog(this)"><span class="s" style="background:var(--green)"></span><catA></div>
    <div class="pill on" data-f="<catB>" onclick="tog(this)"><span class="s" style="background:var(--amber)"></span><catB></div>
  </div>
  <div class="cards">
    <div class="tcard" data-cat="<catA>" style="border-left-color:var(--green)"><div class="cat" style="color:var(--green)"><catA></div><div class="tn"><title></div><div class="td"><one-line description></div></div>
    <div class="tcard" data-cat="<catB>" style="border-left-color:var(--amber)"><div class="cat" style="color:var(--amber)"><catB></div><div class="tn"><title></div><div class="td"><one-line description></div></div>
  </div>
</section>
```

```css
.pills{display:flex;gap:.5rem;flex-wrap:wrap;margin:1rem 0;}
.pill{font-family:var(--mono);font-size:.66rem;padding:.35rem .7rem;border-radius:20px;border:1px solid var(--border);background:var(--bg-card);color:var(--ts);cursor:pointer;display:flex;align-items:center;gap:.4rem;transition:.2s;}
.pill .s{width:9px;height:9px;border-radius:3px;}
.pill.on{color:var(--tp);border-color:var(--border-strong);background:var(--bg-card-hover);}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:.8rem;}
.tcard{background:var(--bg-card);border:1px solid var(--border);border-left-width:3px;border-radius:10px;padding:.9rem 1rem;transition:.25s;cursor:pointer;}
.tcard:hover{border-color:var(--border-strong);}
.tcard.hidden{display:none;}
.tcard .cat{font-family:var(--mono);font-size:.55rem;text-transform:uppercase;letter-spacing:.1em;}
.tcard .tn{font-weight:600;margin:.25rem 0;font-size:.92rem;}
.tcard .td{font-size:.8rem;color:var(--ts);}
```

**Wiring:** pills → `tog(this)` (rebuilds the active `data-f` set and hides `.tcard`s whose `data-cat` isn't active). For a card detail panel, add `data-t`/`data-desc` and `onclick="openCard(this)"`.

## Stat / metric cards

**When:** A handful of headline numbers worth surfacing as a row (added/removed/deferred counts, response sizes, coverage). Top-stripe accent per status. Built in OUR tokens.

```html
<section id="<id>">
  <div class="sec-label"><NN — metrics></div>
  <h2>By the <em>numbers</em></h2>
  <div class="stat-grid">
    <div class="stat-card added"><div class="stat-label"><label></div><div class="stat-value"><N></div><div class="stat-sub"><context></div></div>
    <div class="stat-card removed"><div class="stat-label"><label></div><div class="stat-value"><N></div><div class="stat-sub"><context></div></div>
    <div class="stat-card deferred"><div class="stat-label"><label></div><div class="stat-value"><N></div><div class="stat-sub"><context></div></div>
  </div>
</section>
```

```css
.stat-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:.8rem;margin:1.2rem 0;}
.stat-card{background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:1.1rem 1.1rem 1rem;position:relative;overflow:hidden;}
.stat-card::before{content:'';position:absolute;top:0;left:0;right:0;height:3px;background:var(--accent);}
.stat-card.added::before{background:var(--green);}
.stat-card.removed::before{background:var(--rose);}
.stat-card.deferred::before{background:var(--purple);}
.stat-card.skipped::before{background:var(--tm);}
.stat-card.scope::before{background:var(--amber);}
.stat-label{font-family:var(--mono);font-size:.62rem;color:var(--tm);text-transform:uppercase;letter-spacing:.06em;margin-bottom:.3rem;}
.stat-value{font-family:var(--mono);font-size:1.7rem;font-weight:700;color:var(--tp);font-variant-numeric:tabular-nums;}
.stat-sub{font-size:.74rem;color:var(--tm);margin-top:.25rem;}
```

**Wiring:** Static — revealed by the IntersectionObserver. For an animated count-up, set the final value as text and the bar growth is unnecessary; if you want the number to tick, reuse the animated bar chart pattern instead.

## Animated bar chart

**When:** Comparing magnitudes across many items (file sizes, durations, token counts). Bars grow left-to-right when scrolled into view; rows can expand a breakdown. Built in OUR tokens. **Needs the small reveal JS below** (or reuse the shared `animate` if you give bars `.fil`/`data-w` instead).

```html
<section id="<id>">
  <div class="sec-label"><NN — sizes></div>
  <h2>Relative <em>sizes</em></h2>
  <div class="size-chart" id="sizeChart">
    <div class="size-header"><span><item></span><span><magnitude></span><span><value></span></div>
    <div class="size-row">
      <div class="tool-name"><label></div>
      <div class="size-bar-track"><div class="size-bar" style="background:var(--accent)" data-width="80"><span class="bar-label"><inline></span></div></div>
      <div class="size-value"><value></div>
    </div>
    <div class="size-row">
      <div class="tool-name"><label></div>
      <div class="size-bar-track"><div class="size-bar" style="background:var(--blue)" data-width="45"><span class="bar-label"><inline></span></div></div>
      <div class="size-value"><value></div>
    </div>
  </div>
</section>
```

```css
.size-chart{background:var(--bg-card);border:1px solid var(--border);border-radius:14px;padding:1.5rem 1.8rem;margin:1.2rem 0;overflow:visible;}
.size-header{display:grid;grid-template-columns:180px 1fr 70px;gap:1rem;padding-bottom:.5rem;margin-bottom:.5rem;border-bottom:2px solid var(--border-strong);}
.size-header span{font-family:var(--mono);font-size:.6rem;text-transform:uppercase;letter-spacing:.1em;color:var(--tm);}
.size-header span:last-child{text-align:right;}
.size-row{display:grid;grid-template-columns:180px 1fr 70px;align-items:center;gap:1rem;padding:.7rem 0;border-bottom:1px solid var(--border);}
.size-row:last-child{border-bottom:none;}
.size-row .tool-name{font-family:var(--mono);font-size:.78rem;font-weight:500;color:var(--accent);}
.size-bar-track{height:24px;background:var(--bg-inset);border-radius:6px;overflow:hidden;}
.size-bar{height:100%;border-radius:6px;width:0;transition:width 1.2s var(--ease);display:flex;align-items:center;padding-left:8px;min-width:0;}
.size-bar .bar-label{font-family:var(--mono);font-size:.6rem;color:var(--bg-deep);white-space:nowrap;opacity:.9;}
.size-value{font-family:var(--mono);font-size:.78rem;font-weight:600;color:var(--tp);text-align:right;}
```

**Wiring:** bars animate via an IntersectionObserver reading `data-width`. Append this `{{COMPONENT_JS}}` (or convert bars to the shared `.fil[data-w]` pattern so the shared `animate` handles them):

```js
// {{COMPONENT_JS}} — size-chart reveal
const _sc=new IntersectionObserver(es=>es.forEach(e=>{if(e.isIntersecting){e.target.querySelectorAll('.size-bar').forEach(b=>b.style.width=b.dataset.width+'%');_sc.disconnect();}}),{threshold:.2});
const _scEl=document.getElementById('sizeChart');if(_scEl)_sc.observe(_scEl);
```

## Accordion checklist

**When:** A definition-of-done, list of decisions, or requirements where each row has a verdict and an expandable rationale. Native `<details>` expand/collapse. Lifted from `seed.html`.

```html
<section id="<id>">
  <div class="sec-label"><NN — checklist></div>
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
  <div class="sec-label"><NN — diff></div>
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
  <div class="sec-label"><NN — comparison></div>
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

## Timeline

**When:** The session has a chronological story — versions, milestones, an ordered sequence of events. Vertical rail with dots; the current item highlights. Built in OUR tokens.

```html
<section id="<id>">
  <div class="sec-label"><NN — timeline></div>
  <h2>How it <em>unfolded</em></h2>
  <div class="timeline">
    <div class="timeline-item"><div class="timeline-version"><label></div><div class="timeline-date"><when></div><div class="timeline-desc"><what happened></div></div>
    <div class="timeline-item active"><div class="timeline-version"><label></div><div class="timeline-date"><when></div><div class="timeline-desc"><what happened></div></div>
    <div class="timeline-item"><div class="timeline-version"><label></div><div class="timeline-date"><when></div><div class="timeline-desc"><what happened></div></div>
  </div>
</section>
```

```css
.timeline{position:relative;padding-left:2rem;margin:1.2rem 0;}
.timeline::before{content:'';position:absolute;left:7px;top:0;bottom:0;width:2px;background:var(--border);}
.timeline-item{position:relative;padding-bottom:2rem;padding-left:1.5rem;}
.timeline-item::before{content:'';position:absolute;left:-2rem;top:6px;width:16px;height:16px;border-radius:50%;border:2px solid var(--border);background:var(--bg-deep);}
.timeline-item.active::before{border-color:var(--accent);background:var(--accent);box-shadow:0 0 12px var(--accent-glow);}
.timeline-version{font-family:var(--mono);font-size:.82rem;font-weight:600;color:var(--tp);margin-bottom:.25rem;}
.timeline-date{font-family:var(--mono);font-size:.68rem;color:var(--tm);margin-bottom:.5rem;}
.timeline-desc{font-size:.82rem;color:var(--ts);line-height:1.6;}
```

**Wiring:** No handler. Revealed by the IntersectionObserver.

## Stepper / playback

**When:** A sequence the reader should step through (an end-to-end trace, a replayable run). A play button advances a progress fill; status text narrates. Built in OUR tokens. **Needs a small component-JS snippet** to advance steps.

```html
<section id="<id>">
  <div class="sec-label"><NN — playback></div>
  <h2>Step <em>through</em> it</h2>
  <div class="player">
    <div class="player-stage" id="playerStage"><!-- step content rendered/revealed here --></div>
    <div class="playback-bar">
      <button class="play-btn" onclick="playStep()" aria-label="play"><svg viewBox="0 0 16 16"><path d="M3 2l11 6-11 6z"/></svg></button>
      <div class="playback-progress"><div class="playback-fill" id="playbackFill"></div></div>
      <div class="playback-status" id="playbackStatus">Click play to step</div>
    </div>
  </div>
</section>
```

```css
.player{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;overflow:hidden;margin:1.2rem 0;}
.player-stage{padding:1.2rem 1.4rem;font-family:var(--mono);font-size:.78rem;color:var(--ts);min-height:80px;}
.playback-bar{display:flex;align-items:center;gap:.75rem;padding:.75rem 1.25rem;background:var(--bg-elevated);border-top:1px solid var(--border);}
.play-btn{width:32px;height:32px;border-radius:50%;background:var(--accent);border:none;cursor:pointer;display:flex;align-items:center;justify-content:center;transition:all .2s var(--ease);flex-shrink:0;}
.play-btn:hover{transform:scale(1.08);filter:brightness(1.1);}
.play-btn svg{fill:var(--bg-deep);width:14px;height:14px;margin-left:2px;}
.playback-progress{flex:1;height:4px;background:var(--border);border-radius:2px;overflow:hidden;cursor:pointer;}
.playback-fill{height:100%;background:var(--accent);border-radius:2px;width:0;transition:width .3s var(--ease);}
.playback-status{font-family:var(--mono);font-size:.65rem;color:var(--tm);white-space:nowrap;min-width:100px;text-align:right;}
```

**Wiring:** Component-unique — append this `{{COMPONENT_JS}}` (fill `STEPS` with the real sequence):

```js
// {{COMPONENT_JS}} — stepper/playback
const STEPS=['<step 1>','<step 2>','<step 3>'];let _si=0;
function playStep(){if(_si>=STEPS.length)_si=0;const stage=document.getElementById('playerStage');const f=document.getElementById('playbackFill'),s=document.getElementById('playbackStatus');
 if(stage)stage.textContent=STEPS[_si];_si++;if(f)f.style.width=Math.round(_si/STEPS.length*100)+'%';if(s)s.textContent=_si+' / '+STEPS.length;}
```

## Callouts

**When:** A single point needs emphasis — a caveat, a key insight, a non-obvious constraint. Accent left-border panel. Lifted from `prototype-spec.html`.

```html
<div class="callout"><h4><Callout heading></h4><p><The point, in one or two sentences. Inline <code>code</code> allowed.></p></div>
```

```css
.callout{background:var(--accent-soft);border-left:3px solid var(--accent);border-radius:0 10px 10px 0;padding:.9rem 1.2rem;margin:1.1rem 0;}
.callout h4{font-family:var(--serif);font-weight:400;color:var(--accent);margin:0 0 .3rem;font-size:1.1rem;}
.callout p{margin:0;font-size:.86rem;color:var(--ts);}
.callout code{font-family:var(--mono);font-size:.78rem;background:var(--bg-card);color:var(--accent);padding:1px 5px;border-radius:4px;}
```

**Wiring:** No handler. Sits inline within any section; revealed with its parent section. For a numbered variant (open questions / edge cases), use the Key–value metadata grid's `.oq` and `.edge` patterns below.

## Key–value metadata grid

**When:** Session metadata or any label→value pairs (branch, commit, duration, model, scope). Also covers numbered "edge case" and "open question" rows. Lifted from `prototype-spec.html` (`.edge-grid`/`.edge`, `.oq`).

```html
<section id="<id>">
  <div class="sec-label"><NN — metadata></div>
  <h2>Session <em>facts</em></h2>
  <div class="edge-grid">
    <div class="edge"><div class="n"><label></div><div class="t"><value></div><p><note></p></div>
    <div class="edge"><div class="n"><label></div><div class="t"><value></div><p><note></p></div>
  </div>
  <!-- numbered open-question rows -->
  <div class="oq"><span class="q">1</span><div><An open question or follow-up, with <strong>emphasis</strong>.></div></div>
  <div class="oq"><span class="q">2</span><div><Another.></div></div>
</section>
```

```css
.edge-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:.7rem;margin-top:1rem;}
.edge{background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:.85rem 1rem;}
.edge .n{font-family:var(--mono);font-size:.62rem;color:var(--accent);}
.edge .t{font-weight:600;margin:.2rem 0;font-size:.88rem;color:var(--tp);}
.edge p{font-size:.78rem;margin:0;color:var(--ts);}
.oq{display:flex;gap:.8rem;align-items:flex-start;background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:.8rem 1.1rem;margin-bottom:.6rem;}
.oq .q{font-family:var(--serif);font-style:italic;color:var(--accent);font-size:1.3rem;line-height:1;}
.oq div{font-size:.86rem;color:var(--ts);}
```

**Wiring:** No handler. Revealed by the IntersectionObserver.

## Annotated code block

**When:** A specific snippet (function, config, command) is worth showing verbatim with a filename header. Self-contained `<pre>` with mono styling. Authored from tokens (the prototype `code`/inline-code patterns extended to a block).

```html
<div class="codeblock">
  <div class="cb-head"><span class="cb-file"><path/to/file.ts></span><span class="cb-lang"><lang></span></div>
  <pre class="cb-body"><code><verbatim code — escape <, > and & as entities></code></pre>
</div>
```

```css
.codeblock{background:var(--bg-card);border:1px solid var(--border);border-radius:10px;overflow:hidden;margin:1.1rem 0;}
.cb-head{display:flex;justify-content:space-between;align-items:center;padding:.5rem .9rem;background:var(--bg-elevated);border-bottom:1px solid var(--border);font-family:var(--mono);font-size:.62rem;text-transform:uppercase;letter-spacing:.08em;}
.cb-file{color:var(--accent);}
.cb-lang{color:var(--tm);}
.cb-body{margin:0;padding:.9rem 1.1rem;font-family:var(--mono);font-size:.78rem;line-height:1.65;color:var(--ts);white-space:pre;overflow-x:auto;}
.cb-body code{color:var(--tp);}
```

**Wiring:** No handler. Revealed by the IntersectionObserver. Keep content escaped so the page stays self-contained and valid.

## Concept / mind map

**When:** A central idea branches into related sub-concepts (a topic explored, a feature and its facets). Radial inline SVG (self-contained) with a centre node and labelled spokes.

```html
<section id="<id>">
  <div class="sec-label"><NN — concept map></div>
  <h2>The <em>shape</em> of it</h2>
  <div class="mindmap">
    <svg viewBox="0 0 600 320" role="img" aria-label="<concept map description>">
      <g class="mm-edge"><line x1="300" y1="160" x2="120" y2="70"/><line x1="300" y1="160" x2="480" y2="70"/><line x1="300" y1="160" x2="120" y2="250"/><line x1="300" y1="160" x2="480" y2="250"/></g>
      <g class="mm-node center"><circle cx="300" cy="160" r="46"/><text x="300" y="164" text-anchor="middle"><core></text></g>
      <g class="mm-node"><rect x="40" y="48" width="160" height="40" rx="20"/><text x="120" y="73" text-anchor="middle"><branch A></text></g>
      <g class="mm-node"><rect x="400" y="48" width="160" height="40" rx="20"/><text x="480" y="73" text-anchor="middle"><branch B></text></g>
      <g class="mm-node"><rect x="40" y="230" width="160" height="40" rx="20"/><text x="120" y="255" text-anchor="middle"><branch C></text></g>
      <g class="mm-node"><rect x="400" y="230" width="160" height="40" rx="20"/><text x="480" y="255" text-anchor="middle"><branch D></text></g>
    </svg>
  </div>
</section>
```

```css
.mindmap{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.5rem;margin:1.2rem 0;overflow-x:auto;}
.mindmap svg{display:block;min-width:560px;max-width:100%;height:auto;}
.mm-edge line{stroke:var(--border-strong);stroke-width:1.5;}
.mm-node rect{fill:var(--bg-elevated);stroke:var(--border);transition:all .3s var(--ease);}
.mm-node:hover rect{stroke:var(--accent);}
.mm-node.center circle{fill:color-mix(in srgb,var(--bg-elevated),var(--accent-soft));stroke:var(--accent);}
.mm-node text{font-family:var(--mono);font-size:11px;fill:var(--tp);}
.mm-node.center text{fill:var(--accent);}
```

**Wiring:** No handler (CSS hover glow). Revealed by the IntersectionObserver. Hand-place nodes; one `<line>` per spoke from the centre.

## Legend

**When:** A document uses colour/symbol coding (status colours, category swatches) that needs a key. A compact swatch row — reuses the palette/specimen pattern from `seed.html`/`prototype-spec.html`.

```html
<div class="legend">
  <span class="lg"><i style="background:var(--green)"></i><label · e.g. added></span>
  <span class="lg"><i style="background:var(--rose)"></i><label · removed></span>
  <span class="lg"><i style="background:var(--amber)"></i><label · changed></span>
  <span class="lg"><i style="background:var(--purple)"></i><label · deferred></span>
</div>
```

```css
.legend{display:flex;gap:.6rem;flex-wrap:wrap;margin:1rem 0;}
.lg{font-family:var(--mono);font-size:.6rem;color:var(--tp);padding:.5rem .7rem;border-radius:8px;border:1px solid var(--border);display:flex;align-items:center;gap:.5rem;background:var(--bg-card);}
.lg i{width:14px;height:14px;border-radius:4px;display:inline-block;}
```

**Wiring:** No handler. Place near the component it explains; revealed with its section. The font-specimen variant (`.specimen`/`.spec-card`) from `prototype-spec.html` is a sibling for "fonts used" legends.

## Composing beyond the catalog — see `authoring-guide.md`.
