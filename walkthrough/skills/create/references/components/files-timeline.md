# Component Catalog — Files & Timeline

## File tree

**When:** The session created, moved, or touched several files and the directory layout matters. `white-space:pre` preserves the drawn tree; file rows can be clickable. Self-contained below.

```html
<section id="<id>">
  <div class="sec-label"><files></div>
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
  <div class="sec-label"><catalog></div>
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

## Timeline

**When:** The session has a chronological story — versions, milestones, an ordered sequence of events. Vertical rail with dots; the current item highlights. Built in OUR tokens.

```html
<section id="<id>">
  <div class="sec-label"><timeline></div>
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
  <div class="sec-label"><playback></div>
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

