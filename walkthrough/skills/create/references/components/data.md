# Component Catalog — Data

Components that render the shape of data (not code structure). Tokens-only + self-contained.

## ERD / schema (layered, field-anchored, cycle-aware)

**When:** the session is about a **data model** — entities with fields and relationships carrying
cardinality. Distinct from the architecture map (services, no fields/cardinality). Entities are placed
in **dependency-depth bands** (computed at synthesis, see `authoring-guide.md` § 1 "ERD layering"),
referenced/parent entities on top, the most-dependent (junction) at the bottom. A relationship lives on
its **FK field row** as a clickable `→ Target.field · cardinality`; a **relationship summary** lists
every edge (the lineless, always-visible channel for keyboard/print/no-hover), each entity name in it a
**navigable `openSurface` target** (the row's two `.e` endpoints, not the row itself). On hover/focus of a FK
row, the shared JS (`interactivity.md`) draws **one** connector — up to a parent (accent), a self-loop
(purple), or down to a broken back-edge (rose, dashed); cleared on blur. No standing overlay.

**Edge taxonomy — mark, never drop:**

| Kind | FK-row ref | Drawn on hover |
|---|---|---|
| forward FK | `.ref` (amber) `→ T.id · N:1` | accent line up into parent |
| self-reference | `.ref.self` (purple) `↺ self → T.id` | purple self-loop |
| back-edge (cycle) | `.ref.cyc` (rose) `↩ T.id · N:1` | dashed rose line down |

A **composite / multi-column FK** is one relationship: represent it as a single ref `→ Target(a, b)` on one
field row → **one** connector — never one row or one line per column.

```html
<section id="<id>">
  <div class="sec-label"><data model></div>
  <h2>The <em>schema</em></h2>
  <div class="erd-l">
    <svg class="erd-wires"></svg>
    <div class="band">
      <div class="band-label"><span class="dot"></span>referenced</div>
      <div class="band-row">
        <div class="ent" data-ent="user" role="button" tabindex="0" aria-label="User entity" onclick="openSurface('user')">
          <div class="ent-name"><User><span class="deg">2 in</span></div>
          <div class="fld"><span class="col">id</span><span class="chip info">PK</span></div>
          <div class="fld"><span class="col">email</span><span class="type">text</span></div>
        </div>
      </div>
    </div>
    <div class="band">
      <div class="band-label"><span class="dot"></span>core</div>
      <div class="band-row">
        <div class="ent" data-ent="order" role="button" tabindex="0" aria-label="Order entity" onclick="openSurface('order')">
          <div class="ent-name"><Order></div>
          <div class="fld"><span class="col">id</span><span class="chip info">PK</span></div>
          <div class="fld" data-target="user"><span class="col">user_id</span><span class="ref">→ User.id <span class="card">N:1</span></span></div>
        </div>
      </div>
    </div>
  </div>
  <div class="rels">
    <div class="rels-h">relationships</div>
    <div class="rel"><span class="e" onclick="openSurface('user')">User</span><span class="card">1:N</span><span class="e" onclick="openSurface('order')">Order</span><span class="via">via Order.user_id</span></div>
  </div>
</section>
```

For a **self-reference** the FK row is `<span class="ref self">↺ self → User.id</span>` (targets its own
`data-ent`); for a **broken back-edge** it is `<span class="ref cyc">↩ Team.id <span class="card">N:1</span></span>`
and its `data-target` sits in a *lower* band. Band labels are role names (`referenced`/`core`/`junction`)
or **neutral `Layer 0/1/2`** when a cycle makes roles ambiguous — see `authoring-guide.md`.

```css
.erd-l{position:relative;background:var(--bg-card);border:1px solid var(--border);border-radius:14px;padding:1.4rem;display:flex;flex-direction:column;gap:1.15rem;margin:1.2rem 0;}
.erd-l .erd-wires{position:absolute;inset:0;width:100%;height:100%;overflow:visible;pointer-events:none;z-index:5;}
.band{position:relative;border:1px dashed var(--border);border-radius:12px;background:var(--bg-inset);padding:1.5rem 1rem 1.15rem;}
.band-label{position:absolute;top:-.62rem;left:1rem;font-family:var(--mono);font-size:.58rem;text-transform:uppercase;letter-spacing:.16em;color:var(--tm);background:var(--bg-card);padding:.1rem .55rem;border:1px solid var(--border);border-radius:100px;display:flex;align-items:center;gap:.4rem;}
.band-label .dot{width:5px;height:5px;border-radius:50%;background:var(--accent);}
.band-row{display:flex;justify-content:center;flex-wrap:wrap;gap:1rem;}
.ent{flex:0 0 210px;background:var(--bg-elevated);border:1px solid var(--border);border-radius:10px;overflow:hidden;cursor:pointer;transition:border-color .3s var(--ease),box-shadow .3s var(--ease),opacity .3s var(--ease);position:relative;z-index:1;}
.ent-name{font-family:var(--mono);font-size:.72rem;font-weight:600;color:var(--tp);background:var(--bg-card-hover);padding:.5rem .7rem;border-bottom:1px solid var(--border);display:flex;justify-content:space-between;align-items:center;}
.ent-name .deg{font-weight:400;color:var(--tm);font-size:.56rem;}
.fld{display:flex;align-items:center;justify-content:space-between;gap:.4rem;padding:.42rem .7rem;font-family:var(--mono);font-size:.65rem;color:var(--ts);border-bottom:1px solid var(--border);transition:background .2s var(--ease);}
.fld:last-child{border-bottom:none;}
.fld[data-target]{cursor:pointer;}
.col{color:var(--tp);white-space:nowrap;}
.type{color:var(--tm);}
.ref{font-family:var(--mono);font-size:.58rem;color:var(--amber);background:var(--amber-soft);border:1px solid color-mix(in srgb,var(--amber) 30%,transparent);border-radius:100px;padding:.12rem .45rem;white-space:nowrap;}
.ref .card{color:var(--accent);}
.ref.self{color:var(--purple);background:var(--purple-soft);border-color:color-mix(in srgb,var(--purple) 32%,transparent);}
.ref.cyc{color:var(--rose);background:var(--rose-soft);border-color:color-mix(in srgb,var(--rose) 32%,transparent);}
.rels{margin:1rem 0 0;border-top:1px dashed var(--border);padding-top:1rem;}
.rels-h{font-family:var(--mono);font-size:.6rem;text-transform:uppercase;letter-spacing:.14em;color:var(--tm);margin-bottom:.6rem;}
.rel{display:flex;align-items:center;gap:.5rem;font-family:var(--mono);font-size:.68rem;padding:.3rem .5rem;border-radius:7px;flex-wrap:wrap;}
.rel .e{color:var(--tp);cursor:pointer;transition:color .2s var(--ease);}
.rel .e:hover{color:var(--accent);}
.rel .card{color:var(--accent);border:1px dashed color-mix(in srgb,var(--accent) 40%,transparent);border-radius:100px;padding:.05rem .45rem;font-size:.58rem;}
.rel .via{color:var(--tm);font-size:.62rem;}
.ent.hot{border-color:var(--accent);box-shadow:0 0 0 1px var(--accent),0 0 26px var(--accent-glow);z-index:2;}
.ent.hot.hot-self{border-color:var(--purple);box-shadow:0 0 0 1px var(--purple),0 0 26px color-mix(in srgb,var(--purple) 20%,transparent);}
.ent.hot.hot-cyc{border-color:var(--rose);box-shadow:0 0 0 1px var(--rose),0 0 26px color-mix(in srgb,var(--rose) 20%,transparent);}
.ent.dim{opacity:.36;}
.fld.hotrow{background:var(--accent-soft);}
/* back-compat: pre-1.3.0 flat ERD alias */
.erd{display:flex;align-items:center;flex-wrap:wrap;gap:.6rem;background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.5rem;margin:1.2rem 0;}
.erd-entity{flex:0 1 220px;background:var(--bg-elevated);border:1px solid var(--border);border-radius:10px;overflow:hidden;}
```

**Wiring:** each `.ent` clicks to `openSurface('<data-ent>')` (add a `details{}` entry per entity — the
`openSurface` reference graph must stay acyclic per self-check #14, even when the FK graph cycles). In the
`.rels` summary the **entity-name `.e` spans** are the clickable targets — each `<span class="e"
onclick="openSurface('<entity-id>')">` jumps to that endpoint's entity surface; the row itself carries no
pointer. These summary→entity links are **star links into the same entity surfaces**, never entity→entity,
so they add no navigation cycle and keep the `openSurface` graph acyclic (#14). The `.rel .e` spans are a
deliberate **pointer-only** affordance — they carry no `role="button"`/`tabindex` because every entity they
reach is already keyboard-operable through its `.ent` card (which does carry `role="button"`), so the summary
stays a redundant mouse convenience rather than a second Tab stop. PK =
`.chip info`; FKs are conveyed by the ref chip. `.deg` degree badges (`2 in`, `junction`, `in cycle`)
are omit-empty (hide for trivial degree). No JS in this file — the hover-connector lives in
`interactivity.md`; reveal is the shared IntersectionObserver.

**Hostable in a sheet:** suffix any internal `id=` with the surface id so global ids stay unique
(authoring-guide § 3). `getBoundingClientRect` is container-relative, so hover math is correct at a
sheet's width.
