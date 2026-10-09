# Component Catalog — System map

## System map

**When:** the graph is a **system**: services, stores, queues, people, external systems or modules joined
by calls, data flow or imports. It draws fan-out and fan-in, labelled directed wires, sync and async flow,
boundaries nested to any depth, cycles between components, and change marks. It replaces the architecture
map and the dependency graph (both retired in 1.6.0). It is **not** for states one thing moves between
(state / transition diagram), timed messages between actors (sequence diagram), or a straight unmarked
chain (flow diagram).

**How it works:** you write the graph into the page as plain HTML: nested boxes, plus a list of
connections. That HTML is complete on its own and is what a reader sees with JavaScript off. The
system-map engine (`../system-map-engine.js`, inserted by the write stage of
`../../../render/references/render-contract.md`) reads that HTML, places the boxes and draws the wires.
You never write a coordinate.

```html
<section id="<id>">
  <div class="sec-label"><system></div>
  <h2>The <em>system</em></h2>
  <div class="sysmap" data-graph="<graph id>">
    <div class="sys-bar"><button data-act="all">expand all</button><button data-act="none">collapse all</button><button data-act="auto">reset</button></div>
    <div class="sys-stage">
      <svg class="sys-wires" aria-hidden="true"></svg>
      <div class="sys-node" data-id="visitor" data-kind="actor" role="button" tabindex="0" aria-label="<Visitor>" onclick="openSurface('visitor')"><span class="sys-kind">actor</span><span class="sys-label"><Visitor></span><span class="sys-sub"><browser></span></div>
      <div class="sys-group" data-id="svc">
        <div class="sys-ghead"><button class="sys-tog" aria-expanded="true" aria-label="Expand or collapse <Link shortener>"></button><span class="sys-label"><Link shortener></span><span class="sys-count">2</span></div>
        <div class="sys-body">
          <div class="sys-node" data-id="api" data-kind="service" role="button" tabindex="0" aria-label="<Redirect API>" onclick="openSurface('api')"><span class="sys-kind">service</span><span class="sys-label"><Redirect API></span><span class="sys-sub"><Go></span></div>
          <div class="sys-node" data-id="db" data-kind="store"><span class="sys-kind">store</span><span class="sys-label"><Links DB></span><span class="sys-sub"><Postgres></span></div>
        </div>
      </div>
    </div>
    <details class="sys-conn" open><summary>connections (2)</summary>
      <ol class="sys-links">
        <li data-from="visitor" data-to="api" data-label="<GET /abc>" data-flow="sync"><b><Visitor></b> &rarr; <b><Redirect API></b> <i><GET /abc></i></li>
        <li data-from="api" data-to="db" data-label="<read on miss>" data-flow="async"><b><Redirect API></b> &rarr; <b><Links DB></b> <i><read on miss> (async)</i></li>
      </ol>
    </details>
    <div class="sys-key"><span><i data-k="actor"></i>actor</span><span><i data-k="service"></i>service</span><span><i data-k="store"></i>store</span><span><i data-k="async"></i>async</span></div>
  </div>
</section>
```

### Writing the boxes

- **`data-graph` names the graph:** `main` for the top-level `nodes[]` / `edges[]`, the `graphs[]` id
  for a named graph. `update` reads it back to tell the two apart.
- **Nesting is the `parent` relation.** A node that other nodes name as `parent` becomes a `.sys-group`;
  its children go inside its `.sys-body`, in declaration order. Depth is the level: the outer boundary
  is the system, a group inside it is a container, a group inside that holds components.
- **A leaf** is a `.sys-node` with `data-id` and, unless its kind is `component`, `data-kind` plus a
  `.sys-kind` line. Kinds: `service`, `store`, `queue`, `external`, `actor`, `component`. `sub` becomes
  `.sys-sub`; leave the span out when there is none.
- **A group** has a `.sys-ghead` holding the toggle button, the label and a `.sys-count` with the number
  of leaves under it. `open: true` or `open: false` on the node becomes `data-open="true|false"`; leave
  the attribute out to let the engine decide.
- **Clickable only with a detail.** A leaf with a `details{}` entry gets `role="button"`, `tabindex="0"`,
  an `aria-label` and `onclick="openSurface('<id>')"`. A group with one puts those four on its
  `.sys-label`. A box without a detail carries none of them.
- **`data-id` is unique inside one `.sysmap`.** The same id may appear in another map on the page; it
  opens the same detail.
- **An id is a slug:** letters, digits, `-` and `_` only. It is written into attributes and into
  `openSurface('<id>')`, so it must never carry a quote, a space or markup. Turn any other name into a
  slug at synthesis time and keep the readable name in the label.

### Writing the connections

One `<li>` per edge, none left out, in declaration order. `data-from` and `data-to` name boxes in this
map. `data-label` is the label (empty when there is none), `data-flow` is `sync` or `async`. The visible
text repeats it: both labels in `<b>`, the label in `<i>`, with ` (async)` after an async label. An edge
with `where[]` evidence ends with one `<code class="sf-loc">path:line</code>` per anchor. Set
`<summary>connections (N)</summary>` to the row count. This list is the complete record: the engine does
not draw a self-edge or an edge between a group and one of its own descendants, but both stay listed.

### Marks

| Model | On the box | On the connection row | Extra text |
|---|---|---|---|
| `inferred: true` | `data-inferred` | `data-inferred` | kind line ends ` &middot; inferred` (a box with no kind line gets one reading `inferred`); row ends ` (inferred)` |
| `change: added` | `data-change="added"` | `data-change="added"` | `<span class="sys-mark" data-m="added">+ added</span>` |
| `change: modified` | `data-change="modified"` | `data-change="modified"` | `<span class="sys-mark" data-m="modified">~ modified</span>` |
| `change: deleted` | `data-change="deleted"` | `data-change="deleted"` | `<span class="sys-mark" data-m="deleted">- deleted</span>` |

The `.sys-mark` span is the first child of a marked `.sys-node`, sits after the label inside a marked
group's `.sys-ghead`, and ends a marked row. A group that holds marked items also gets
`<span class="sys-chg">N changed</span>` after its `.sys-count`, where N is its marked descendant boxes
plus its marked connections that have both ends inside it. A graph with `compareTo` puts that graph's id
in `data-compare` on its `.sysmap`.

### The key

`.sys-key` lists exactly what appears on this map, in this order: the kinds present (`actor`, `service`,
`store`, `queue`, `external`), then `async` if any connection is async, then `inferred`, then the change
marks present. One `<span><i data-k="<name>"></i><name></span>` each. Leave the whole `.sys-key` out when
the list would be empty.

```css
.sysmap{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.4rem;margin:1.2rem 0;overflow-x:auto;}
.sys-bar{display:none;gap:.4rem;margin:0 0 1rem;}
.sys-bar button{font-family:var(--mono);font-size:.62rem;color:var(--ts);background:var(--bg-elevated);border:1px solid var(--border);border-radius:8px;padding:.3rem .7rem;cursor:pointer;transition:all .25s var(--ease);}
.sys-bar button:hover{border-color:var(--border-strong);color:var(--tp);}
.sys-stage{display:flex;flex-wrap:wrap;gap:.8rem;align-items:flex-start;position:relative;}
.sys-wires{display:none;}
.sys-node{background:var(--bg-elevated);border:1px solid var(--border);border-radius:10px;padding:.5rem .85rem .55rem;font-family:var(--mono);font-size:.7rem;color:var(--tp);line-height:1.35;transition:border-color .3s var(--ease),box-shadow .3s var(--ease),opacity .3s var(--ease);}
.sys-node[role="button"],.sys-ghead .sys-label[role="button"]{cursor:pointer;}
.sys-node[role="button"]:hover,.sys-node:focus-visible{border-color:var(--accent);box-shadow:0 0 0 1px var(--accent),0 8px 32px -8px var(--accent-glow);outline:none;}
.sys-kind{display:block;font-size:.52rem;color:var(--tm);text-transform:uppercase;letter-spacing:.1em;}
.sys-label{display:block;white-space:nowrap;}
.sys-sub{display:block;font-size:.58rem;color:var(--ts);white-space:nowrap;}
.sys-node[data-kind="store"]{border-color:color-mix(in srgb,var(--blue) 30%,transparent);background:linear-gradient(135deg,var(--bg-elevated),var(--blue-soft));}
.sys-node[data-kind="queue"]{border-color:color-mix(in srgb,var(--purple) 30%,transparent);background:linear-gradient(135deg,var(--bg-elevated),var(--purple-soft));}
.sys-node[data-kind="external"]{border-color:var(--border-strong);background:transparent;}
.sys-node[data-kind="actor"]{border-radius:100px;padding-left:1.15rem;padding-right:1.15rem;border-color:color-mix(in srgb,var(--accent) 30%,transparent);background:linear-gradient(135deg,var(--bg-elevated),var(--accent-soft));}
.sys-group{border:1px dashed var(--border-strong);border-radius:12px;background:var(--bg-inset);padding:.55rem .8rem .8rem;transition:border-color .3s var(--ease),background .3s var(--ease);}
.sys-group .sys-group{background:var(--bg-card);}
.sys-group .sys-group .sys-group{background:var(--bg-inset);}
.sys-ghead{display:inline-flex;align-items:center;gap:.45rem;font-family:var(--mono);font-size:.58rem;text-transform:uppercase;letter-spacing:.13em;color:var(--ts);white-space:nowrap;}
.sys-ghead .sys-label{display:inline;}
.sys-tog,.sys-chg{display:none;}
.sys-count,.sys-chg{font-size:.52rem;color:var(--tm);border:1px solid var(--border);border-radius:100px;padding:0 .4rem;letter-spacing:0;}
.sys-chg{color:var(--amber);border-color:color-mix(in srgb,var(--amber) 35%,transparent);}
.sys-body{display:flex;flex-wrap:wrap;gap:.7rem;margin-top:.55rem;}
.sys-node[data-inferred],.sys-group[data-inferred]{border-style:dotted;border-color:var(--border-strong);}
.sys-node[data-change="added"],.sys-group[data-change="added"]{box-shadow:0 0 0 2px var(--green);}
.sys-node[data-change="modified"],.sys-group[data-change="modified"]{box-shadow:0 0 0 2px var(--amber);}
.sys-node[data-change="deleted"],.sys-group[data-change="deleted"]{box-shadow:0 0 0 2px var(--rose);opacity:.6;}
[data-change="deleted"]>.sys-label,[data-change="deleted"]>.sys-ghead>.sys-label{text-decoration:line-through;}
.sys-mark{display:block;font-size:.5rem;text-transform:uppercase;letter-spacing:.1em;white-space:nowrap;}
.sys-ghead .sys-mark,.sys-links .sys-mark{display:inline;}
.sys-mark[data-m="added"]{color:var(--green);}
.sys-mark[data-m="modified"]{color:var(--amber);}
.sys-mark[data-m="deleted"]{color:var(--rose);}
.sys-conn{margin-top:1.1rem;border-top:1px dashed var(--border);padding-top:.9rem;}
.sys-conn summary{font-family:var(--mono);font-size:.6rem;text-transform:uppercase;letter-spacing:.14em;color:var(--tm);cursor:pointer;}
.sys-links{list-style:none;margin:.6rem 0 0;padding:0;columns:3 240px;font-family:var(--mono);font-size:.64rem;color:var(--ts);}
.sys-links li{padding:.14rem .3rem;break-inside:avoid;border-radius:5px;}
.sys-links li.hot{background:var(--accent-soft);}
.sys-links b{color:var(--tp);font-weight:500;}
.sys-links i{font-style:normal;color:var(--tm);}
.sys-links li[data-change="deleted"] b,.sys-links li[data-change="deleted"] i{text-decoration:line-through;}
.sys-links .sf-loc{font-size:.56rem;margin-left:.3rem;}
.sys-key{display:flex;flex-wrap:wrap;gap:.35rem .9rem;margin-top:.9rem;font-family:var(--mono);font-size:.54rem;color:var(--tm);text-transform:uppercase;letter-spacing:.08em;}
.sys-key span{display:inline-flex;align-items:center;gap:.35rem;}
.sys-key i{display:inline-block;width:14px;height:10px;border:1px solid var(--border-strong);border-radius:3px;background:var(--bg-elevated);}
.sys-key i[data-k="store"]{border-color:color-mix(in srgb,var(--blue) 40%,transparent);background:var(--blue-soft);}
.sys-key i[data-k="queue"]{border-color:color-mix(in srgb,var(--purple) 40%,transparent);background:var(--purple-soft);}
.sys-key i[data-k="external"]{background:transparent;}
.sys-key i[data-k="actor"]{border-radius:100px;border-color:color-mix(in srgb,var(--accent) 40%,transparent);background:var(--accent-soft);}
.sys-key i[data-k="inferred"]{border-style:dotted;}
.sys-key i[data-k="added"]{border-color:var(--green);box-shadow:0 0 0 1px var(--green);}
.sys-key i[data-k="modified"]{border-color:var(--amber);box-shadow:0 0 0 1px var(--amber);}
.sys-key i[data-k="deleted"]{border-color:var(--rose);box-shadow:0 0 0 1px var(--rose);}
.sys-key i[data-k="async"]{width:18px;height:0;border:0;border-top:1.5px dashed var(--border-strong);border-radius:0;background:none;}
/* upgraded by the engine: everything below applies only once the engine has turned the map on */
.sysmap.on .sys-bar{display:flex;}
.sysmap.on .sys-stage{display:block;margin:0 auto;}
.sysmap.on .sys-wires{display:block;position:absolute;left:0;top:0;overflow:visible;pointer-events:none;z-index:3;}
.sysmap.on .sys-node{position:absolute;width:max-content;margin:0;}
.sysmap.on .sys-group{position:absolute;padding:0;margin:0;}
.sysmap.on .sys-ghead{position:absolute;left:11px;top:4px;z-index:4;background:inherit;border-radius:6px;padding:2px 4px;}
.sysmap.on .sys-body{display:block;margin:0;}
.sysmap.on .sys-tog{display:inline-flex;align-items:center;justify-content:center;width:15px;height:15px;padding:0;border:1px solid var(--border-strong);border-radius:4px;background:var(--bg-elevated);color:var(--ts);font-family:var(--mono);font-size:.62rem;line-height:1;cursor:pointer;}
.sysmap.on .sys-tog::before{content:"\2212";}
.sysmap.on .sys-tog[aria-expanded="false"]::before{content:"+";}
.sysmap.on .sys-tog:hover,.sysmap.on .sys-tog:focus-visible{border-color:var(--accent);color:var(--accent);outline:none;}
.sysmap.on .sys-group.closed{border-style:solid;border-color:var(--border-active);background:var(--bg-elevated);cursor:pointer;box-shadow:4px 4px 0 -1px var(--bg-card),4px 4px 0 0 var(--border-active);}
.sysmap.on .sys-group.closed:hover{border-color:var(--accent);}
.sysmap.on .sys-group.closed>.sys-ghead{top:7px;color:var(--tp);}
.sysmap.on .sys-group.closed>.sys-ghead .sys-chg{display:inline;}
.sysmap.on .sys-group.closed>.sys-body{display:none;}
.sysmap.anim .sys-node,.sysmap.anim .sys-group{transition:left .4s var(--ease),top .4s var(--ease),width .4s var(--ease),height .4s var(--ease),border-color .3s var(--ease);}
.sysmap.anim .sys-body{animation:sysfade .3s var(--ease) .3s both;}
@keyframes sysfade{from{opacity:0}to{opacity:1}}
.sys-w{fill:none;stroke:var(--border-strong);stroke-width:1.4;transition:stroke .2s,opacity .2s;}
.sys-w.async{stroke-dasharray:5 4;}
.sys-w.inferred{stroke-dasharray:1 5;stroke-linecap:round;}
.sys-w.async.inferred{stroke-dasharray:5 4 1 4;stroke-linecap:round;}
.sys-w.multi{stroke-width:2.3;}
.sys-w.chg-added{stroke:var(--green);}
.sys-w.chg-modified{stroke:var(--amber);}
.sys-w.chg-deleted{stroke:var(--rose);opacity:.6;}
.sys-w.hot{stroke:var(--accent);opacity:1;}
.sys-arr{fill:var(--border-strong);}
.sys-arr-hot{fill:var(--accent);}
.sys-arr-added{fill:var(--green);}
.sys-arr-modified{fill:var(--amber);}
.sys-arr-deleted{fill:var(--rose);}
.sys-wl{font-family:var(--mono);font-size:10px;fill:var(--ts);paint-order:stroke;stroke:var(--bg-card);stroke-width:5px;stroke-linejoin:round;transition:opacity .2s,fill .2s;}
.sys-wl.multi{pointer-events:auto;cursor:pointer;text-decoration:underline;}
.sys-wl.hot{fill:var(--tp);}
.sys-wires.dimmed .sys-w:not(.hot),.sys-wires.dimmed .sys-wl:not(.hot){opacity:.16;}
.sys-node.peer,.sys-group.peer{border-color:var(--accent);}
@media (prefers-reduced-motion:reduce){.sysmap.anim .sys-node,.sysmap.anim .sys-group{transition:none}.sysmap.anim .sys-body{animation:none}}
/* back-compat: the 1.5.0 architecture map and dependency graph, for old markup that update could not upgrade */
.archmap{display:flex;align-items:center;flex-wrap:wrap;gap:.4rem;background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.5rem;margin:1.2rem 0;justify-content:center;}
.flow-node{background:var(--bg-elevated);border:1px solid var(--border);border-radius:10px;padding:.85rem 1.25rem;font-family:var(--mono);font-size:.72rem;color:var(--tp);text-align:center;position:relative;cursor:pointer;min-width:140px;}
.flow-node .node-label{font-size:.6rem;color:var(--tm);text-transform:uppercase;letter-spacing:.1em;margin-bottom:.3rem;display:block;}
.flow-arrow{color:var(--tm);font-size:1.2rem;padding:0 .75rem;opacity:.4;flex-shrink:0;}
.depgraph{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.5rem;margin:1.2rem 0;overflow-x:auto;}
.depgraph svg{display:block;min-width:560px;max-width:100%;height:auto;}
.dg-edge line{stroke:var(--border-strong);stroke-width:1.5;}
.dg-node rect{fill:var(--bg-elevated);stroke:var(--border);}
.dg-node text{font-family:var(--mono);font-size:11px;fill:var(--tp);}
```

**Wiring:** a box with a detail calls `openSurface('<id>')` like every other component (add the matching
`details{}` entry). Everything else is the engine's: it turns the map on, decides which groups start
open (16 visible boxes; `data-open` overrides it), lays out left to right when that fits and top to
bottom when it does not, and lays out again when a group is toggled, the width changes or the fonts
load. It adds no global beyond `WtSysMap`. The toggle and the three bar buttons are native `<button>`s
and carry no `role`. The "N links" label on a merged wire is pointer-only: a click opens the
connections list and marks its rows, and the list itself is always reachable by keyboard.

**If the engine cannot run** (JavaScript off, a damaged engine block, a failed layout check) the reader
keeps the plain view above. Never hide content behind the engine.

**Hostable in a sheet:** yes. The engine waits until the map has a width, so a map inside a closed
sheet is laid out when the sheet opens. `data-id` is not an `id`, so nothing needs a surface suffix.

**No `{{COMPONENT_JS}}`.** The engine is not pasted from this file and is not part of
`interactivity.md`. It goes in the scaffold's `{{SYSMAP_ENGINE}}` slot, once per page, however many
maps the page has.
