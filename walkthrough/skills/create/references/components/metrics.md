# Component Catalog — Metrics

## Stat / metric cards

**When:** A handful of headline numbers worth surfacing as a row (added/removed/deferred counts, response sizes, coverage). Top-stripe accent per status. Built in OUR tokens.

```html
<section id="<id>">
  <div class="sec-label"><metrics></div>
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
  <div class="sec-label"><sizes></div>
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

