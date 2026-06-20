# Component Catalog — Reasoning

Components that render a line of reasoning (debugging, argument). Tokens-only + self-contained.

## Cause→effect (hypothesis ladder)

**When:** A **debugging / causal investigation** — a symptom, candidate causes each **ruled in or out
by evidence**, converging to a root cause and a fix. Distinct from the **flow** (neutral processing
stages, no evidence semantics). HTML rows + `.chip` status (ruled-in = `ok`, ruled-out = `danger`) +
a root-cause→fix callout. Clickable row → `openSurface` for the full evidence.

```html
<section id="<id>">
  <div class="sec-label"><debugging></div>
  <h2>Why it <em>broke</em></h2>
  <div class="ladder">
    <div class="lad-symptom"><span class="k">symptom</span><the observed failure></div>
    <div class="lad-row" data-d="h1" onclick="openSurface('h1')">
      <span class="chip danger">ruled out</span>
      <div class="lad-body"><div class="lad-cause"><candidate cause 1></div><div class="lad-evi"><the evidence that ruled it out></div></div>
    </div>
    <div class="lad-row ruled-in" data-d="h2" onclick="openSurface('h2')">
      <span class="chip ok">ruled in</span>
      <div class="lad-body"><div class="lad-cause"><the root candidate></div><div class="lad-evi"><the evidence that confirmed it></div></div>
    </div>
    <div class="lad-fix"><span class="k">root cause &rarr; fix</span><div class="t"><the fix></div></div>
  </div>
</section>
```

```css
.ladder{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.3rem 1.4rem;margin:1.2rem 0;}
.lad-symptom{font-family:var(--mono);font-size:.72rem;background:var(--rose-soft);border:1px solid color-mix(in srgb,var(--rose) 40%,transparent);border-radius:9px;padding:.6rem .8rem;color:var(--tp);margin-bottom:.8rem;}
.lad-symptom .k{color:var(--rose);text-transform:uppercase;letter-spacing:.1em;font-size:.58rem;margin-right:.5rem;}
.lad-row{display:flex;gap:.7rem;align-items:flex-start;background:var(--bg-elevated);border:1px solid var(--border);border-radius:9px;padding:.6rem .75rem;margin-bottom:.5rem;cursor:pointer;transition:all .3s var(--ease);}
.lad-row:hover{border-color:var(--accent);box-shadow:0 0 0 1px var(--accent),0 8px 32px -8px var(--accent-glow);}
.lad-row.ruled-in{border-color:color-mix(in srgb,var(--green) 45%,transparent);background:linear-gradient(135deg,var(--bg-elevated),var(--green-soft));}
.lad-body{flex:1;}
.lad-cause{font-size:.82rem;color:var(--tp);margin-bottom:.15rem;}
.lad-evi{font-family:var(--mono);font-size:.62rem;color:var(--ts);}
.lad-fix{margin-top:.75rem;border-left:2px solid var(--accent);background:var(--accent-soft);border-radius:0 9px 9px 0;padding:.6rem .8rem;}
.lad-fix .k{font-family:var(--mono);font-size:.58rem;letter-spacing:.1em;text-transform:uppercase;color:var(--accent);}
.lad-fix .t{font-size:.84rem;color:var(--tp);margin-top:.2rem;}
```

**Wiring:** click a row → `openSurface('<id>')` (add a `details{}` entry per hypothesis — full evidence
lives there). Mark ruled-in rows `.ruled-in` and use `.chip ok`; ruled-out rows use `.chip danger`.
The `&rarr;` in the fix kicker is an HTML entity (it is in body text, not the CSS block).

**Hostable in a sheet:** suffix any internal `id=` with the surface id so global ids stay unique.
