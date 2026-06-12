# Component Catalog — Review (lens)

Three components for `lens` review docs. Tokens only; wire to the shared handlers in
`interactivity.md`. Each `findings[]` id is also a `DET` sheet entry — see `session-model.md` § Review.

## Annotated diff

**When:** `diffHunks[]` is present — show changed hunks with inline finding pins.

```html
<section id="<id>">
  <div class="sec-label">diff</div>
  <h2>The <em>change</em>, annotated</h2>
  <div class="diff">
    <div class="diff-file"><span class="diff-path"><path></span><span class="chip warn">risk: <risk></span></div>
    <div class="diff-hunk">
      <div class="dl ctx"><span class="ln">12</span><span class="tx"> unchanged line</span></div>
      <div class="dl add"><span class="ln">13</span><span class="tx">+ added line</span><button class="pin" onclick="openSurface('F1')" aria-label="finding F1">●</button></div>
      <div class="dl del"><span class="ln">14</span><span class="tx">- removed line</span></div>
    </div>
  </div>
</section>
```

```css
.diff{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;overflow:hidden;margin:1.2rem 0;font-family:var(--mono);font-size:.72rem;}
.diff-file{display:flex;align-items:center;gap:.6rem;padding:.6rem 1rem;background:var(--bg-elevated);border-bottom:1px solid var(--border);}
.diff-path{color:var(--tp);}
.diff-hunk{padding:.4rem 0;}
.dl{display:flex;align-items:center;gap:.6rem;padding:.05rem 1rem;position:relative;}
.dl .ln{color:var(--tm);min-width:2.5rem;text-align:right;user-select:none;}
.dl .tx{color:var(--ts);white-space:pre;overflow-x:auto;}
.dl.add{background:var(--green-soft);} .dl.add .tx{color:var(--tp);}
.dl.del{background:var(--rose-soft);} .dl.del .tx{color:var(--tp);}
.dl .pin{margin-left:auto;width:16px;height:16px;border:none;border-radius:50%;background:var(--accent);color:var(--bg-deep);font-size:.6rem;line-height:1;cursor:pointer;flex-shrink:0;transition:transform .2s var(--ease);}
.dl .pin:hover{transform:scale(1.2);}
```

**Wiring:** pin → `openSurface('<finding-id>')` (the finding's `DET` sheet). Lines with no finding omit the pin.

## Findings list

**When:** `findings[]` is present — severity-ranked, filterable by category.

```html
<section id="<id>">
  <div class="sec-label">findings</div>
  <h2>What the review <em>found</em></h2>
  <div class="iter-delta">2 fixed · 1 new · 3 still-open</div>
  <div class="pills">
    <div class="pill on" data-f="bug" onclick="tog(this)"><span class="s" style="background:var(--rose)"></span>bug</div>
    <div class="pill on" data-f="spec-gap" onclick="tog(this)"><span class="s" style="background:var(--amber)"></span>spec-gap</div>
  </div>
  <div class="cards">
    <div class="tcard" data-cat="bug" style="border-left-color:var(--rose)" onclick="openSurface('F1')">
      <div class="cat"><span class="chip danger">high</span> bug <span class="chip info" data-iter="new">new</span></div>
      <div class="tn">F1 — <claim></div>
      <div class="td"><path:line></div>
    </div>
  </div>
</section>
```

**CSS — none of its own.** This component depends entirely on the `.pills`/`.pill`/`.cards`/`.tcard` block from `files-timeline.md` (Filterable cards). If you are NOT also rendering that component elsewhere in the doc, you MUST still paste its CSS block, or the findings list renders completely unstyled (a silent, visual-only failure). The `.cat` line hosts a severity `.chip`.

The delta subhead needs one rule (tokens only):

```css
.iter-delta{font-family:var(--mono);font-size:.72rem;color:var(--ts);margin:-.4rem 0 1rem;letter-spacing:.04em;}
```

The iteration chip reuses the shared `.chip` primitive with `data-iter` carrying the literal label
(`fixed`/`still-open`/`new`/`possibly-resolved`); roles: `fixed`=ok, `still-open`/`possibly-resolved`=warn,
`new`=info. Omit the chip and the subhead entirely on a first review.

**Wiring:** pills → `tog(this)`; card → `openSurface('<finding-id>')`. Severity chip role per the `severity → chip role` map.

## Adherence panel

**When:** `adherence` is present — spec items + plan steps with met/partial/missing chips.

```html
<section id="<id>">
  <div class="sec-label">adherence</div>
  <h2>Did it build <em>what was asked</em>?</h2>
  <div class="adh">
    <div class="adh-col">
      <div class="adh-h">Spec items <span class="adh-score">7 / 8 met</span></div>
      <div class="adh-row"><span class="chip ok">met</span><span><spec item></span></div>
      <div class="adh-row"><span class="chip warn">partial</span><span><spec item></span></div>
      <div class="adh-row"><span class="chip danger">missing</span><span><spec item></span></div>
    </div>
    <div class="adh-col">
      <div class="adh-h">Plan steps</div>
      <div class="adh-row"><span class="chip ok">followed</span><span><plan step></span></div>
      <div class="adh-row"><span class="chip warn">deviated</span><span><plan step></span></div>
    </div>
  </div>
</section>
```

```css
.adh{display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin:1.2rem 0;}
@media(max-width:640px){.adh{grid-template-columns:1fr;}}
.adh-col{background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1rem 1.2rem;}
.adh-h{font-family:var(--mono);font-size:.7rem;text-transform:uppercase;letter-spacing:.12em;color:var(--ts);margin-bottom:.8rem;display:flex;justify-content:space-between;align-items:center;}
.adh-score{color:var(--accent);letter-spacing:0;}
.adh-row{display:flex;align-items:flex-start;gap:.6rem;padding:.4rem 0;font-size:.84rem;color:var(--tp);border-top:1px solid var(--border);}
.adh-row:first-of-type{border-top:none;}
```

**Wiring:** none (static). Chip roles: met/followed=`ok`, partial/deviated=`warn`, missing=`danger`.
