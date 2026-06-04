# Component Catalog — Layout, Prose & Meta

## Hero + stat grid

**When:** Always — the opening section. Eyebrow + serif headline + lede, optional palette strip, and a stat grid summarising the session (counts of files, decisions, stages, etc.).

```html
<section id="top" class="vis" style="padding-top:2.4rem">
  <div class="eyebrow"><eyebrow text · e.g. session walkthrough></div>
  <h1><Headline with an <em>accent</em> word.></h1>
  <p class="lede"><One- or two-sentence summary of what the session was about.></p>
  <div class="hstats">
    <div class="hstat"><div class="v"><em><N></em></div><div class="l"><label></div></div>
    <div class="hstat"><div class="v"><N></div><div class="l"><label></div></div>
    <div class="hstat"><div class="v"><N></div><div class="l"><label></div></div>
    <div class="hstat"><div class="v"><N></div><div class="l"><label></div></div>
  </div>
</section>
```

```css
.eyebrow{font-family:var(--mono);font-size:.68rem;color:var(--accent);text-transform:uppercase;letter-spacing:.18em;display:inline-flex;align-items:center;gap:.6rem;margin-bottom:.8rem;}
.eyebrow::before{content:'';width:26px;height:1px;background:var(--accent);}
h1{font-family:var(--serif);font-size:clamp(2.4rem,6vw,4rem);font-weight:400;line-height:1.04;letter-spacing:-.025em;margin:.2rem 0;max-width:880px;}
h1 em,h2 em{font-style:italic;color:var(--accent);}
.lede{color:var(--ts);font-size:1.08rem;line-height:1.7;max-width:720px;margin:.6rem 0 0;}
.hstats{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:1px;background:var(--border);border:1px solid var(--border);border-radius:12px;overflow:hidden;margin-top:1.8rem;}
.hstat{background:var(--bg-card);padding:1.1rem 1.2rem;}
.hstat .v{font-family:var(--serif);font-size:1.9rem;color:var(--tp);line-height:1;}
.hstat .v em{font-style:italic;color:var(--accent);}
.hstat .l{font-family:var(--mono);font-size:.6rem;color:var(--tm);text-transform:uppercase;letter-spacing:.1em;margin-top:.4rem;}
```

**Wiring:** No click handler. The hero section is revealed by the IntersectionObserver (`.vis`) and feeds the `#prog` scroll bar; start it with `class="vis"` so it paints immediately above the fold.

## Prose section

**When:** Any narrative block — context, summary, rationale, "what happened". The connective tissue between interactive components.

```html
<section id="<id>">
  <div class="sec-label"><section kicker></div>
  <h2><Section heading with an <em>accent</em>.></h2>
  <p class="lede"><Lead sentence.></p>
  <p><Body paragraph. Inline <code>code</code> and <strong>emphasis</strong> are fine.></p>
</section>
```

```css
section{padding:4rem 0 2rem;scroll-margin-top:70px;opacity:0;transform:translateY(24px);transition:opacity .7s var(--ease),transform .7s var(--ease);}
section.vis{opacity:1;transform:none;}
.sec-label{counter-increment:sec;font-family:var(--mono);font-size:.65rem;color:var(--tm);text-transform:uppercase;letter-spacing:.15em;margin-bottom:.5rem;}
.sec-label::before{content:counter(sec,decimal-leading-zero) " \2014 ";}
h2{font-family:var(--serif);font-size:clamp(1.7rem,3.5vw,2.4rem);font-weight:400;line-height:1.15;margin:.2rem 0 .3rem;}
p{font-size:.92rem;color:var(--ts);max-width:720px;}
p code{font-family:var(--mono);font-size:.8rem;background:var(--accent-soft);color:var(--accent);padding:1px 5px;border-radius:4px;}
```

**Wiring:** Reveal-on-scroll via the IntersectionObserver (`.vis`); the section `id` is picked up by nav scrollspy.

## Callouts

**When:** A single point needs emphasis — a caveat, a key insight, a non-obvious constraint. Accent left-border panel. Self-contained below.

```html
<div class="callout"><h4><Callout heading></h4><p><The point, in one or two sentences. Inline <code>code</code> allowed.></p></div>
```

```css
.callout{background:var(--accent-soft);border-left:3px solid var(--accent);border-radius:0 10px 10px 0;padding:.9rem 1.2rem;margin:1.1rem 0;}
.callout h4{font-family:var(--serif);font-weight:400;color:var(--accent);margin:0 0 .3rem;font-size:1.1rem;}
.callout p{margin:0;font-size:.86rem;color:var(--ts);}
.callout code{font-family:var(--mono);font-size:.78rem;background:var(--bg-card);color:var(--accent);padding:1px 5px;border-radius:4px;}
```

**Wiring:** No handler. Sits inline within any section; revealed with its parent section. For a numbered variant (open questions / edge cases), use the Key–value metadata grid's `.oq` and `.edge` patterns below.

## Key–value metadata grid

**When:** Session metadata or any label→value pairs (date, type, scope, model, duration). Also covers numbered "edge case" and "open question" rows. Self-contained below (`.edge-grid`/`.edge`, `.oq`).

```html
<section id="<id>">
  <div class="sec-label"><metadata></div>
  <h2>Session <em>facts</em></h2>
  <div class="edge-grid">
    <div class="edge"><div class="n"><label></div><div class="t"><value></div><p><note></p></div>
    <div class="edge"><div class="n"><label></div><div class="t"><value></div><p><note></p></div>
  </div>
  <!-- numbered open-question rows -->
  <div class="oq"><span class="q">1</span><div><An open question or follow-up, with <strong>emphasis</strong>.></div></div>
  <div class="oq"><span class="q">2</span><div><Another.></div></div>
</section>
```

```css
.edge-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:.7rem;margin-top:1rem;}
.edge{background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:.85rem 1rem;}
.edge .n{font-family:var(--mono);font-size:.62rem;color:var(--accent);}
.edge .t{font-weight:600;margin:.2rem 0;font-size:.88rem;color:var(--tp);}
.edge p{font-size:.78rem;margin:0;color:var(--ts);}
.oq{display:flex;gap:.8rem;align-items:flex-start;background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:.8rem 1.1rem;margin-bottom:.6rem;}
.oq .q{font-family:var(--serif);font-style:italic;color:var(--accent);font-size:1.3rem;line-height:1;}
.oq div{font-size:.86rem;color:var(--ts);}
```

**Wiring:** No handler. Revealed by the IntersectionObserver.

## Annotated code block

**When:** A specific snippet (function, config, command) is worth showing verbatim with a filename header. Self-contained `<pre>` with mono styling. Authored from tokens (the prototype `code`/inline-code patterns extended to a block).

```html
<div class="codeblock">
  <div class="cb-head"><span class="cb-file"><path/to/file.ts></span><span class="cb-lang"><lang></span></div>
  <pre class="cb-body"><code><verbatim code — escape <, > and & as entities></code></pre>
</div>
```

```css
.codeblock{background:var(--bg-card);border:1px solid var(--border);border-radius:10px;overflow:hidden;margin:1.1rem 0;}
.cb-head{display:flex;justify-content:space-between;align-items:center;padding:.5rem .9rem;background:var(--bg-elevated);border-bottom:1px solid var(--border);font-family:var(--mono);font-size:.62rem;text-transform:uppercase;letter-spacing:.08em;}
.cb-file{color:var(--accent);}
.cb-lang{color:var(--tm);}
.cb-body{margin:0;padding:.9rem 1.1rem;font-family:var(--mono);font-size:.78rem;line-height:1.65;color:var(--ts);white-space:pre;overflow-x:auto;}
.cb-body code{color:var(--tp);}
```

**Wiring:** No handler. Revealed by the IntersectionObserver. Keep content escaped so the page stays self-contained and valid.

## Legend

**When:** A document uses colour/symbol coding (status colours, category swatches) that needs a key. A compact swatch row — reuses the palette pattern from `seed.html`.

```html
<div class="legend">
  <span class="lg"><i style="background:var(--green)"></i><label · e.g. added></span>
  <span class="lg"><i style="background:var(--rose)"></i><label · removed></span>
  <span class="lg"><i style="background:var(--amber)"></i><label · changed></span>
  <span class="lg"><i style="background:var(--purple)"></i><label · deferred></span>
</div>
```

```css
.legend{display:flex;gap:.6rem;flex-wrap:wrap;margin:1rem 0;}
.lg{font-family:var(--mono);font-size:.6rem;color:var(--tp);padding:.5rem .7rem;border-radius:8px;border:1px solid var(--border);display:flex;align-items:center;gap:.5rem;background:var(--bg-card);}
.lg i{width:14px;height:14px;border-radius:4px;display:inline-block;}
```

**Wiring:** No handler. Place near the component it explains; revealed with its section.

