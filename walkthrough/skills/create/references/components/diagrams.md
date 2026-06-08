# Component Catalog — Diagrams

## Flow / pipeline diagram

**When:** The session described a linear pipeline or staged process. Horizontal nodes with arrows; click a node for detail in the side panel. Lifted from `seed.html`.

```html
<section id="<id>">
  <div class="sec-label"><flow></div>
  <h2>Animated <em>flow</em> diagram</h2>
  <div class="flow">
    <div class="fnode" data-d="<id1>" onclick="openSurface('<id1>')"><div class="nl"><stage 1></div><Label></div>
    <span class="farr">→</span>
    <div class="fnode accent" data-d="<id2>" onclick="openSurface('<id2>')"><div class="nl"><stage 2></div><Label></div>
    <span class="farr">→</span>
    <div class="fnode" data-d="<id3>" onclick="openSurface('<id3>')"><div class="nl"><stage 3></div><Label></div>
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

**Wiring:** click → `openSurface('<id>')` (reads the structured `DET` store in `interactivity.md` — add a matching `details{}` entry per node, compiled to `DET[id]` = `{k,h,summary,where,…}`). Escape closes the pane; a rich node can route to a sheet instead (kind inference, authoring-guide § 3).

**Hostable in a sheet:** can be embedded in a detail sheet via a detail's `components[]`; suffix its internal ids with the surface id (e.g. `-rich`) so global ids stay unique (authoring-guide § 3).

## Architecture map

**When:** The session described a system with components that connect non-linearly (services, layers, a fan-out). Built in OUR tokens as labelled boxes joined by arrows.

```html
<section id="<id>">
  <div class="sec-label"><architecture></div>
  <h2>Component <em>map</em></h2>
  <div class="archmap">
    <div class="flow-node accent" data-d="<id1>" onclick="openSurface('<id1>')"><span class="node-label"><layer></span><Component A></div>
    <span class="flow-arrow">→</span>
    <div class="flow-node green" data-d="<id2>" onclick="openSurface('<id2>')"><span class="node-label"><layer></span><Component B></div>
    <span class="flow-arrow">→</span>
    <div class="flow-node amber" data-d="<id3>" onclick="openSurface('<id3>')"><span class="node-label"><layer></span><Component C></div>
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

**Wiring:** click → `openSurface('<id>')` (add `DET` keys per node). Reveal via the IntersectionObserver.

**Hostable in a sheet:** can be embedded in a detail sheet via a detail's `components[]`; suffix its internal ids with the surface id (e.g. `-rich`) so global ids stay unique (authoring-guide § 3).

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

## State / transition diagram

**When:** The session described a system of **states** with transitions that are **cyclic** (back-edges, retry loops, self-loops) and/or **guarded** (an edge fires only under a condition). This is the right form whenever a flow/architecture map would have to bend its linear arrows backwards — a connection lifecycle, a parser/protocol FSM, a workflow with retries. Inline SVG (self-contained), token-coloured state boxes, curved `<path>` edges (a `Q`/`C` Bézier draws a back-edge or self-loop a straight `<line>` cannot), and small guard labels on the conditional edges. Clickable states open detail via `openSurface`.

```html
<section id="<id>">
  <div class="sec-label"><state machine></div>
  <h2>The <em>lifecycle</em></h2>
  <div class="statemap">
    <svg viewBox="0 0 660 320" role="img" aria-label="<state diagram description>">
      <defs><marker id="sm-arr" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto"><path class="sm-arrhead" d="M0,0 L8,4 L0,8 z"/></marker></defs>
      <g class="sm-edges">
        <path class="sm-edge" d="M150,70 L250,70" marker-end="url(#sm-arr)"/>
        <path class="sm-edge" d="M350,70 L450,70" marker-end="url(#sm-arr)"/>
        <!-- curved back-edge (the retry loop) -->
        <path class="sm-edge" d="M450,95 Q300,170 250,95" marker-end="url(#sm-arr)"/>
        <!-- self-loop -->
        <path class="sm-edge" d="M300,45 C280,5 360,5 340,45" marker-end="url(#sm-arr)"/>
        <text class="sm-guard" x="300" y="150">[guard]</text>
      </g>
      <g class="sm-node start" role="button" tabindex="0" aria-label="<state 1>" data-d="s1" onclick="openSurface('s1')">
        <rect x="50" y="50" width="100" height="40" rx="8"/><text x="100" y="75" text-anchor="middle"><state 1></text></g>
      <g class="sm-node" role="button" tabindex="0" aria-label="<state 2>" data-d="s2" onclick="openSurface('s2')">
        <rect x="250" y="50" width="100" height="40" rx="8"/><text x="300" y="75" text-anchor="middle"><state 2></text></g>
      <g class="sm-node" role="button" tabindex="0" aria-label="<state 3>" data-d="s3" onclick="openSurface('s3')">
        <rect x="450" y="50" width="100" height="40" rx="8"/><text x="500" y="75" text-anchor="middle"><state 3></text></g>
    </svg>
  </div>
</section>
```

```css
.statemap{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.5rem;margin:1.2rem 0;overflow-x:auto;}
.statemap svg{display:block;min-width:600px;max-width:100%;height:auto;}
.sm-edge{fill:none;stroke:var(--border-strong);stroke-width:1.5;transition:stroke .3s var(--ease);}
.statemap:hover .sm-edge{stroke:var(--accent);}
.sm-arrhead{fill:var(--border-strong);}
.sm-guard{font-family:var(--mono);font-size:10px;fill:var(--ts);text-anchor:middle;}
.sm-node{cursor:pointer;}
.sm-node rect{fill:var(--bg-elevated);stroke:var(--border);transition:all .3s var(--ease);}
.sm-node:hover rect{stroke:var(--accent);}
.sm-node.start rect{stroke:var(--accent);fill:color-mix(in srgb,var(--bg-elevated),var(--accent-soft));}
.sm-node text{font-family:var(--mono);font-size:11px;fill:var(--tp);}
```

**Wiring:** click → `openSurface('<id>')` (add a `details{}` entry per state). Coordinates are placeholders — **lay states out by hand**: one `<path>` per real transition, a `Q`/`C` Bézier for any back-edge or self-loop, and a `.sm-guard` `<text>` near each conditional edge. **Escape `<`/`>` inside SVG `<text>` as `&lt;`/`&gt;`** (e.g. a guard `[attempts &lt; 5]`) so the self-check's ASCII/markup rules hold. Mark the initial state `.start`.

**Hostable in a sheet:** embeddable via a detail's `components[]`; suffix internal ids (the `#sm-arr` marker, any `id=`) with the surface id (e.g. `sm-arr-rich`) so global ids stay unique (authoring-guide § 3).

## Sequence / swimlane diagram

**When:** The session traced an **ordered exchange of messages between two or more actors/participants** over time — a request lifecycle, an auth handshake, a protocol trace. Time flows top-to-bottom; each actor owns a lane; messages bounce between lanes. No linear flow or architecture map captures the lanes + ordering, so this is the right form. Token-styled lane heads over CSS-grid message rows; each message is clickable → `openSurface`. Pairs naturally with the **Stepper / playback** (`files-timeline.md`) to replay the trace.

```html
<section id="<id>">
  <div class="sec-label"><sequence></div>
  <h2>The <em>exchange</em>, in order</h2>
  <div class="seq" style="--lanes:4">
    <div class="seq-heads">
      <div class="seq-head"><actor 1></div>
      <div class="seq-head"><actor 2></div>
      <div class="seq-head"><actor 3></div>
      <div class="seq-head"><actor 4></div>
    </div>
    <div class="seq-rows">
      <div class="seq-row"><button class="seq-msg" style="--c1:1;--c2:3" data-id="m1" onclick="openSurface('m1')"><span class="seq-n">1</span><message 1></button></div>
      <div class="seq-row"><button class="seq-msg rtl" style="--c1:2;--c2:4" data-id="m2" onclick="openSurface('m2')"><span class="seq-n">2</span><message 2></button></div>
      <div class="seq-row"><button class="seq-msg self" style="--c1:2;--c2:3" data-id="m3" onclick="openSurface('m3')"><span class="seq-n">3</span><message 3></button></div>
    </div>
  </div>
</section>
```

```css
.seq{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.25rem 1.5rem;margin:1.2rem 0;overflow-x:auto;}
.seq-heads,.seq-row{display:grid;grid-template-columns:repeat(var(--lanes),minmax(90px,1fr));gap:.4rem;min-width:480px;}
.seq-head{font-family:var(--mono);font-size:.62rem;text-transform:uppercase;letter-spacing:.1em;color:var(--accent);text-align:center;padding:.5rem .4rem;border:1px solid var(--border);border-radius:8px;background:var(--bg-elevated);}
.seq-rows{display:flex;flex-direction:column;gap:.45rem;margin-top:.6rem;}
.seq-msg{grid-column:var(--c1)/var(--c2);display:flex;align-items:center;gap:.45rem;font-family:var(--mono);font-size:.66rem;color:var(--tp);text-align:left;background:var(--bg-elevated);border:1px solid var(--border);border-radius:8px;padding:.4rem .6rem;cursor:pointer;transition:all .3s var(--ease);}
.seq-msg:hover{border-color:var(--accent);box-shadow:0 0 0 1px var(--accent),0 8px 32px -8px var(--accent-glow);}
.seq-msg::after{content:"\2192";margin-left:auto;color:var(--tm);}
.seq-msg.rtl::after{content:"\2190";}
.seq-msg.self::after{content:"\21BA";}
.seq-n{display:inline-flex;align-items:center;justify-content:center;min-width:1.3em;height:1.3em;font-size:.55rem;color:var(--bg-deep);background:var(--accent);border-radius:50%;flex-shrink:0;}
```

**Wiring:** click a message → `openSurface('<id>')` (add a `details{}` entry per message). **Lay lanes out by hand**: `--lanes` = actor count; per message `--c1` = leftmost involved lane number, `--c2` = rightmost lane + 1 (so the bar spans both lanes); add `.rtl` when the message flows right-to-left, `.self` for a within-one-lane message (`--c1:n; --c2:n+1`). The arrow glyph is a CSS escape (`\2192`/`\2190`/`\21BA`) so the style block stays ASCII.

**Hostable in a sheet:** embeddable via a detail's `components[]`; suffix any internal `id=` with the surface id so global ids stay unique (authoring-guide § 3).

