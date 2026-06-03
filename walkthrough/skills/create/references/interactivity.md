# Interactivity — shared JS bundle

This is the shared JS bundle, always inlined into the scaffold's `{{INTERACTIVITY_JS}}` slot. All handlers are guarded so missing elements never throw; all state is namespaced inside this one `<script>`. Unused handlers (e.g. `setTab` when there are no tabs) are harmless no-ops.

### Detail panel — open/close the side panel from flow nodes (`openD` reads the `DET` object) or cards (`openCard` reads `data-t`/`data-desc`), with Escape-to-close

```js
const DET={
 gather:{k:"Stage 1",h:"Gather",b:"Pull the conversation, run git enrichment, read referenced files to verify code locations."},
 synth:{k:"Stage 2",h:"Synthesize",b:"Build the structured <code>session model</code> before any HTML — title, sections, nodes, decisions, files, timeline."},
 select:{k:"Stage 3",h:"Select",b:"Pick the components that fit this session from the shared vocabulary. Empty ones are omitted."},
 assemble:{k:"Stage 4",h:"Assemble",b:"Fill the house-style scaffold + chosen component snippets + inline JS. Everything self-contained."},
 write:{k:"Stage 5",h:"Write",b:"Save to <code>.claude/walkthrough/</code>, gitignore prompt, offer to open."}
};
const panel=document.getElementById('panel');
function openD(id){const d=DET[id];if(!d)return;pk.textContent=d.k;ph.textContent=d.h;pbd.innerHTML=d.b;panel.classList.add('open');}
function openCard(el){if(!el)return;pk.textContent=el.dataset.k||'Detail';ph.textContent=el.dataset.t||'';pbd.innerHTML=el.dataset.desc||'';panel.classList.add('open');}
function closeD(){panel.classList.remove('open');}
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeD();});
```

### Tabs — swap the shown detail and re-grow its tradeoff bars (double-rAF reset-then-grow)

```js
function setTab(app){document.querySelectorAll('.tab').forEach(t=>t.classList.toggle('active',t.dataset.app===app));
 document.querySelectorAll('.detail').forEach(d=>{const on=d.dataset.app===app;d.classList.toggle('show',on);if(on)animate(d);});}
function animate(scope){scope.querySelectorAll('.fil').forEach(f=>{f.style.width='0';requestAnimationFrame(()=>requestAnimationFrame(()=>{f.style.width=f.dataset.w+'%';}));});}
```

### Filter pills — toggle a pill, rebuild the active `data-f` set, hide non-matching cards

```js
function tog(el){el.classList.toggle('on');const set=new Set([...document.querySelectorAll('.pill.on')].map(p=>p.dataset.f));
 document.querySelectorAll('.tcard').forEach(c=>c.classList.toggle('hidden',!set.has(c.dataset.cat)));}
```

### Theme toggle — flip dark/light and persist the choice in `localStorage`, restored on load

```js
function tgl(){const h=document.documentElement;const t=h.getAttribute('data-theme')==='dark'?'light':'dark';h.setAttribute('data-theme',t);try{localStorage.setItem('wt-theme',t);}catch(e){}}
(function(){try{const t=localStorage.getItem('wt-theme');if(t)document.documentElement.setAttribute('data-theme',t);}catch(e){}})();
```

### Reveal + progress — IntersectionObserver (`threshold:.1`) adds `.vis` and re-animates a visible chart; the passive `scroll` handler sets `#prog` width and drives nav scrollspy (`.on`)

```js
// reveal + progress + animate-on-view
const io=new IntersectionObserver(es=>es.forEach(e=>{if(e.isIntersecting){e.target.classList.add('vis');const d=e.target.querySelector('.detail.show');if(d)animate(d);}}),{threshold:.1});
document.querySelectorAll('section').forEach(s=>io.observe(s));
addEventListener('scroll',()=>{const sc=scrollY/(document.body.scrollHeight-innerHeight)*100;if(prog)prog.style.width=sc+'%';
 let cur='';document.querySelectorAll('section[id]').forEach(s=>{if(scrollY>=s.offsetTop-120)cur=s.id;});
 document.querySelectorAll('.nav-links a').forEach(a=>a.classList.toggle('on',a.getAttribute('href')==='#'+cur));},{passive:true});
```

### Initial bar animation — grow the bars of the tab shown on first paint

```js
// initial bar animation for the shown tab
setTimeout(()=>{const d=document.querySelector('.detail.show');if(d)animate(d);},300);
```
