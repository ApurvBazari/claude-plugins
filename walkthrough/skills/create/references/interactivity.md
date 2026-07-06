# Interactivity — shared JS bundle

This is the shared JS bundle, always inlined into the scaffold's `{{INTERACTIVITY_JS}}` slot. Its first act is the progressive-enhancement gate: it adds `html.js` (which reveals the JS-gated interactive state) and then loads the detail store by `JSON.parse`-ing the inert `<script type="application/json" id="wt-data">` island into `DET` and `SURF` — the data is no longer emitted as `const DET={…}`/`const SURF={…}` literals in this script, so a data-parse failure is caught and degrades to empty objects rather than killing the whole bundle. All handlers are guarded so missing elements never throw; all state is namespaced inside this one `<script>`. Unused handlers (e.g. `setTab` when there are no tabs) are harmless no-ops.

### Detail surfaces — `renderSurface` builds the structured DOM; `openSurface` routes via `SURF` to the pane (`openPane`) or a native `<dialog>` (sheet, or the shared `paneDialog` for a pane opened inside a sheet), stacked in the top layer via the shared `_capPush`; `openCard` opens from a card's `data-id`; `openD` is a deprecated alias; native Escape closes the topmost dialog, the manual handler closes the pane only when no dialog is open; backdrop-click closes a dialog

```js
// progressive-enhancement gate + inert-data load (must be first)
document.documentElement.classList.add('js');
const _WT=(()=>{try{return JSON.parse(document.getElementById('wt-data').textContent||'{}');}catch(e){return{};}})();
const DET=_WT.DET||{}, SURF=_WT.SURF||{};
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
// failsafe: if the IO never fires (runtime error, detached observer), reveal everything after 2.5s
setTimeout(()=>document.querySelectorAll('section').forEach(s=>s.classList.add('vis')),2500);
addEventListener('scroll',()=>{const sc=scrollY/(document.body.scrollHeight-innerHeight)*100;if(prog)prog.style.width=sc+'%';
 let cur='';document.querySelectorAll('section[id]').forEach(s=>{if(scrollY>=s.offsetTop-120)cur=s.id;});
 document.querySelectorAll('.nav-links a').forEach(a=>a.classList.toggle('on',a.getAttribute('href')==='#'+cur));},{passive:true});
```

### Initial bar animation — grow the bars of the tab shown on first paint

```js
// initial bar animation for the shown tab
setTimeout(()=>{const d=document.querySelector('.detail.show');if(d)animate(d);},300);
```

### ERD schema wires — hover/focus a FK row draws ONE connector (up=parent/accent, down=back-edge/rose dashed, self=loop/purple), cleared on blur. Container-scoped; no standing overlay ⇒ no resize/theme/print listeners.

```html
<script>
(function(){var NS='http://www.w3.org/2000/svg';function mk(t){return document.createElementNS(NS,t);}
function initErd(box){var svg=box.querySelector('.erd-wires');if(!svg)return;
 function clear(){while(svg.firstChild)svg.removeChild(svg.firstChild);
  box.querySelectorAll('.hot').forEach(function(e){e.classList.remove('hot','hot-self','hot-cyc');});
  box.querySelectorAll('.hotrow').forEach(function(e){e.classList.remove('hotrow');});
  box.querySelectorAll('.dim').forEach(function(e){e.classList.remove('dim');});}
 function stroke(el,c,dash){el.style.fill='none';el.style.stroke=c;el.style.strokeWidth='1.9';el.style.strokeLinecap='round';el.style.strokeLinejoin='round';if(dash)el.style.strokeDasharray='5 4';}
 function draw(row){clear();var name=row.getAttribute('data-target');var card=box.querySelector('.ent[data-ent="'+name+'"]');if(!card)return;var src=row.closest('.ent');
  var B=box.getBoundingClientRect(),r=row.getBoundingClientRect(),sc=src.getBoundingClientRect(),t=card.getBoundingClientRect();
  row.classList.add('hotrow');box.querySelectorAll('.ent').forEach(function(e){if(e!==card&&e!==src)e.classList.add('dim');});
  var reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;var cardTxt=(row.querySelector('.card')||{}).textContent||'';
  var p=mk('path'),sx,sy,tx,ty,color;
  if(card===src){card.classList.add('hot','hot-self');color='var(--purple)';sx=r.right-B.left;sy=(r.top+r.bottom)/2-B.top;
   var cr=sc.right-B.left,ct=sc.top-B.top,cx=(sc.left+sc.right)/2-B.left;
   p.setAttribute('d','M '+sx+' '+sy+' C '+(sx+52)+' '+sy+' '+(cr+34)+' '+(ct+4)+' '+cx+' '+ct);stroke(p,color,false);svg.appendChild(p);
   var hd=mk('path');hd.setAttribute('d','M '+(cx-4.5)+' '+(ct-5)+' L '+cx+' '+ct+' L '+(cx+4.5)+' '+(ct-5));stroke(hd,color,false);svg.appendChild(hd);tx=cx;ty=ct;
  }else{var down=t.top>r.bottom;color=down?'var(--rose)':'var(--accent)';card.classList.add('hot');if(down)card.classList.add('hot-cyc');
   tx=(t.left+t.right)/2-B.left;ty=(down?t.top:t.bottom)-B.top;var scMid=(sc.left+sc.right)/2-B.left;var exitLeft=tx<=scMid;
   sx=(exitLeft?r.left:r.right)-B.left;sy=(r.top+r.bottom)/2-B.top;var reach=Math.min(90,Math.max(34,Math.abs(tx-sx)*0.4));
   p.setAttribute('d','M '+sx+' '+sy+' C '+(sx+(exitLeft?-reach:reach))+' '+sy+' '+tx+' '+((sy+ty)/2)+' '+tx+' '+ty);stroke(p,color,down);svg.appendChild(p);
   var ah=down?-5:5;var h2=mk('path');h2.setAttribute('d','M '+(tx-4.5)+' '+(ty+ah)+' L '+tx+' '+ty+' L '+(tx+4.5)+' '+(ty+ah));stroke(h2,color,false);svg.appendChild(h2);}
  if(cardTxt){var te=mk('text');te.setAttribute('x',(sx+tx)/2);te.setAttribute('y',(sy+ty)/2);te.setAttribute('text-anchor','middle');te.setAttribute('dominant-baseline','middle');te.textContent=cardTxt;te.style.fontFamily='var(--mono)';te.style.fontSize='10px';te.style.fill=color;te.style.paintOrder='stroke';te.style.stroke='var(--bg-inset)';te.style.strokeWidth='4px';svg.appendChild(te);}
  if(!reduce){var len=p.getTotalLength();var wasDash=p.style.strokeDasharray;p.style.strokeDasharray=len;p.style.strokeDashoffset=len;p.getBoundingClientRect();p.style.transition='stroke-dashoffset .34s var(--ease)';p.style.strokeDashoffset=0;if(wasDash&&wasDash.indexOf('5 4')===0){setTimeout(function(){p.style.transition='none';p.style.strokeDasharray='5 4';p.style.strokeDashoffset=0;},360);}}}
 box.querySelectorAll('.fld[data-target]').forEach(function(row){row.setAttribute('tabindex','0');
  row.addEventListener('mouseenter',function(){draw(row);});row.addEventListener('mouseleave',clear);
  row.addEventListener('focus',function(){draw(row);});row.addEventListener('blur',clear);});}
document.querySelectorAll('.erd-l').forEach(initErd);})();
</script>
```

**Why no resize/theme/print listeners:** the connector exists only during an active hover/focus and is
recomputed from live `getBoundingClientRect` each time, so a layout change between hovers is irrelevant —
there is no standing line to keep in sync. This is precisely why the hybrid ERD stays self-contained.
