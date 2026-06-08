# Interactivity — shared JS bundle

This is the shared JS bundle, always inlined into the scaffold's `{{INTERACTIVITY_JS}}` slot. All handlers are guarded so missing elements never throw; all state is namespaced inside this one `<script>`. Unused handlers (e.g. `setTab` when there are no tabs) are harmless no-ops.

### Detail surfaces — `renderSurface` builds the structured DOM; `openSurface` routes via `SURF` to the pane (`openPane`) or a native `<dialog>` (sheet, or the shared `paneDialog` for a pane opened inside a sheet), stacked in the top layer via the shared `_capPush`; `openCard` opens from a card's `data-id`; `openD` is a deprecated alias; native Escape closes the topmost dialog, the manual handler closes the pane only when no dialog is open; backdrop-click closes a dialog

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
// Phase ③ router: pane vs sheet via SURF; sheets and nested panes stack as native <dialog>s in the top layer, capped at MAX_DEPTH (replace-topmost)
const _stack=[]; const MAX_DEPTH=3;
function _capPush(el){if(!el||el.open)return;if(_stack.length>=MAX_DEPTH){const t=_stack.pop();if(t)t.close();}el.showModal();_stack.push(el);}
function openSurface(id){const k=(typeof SURF!=='undefined'&&SURF[id])||'pane';
 if(k==='sheet'){const el=document.getElementById('sheet-'+id);_capPush(el);return;}
 if(_stack.length){const pd=document.getElementById('paneDialog'),d=DET[id],b=document.getElementById('paneDialogBody');
  // nested pane → shared paneDialog: render kicker + body, then stack it. Re-opening swaps content in place (no new depth level; _capPush no-ops on el.open).
  renderSurface(d,b);if(d&&d.k)b.insertAdjacentHTML('afterbegin',`<div class="sf-kicker">${d.k}</div>`);_capPush(pd);}
 else openPane(id);}
// dialog housekeeping: pop on close, close on backdrop click
document.querySelectorAll('dialog.sheet').forEach(dlg=>{
 dlg.addEventListener('close',()=>{const i=_stack.indexOf(dlg);if(i>-1)_stack.splice(i,1);});
 dlg.addEventListener('click',e=>{if(e.target===dlg)dlg.close();});});
function openCard(el){if(!el)return;openPane(el.dataset.id||'');}
function openD(id){openSurface(id);} // deprecated alias
function closeD(){panel.classList.remove('open');}
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!_stack.length)closeD();});
```

Sheets and nested panes rely on the native top layer: `showModal()` stacks each above the last, traps focus in the topmost, and Escape closes them top-down — no hand-rolled focus/stack manager. A pane detail opened from *inside* a sheet can't use the non-modal `.panel` (it would render behind the modal), so it renders via `renderSurface` into the shared `paneDialog` — a narrow right-edge `<dialog class="sheet pane-dialog">` that also stacks in the top layer. `_stack` mirrors the open order; the shared `_capPush` enforces the depth cap (`MAX_DEPTH=3` → replace-topmost: close the top, open the new at the same depth) and the `el.open` no-op guard, so re-opening the same sheet/paneDialog — or a bidirectional `related[]` chip (A↔B) — can't double-push `_stack` and strand a phantom entry. `::backdrop` click closes the dialog it dims (`e.target===dlg`); inner clicks never close it.

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
