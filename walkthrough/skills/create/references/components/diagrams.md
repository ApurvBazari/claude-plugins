# Component Catalog — Diagrams

## Flow / pipeline diagram

**When:** The session described a linear pipeline or staged process. Horizontal nodes with arrows; click a node for detail in the side panel. Lifted from `seed.html`.

```html
<section id="<id>">
  <div class="sec-label"><flow></div>
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
  <div class="sec-label"><architecture></div>
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
  <div class="sec-label"><dependencies></div>
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
  <div class="sec-label"><modes></div>
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

## Concept / mind map

**When:** A central idea branches into related sub-concepts (a topic explored, a feature and its facets). Radial inline SVG (self-contained) with a centre node and labelled spokes.

```html
<section id="<id>">
  <div class="sec-label"><concept map></div>
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

