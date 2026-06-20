# Component Catalog — Data

Components that render the shape of data (not code structure). Tokens-only + self-contained.

## ERD / schema

**When:** The session is about a **data model** — entities with fields and relationships carrying
**cardinality** (1:N, N:M). DB schema, a migration, related types/tables. Distinct from the
**architecture map** (services, no fields/cardinality). HTML entity cards (real, accessible field rows)
joined by **cardinality connector chips** — no fragile SVG edges, so uneven card heights never break a
connection. PK/FK use the `.chip` primitive. Clickable entity → `openSurface`.

```html
<section id="<id>">
  <div class="sec-label"><data model></div>
  <h2>The <em>schema</em></h2>
  <div class="erd">
    <div class="erd-entity" data-d="user" onclick="openSurface('user')">
      <div class="erd-name"><User></div>
      <div class="erd-field"><span class="erd-col">id</span><span class="chip info">PK</span></div>
      <div class="erd-field"><span class="erd-col">email</span><span class="erd-type">text</span></div>
    </div>
    <div class="erd-rel"><span class="erd-card">1:N</span></div>
    <div class="erd-entity" data-d="order" onclick="openSurface('order')">
      <div class="erd-name"><Order></div>
      <div class="erd-field"><span class="erd-col">id</span><span class="chip info">PK</span></div>
      <div class="erd-field"><span class="erd-col">user_id</span><span class="chip warn">FK</span></div>
    </div>
  </div>
</section>
```

```css
.erd{display:flex;align-items:center;flex-wrap:wrap;gap:.6rem;background:var(--bg-card);border:1px solid var(--border);border-radius:12px;padding:1.5rem;margin:1.2rem 0;}
.erd-entity{flex:0 1 220px;background:var(--bg-elevated);border:1px solid var(--border);border-radius:10px;overflow:hidden;cursor:pointer;transition:all .3s var(--ease);}
.erd-entity:hover{border-color:var(--accent);box-shadow:0 0 20px var(--accent-glow);}
.erd-name{font-family:var(--mono);font-size:.72rem;font-weight:600;color:var(--tp);background:var(--bg-card-hover);padding:.5rem .7rem;border-bottom:1px solid var(--border);}
.erd-field{display:flex;align-items:center;justify-content:space-between;gap:.5rem;padding:.35rem .7rem;font-family:var(--mono);font-size:.66rem;color:var(--ts);border-bottom:1px solid var(--border);}
.erd-field:last-child{border-bottom:none;}
.erd-col{color:var(--tp);}
.erd-type{color:var(--tm);}
.erd-rel{display:flex;align-items:center;flex-shrink:0;}
.erd-card{font-family:var(--mono);font-size:.6rem;letter-spacing:.08em;color:var(--accent);border:1px dashed color-mix(in srgb,var(--accent) 40%,transparent);border-radius:100px;padding:.2rem .55rem;white-space:nowrap;}
```

**Wiring:** click an entity → `openSurface('<id>')` (add a `details{}` entry per entity — full field
list / notes live there). Place one `.erd-rel` cardinality chip between each related pair; mark keys
with `.chip info` (PK) / `.chip warn` (FK). No JS required (reveal via the shared IntersectionObserver).
Sibling `related[]` cross-links between entities are fine for pane-kind details; if an entity is
sheet-kind, keep the reference graph acyclic (self-check).

**Hostable in a sheet:** suffix any internal `id=` with the surface id so global ids stay unique
(authoring-guide § 3).
