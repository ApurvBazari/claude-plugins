# Interactivity — shared JS bundle

This is the shared JS bundle, always inlined into the scaffold's `{{INTERACTIVITY_JS}}` slot. All handlers are guarded so missing elements never throw; all state is namespaced inside this one `<script>`. Unused handlers (e.g. `setTab` when there are no tabs) are harmless no-ops.

### Detail panel — `renderSurface` builds a structured detail into the pane; `openSurface` routes (pane-only in Phase ①), `openPane` opens it, `openCard` opens from a card's `data-id`, `openD` is a deprecated alias, Escape closes

```js
// renderSurface — build a structured detail DOM from a DET record into `host`
function renderSurface(d,host){if(!d||!host)return;let h='';
 if(d.h)h+=`<h3 class="sf-h">${d.h}</h3>`;
 if(d.summary)h+=`<p class="sf-summary">${d.summary}</p>`;
 if(d.where&&d.where.length)h+=`<div class="sf-where">${d.where.map(w=>`<code class="sf-loc">${w}</code>`).join('')}</div>`;
 if(d.code&&d.code.length)h+=d.code.map(c=>`<figure class="sf-code"><figcaption>${c.file||''}</figcaption><pre><code>${c.snippet||''}</code></pre></figure>`).join('');
 if(d.points&&d.points.length)h+=`<ul class="sf-points">${d.points.map(p=>`<li>${p}</li>`).join('')}</ul>`;
 if(d.components)h+=d.components;
 if(d.related&&d.related.length)h+=`<div class="sf-related">${d.related.map(r=>`<button class="chip neutral" onclick="openSurface('${r}')">${r}</button>`).join('')}</div>`;
 host.innerHTML=h;}
const panel=document.getElementById('panel');
function openPane(id){const d=DET[id];if(!d)return;
 const k=document.getElementById('panelKicker');if(k)k.textContent=d.k||'Detail';
 renderSurface(d,document.getElementById('panelBody'));panel.classList.add('open');}
// Phase ① router: pane only (sheet branch added in Phase ②)
function openSurface(id){openPane(id);}
function openCard(el){if(!el)return;openPane(el.dataset.id||'');}
function openD(id){openSurface(id);} // deprecated alias
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
