# Component Catalog -- Interactive (data-model-driven)

Components that render from an inline JS data model. Both ship their own `{{COMPONENT_JS}}` and obey
tokens-only + self-contained. The home for harness-adapter data dashboards.

## Interactive explorer / state-driven views

**When:** A set of related views the reader switches between -- one selector drives a live diagram
region AND a detail pane from one data model. Generalizes the morphing-mode diagram. Needs a
`{{COMPONENT_JS}}` snippet. For multiple explorers in one doc, suffix the ids and the `VIEWS` object.

```html
<section id="<id>">
  <div class="sec-label"><explorer></div>
  <h2>Interactive <em>explorer</em></h2>
  <div class="xp-tabs" id="xpTabs">
    <button class="xp-tab active" data-v="v1" onclick="setView('v1')"><view 1></button>
    <button class="xp-tab" data-v="v2" onclick="setView('v2')"><view 2></button>
    <button class="xp-tab" data-v="v3" onclick="setView('v3')"><view 3></button>
  </div>
  <div class="xp-stage">
    <div class="xp-diagram" id="xpDiagram"></div>
    <div class="xp-detail" id="xpDetail"></div>
  </div>
</section>
```

```css
.xp-tabs{display:flex;gap:.4rem;flex-wrap:wrap;margin:1.2rem 0 1rem;}
.xp-tab{font-family:var(--mono);font-size:.7rem;color:var(--ts);background:var(--bg-card);border:1px solid var(--border);border-radius:8px;padding:.45rem .9rem;cursor:pointer;transition:all .25s var(--ease);}
.xp-tab:hover{border-color:var(--border-strong);color:var(--tp);}
.xp-tab.active{border-color:var(--accent);color:var(--tp);background:var(--bg-card-hover);box-shadow:0 0 0 1px var(--accent),0 8px 32px -8px var(--accent-glow);}
.xp-stage{display:grid;grid-template-columns:1.3fr 1fr;gap:1rem;}
.xp-diagram,.xp-detail{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.3rem;}
.xp-diagram{display:flex;align-items:center;justify-content:center;flex-wrap:wrap;gap:.5rem;font-family:var(--mono);font-size:.72rem;min-height:120px;}
.xp-detail h4{font-family:var(--serif);font-weight:400;color:var(--accent);margin:0 0 .4rem;font-size:1.1rem;}
.xp-detail p{font-size:.84rem;color:var(--ts);margin:0;}
@media(max-width:780px){.xp-stage{grid-template-columns:1fr;}}
```

**Wiring:** Component-unique -- append this `{{COMPONENT_JS}}` (fill `VIEWS`; diagram/detail values are
token-styled HTML, e.g. `.chip` labels and arrows). The init line renders the first view on load.

```js
// {{COMPONENT_JS}} -- interactive explorer
const VIEWS={
 v1:{diagram:'<span class="chip info"><node A></span> -> <span class="chip ok"><node B></span>',detail:'<h4><View 1></h4><p><what this view shows></p>'},
 v2:{diagram:'<span class="chip info"><node A></span> -> <span class="chip warn"><node C></span>',detail:'<h4><View 2></h4><p><...></p>'},
 v3:{diagram:'<span class="chip neutral"><node X></span>',detail:'<h4><View 3></h4><p><...></p>'}
};
function setView(v){const d=VIEWS[v];if(!d)return;
 document.querySelectorAll('#xpTabs .xp-tab').forEach(b=>b.classList.toggle('active',b.dataset.v===v));
 const dg=document.getElementById('xpDiagram'),dt=document.getElementById('xpDetail');
 if(dg)dg.innerHTML=d.diagram;if(dt)dt.innerHTML=d.detail;}
setView('v1');
```

## Data-driven step timeline

**When:** A staged execution model -- phases run in sequence, each holding steps that run PARALLEL or
SEQUENTIAL, with per-step source pills and optional micro-cycles. Static-rendered from the model (no
runtime JS); steps may be made clickable via the shared `openD` (add a `DET` key + `data-d`/`onclick`).
Source pills and the kind tag use the `.chip` primitive.

```html
<section id="<id>">
  <div class="sec-label"><timeline></div>
  <h2>Execution <em>timeline</em></h2>
  <div class="dt-rail">
    <div class="dt-phase">
      <div class="dt-phase-head"><span class="chip neutral"><phase name></span><span class="dt-kind"><SEQUENTIAL></span></div>
      <div class="dt-steps">
        <div class="dt-step"><div class="dt-step-label"><step></div><span class="chip info"><source></span></div>
      </div>
    </div>
    <div class="dt-phase">
      <div class="dt-phase-head"><span class="chip neutral"><phase name></span><span class="dt-kind parallel">PARALLEL</span></div>
      <div class="dt-steps">
        <div class="dt-step"><div class="dt-step-label"><step></div><span class="chip ok"><source></span>
          <div class="dt-micro"><span><micro 1></span><span><micro 2></span></div></div>
        <div class="dt-step"><div class="dt-step-label"><step></div><span class="chip warn"><source></span></div>
      </div>
    </div>
  </div>
</section>
```

```css
.dt-rail{display:flex;flex-direction:column;gap:.8rem;margin:1.2rem 0;}
.dt-phase{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1rem 1.2rem;}
.dt-phase-head{display:flex;align-items:center;gap:.6rem;margin-bottom:.7rem;}
.dt-kind{font-family:var(--mono);font-size:.55rem;text-transform:uppercase;letter-spacing:.12em;color:var(--tm);}
.dt-kind.parallel{color:var(--accent);}
.dt-steps{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:.6rem;}
.dt-step{background:var(--bg-elevated);border:1px solid var(--border);border-radius:10px;padding:.7rem .85rem;}
.dt-step-label{font-size:.84rem;color:var(--tp);margin-bottom:.4rem;}
.dt-micro{display:flex;flex-wrap:wrap;gap:.3rem;margin-top:.5rem;}
.dt-micro span{font-family:var(--mono);font-size:.58rem;color:var(--ts);background:var(--bg-inset);border:1px solid var(--border);border-radius:6px;padding:.2rem .45rem;}
```

**Wiring:** No required handler (static). Revealed by the IntersectionObserver. To open step detail,
add `data-d="<id>"` + `onclick="openD('<id>')"` to a `.dt-step` and a matching `DET` key.
