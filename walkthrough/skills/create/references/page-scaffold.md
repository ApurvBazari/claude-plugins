# Page Scaffold — the copy-ready empty shell

This is the empty page shell for every walkthrough: the chrome (frosted nav, scroll-progress
bar, grain overlay, theme toggle, detail panel) plus the BASE/CHROME CSS only. The generator
copies this document verbatim, then injects the chosen components' CSS into `{{COMPONENT_CSS}}`,
their markup into `{{HERO}}`/`{{SECTIONS}}`, and their behaviour into `{{COMPONENT_JS}}` — while
the shared bundle goes into `{{INTERACTIVITY_JS}}` and the detail lookup into `{{DETAIL_DATA}}`.

It contains **no component CSS or markup** — that lives in the `components/` catalog. The base CSS below is
lifted verbatim from `seed.html`; never invent base styles.

Slots to fill: `{{TITLE}}`, `{{NAV_LINKS}}`, `{{KICKER}}`, `{{HERO}}`, `{{SECTIONS}}`,
`{{COMPONENT_CSS}}`, `{{INTERACTIVITY_JS}}`, `{{COMPONENT_JS}}`, `{{DETAIL_DATA}}`, `{{SHEETS}}`, `{{SURFACE_MAP}}`.

```html
<!DOCTYPE html><html lang="en" data-theme="dark"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{TITLE}} — walkthrough</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Instrument+Serif:ital@0;1&family=DM+Sans:wght@300;400;500;600&display=swap');
:root{
  --bg-deep:#08090c; --bg-card:#0f1117; --bg-card-hover:#151821; --bg-elevated:#1a1d28; --bg-inset:#060709;
  --border:#1e2230; --border-active:#2d3348; --border-strong:#3a4159;
  --tp:#e8eaf0; --ts:#7d8399; --tm:#4a5068; --tf:#2e3349;
  --blue:#3b82f6; --green:#22c55e; --amber:#f59e0b; --rose:#f43f5e; --purple:#a78bfa;
  --accent:#22d3ee; --accent-glow:rgba(34,211,238,.16); --accent-soft:rgba(34,211,238,.08);
  --blue-soft:rgba(59,130,246,.1); --green-soft:rgba(34,197,94,.1); --amber-soft:rgba(245,158,11,.1); --rose-soft:rgba(244,63,94,.1); --purple-soft:rgba(167,139,250,.1);
  --mono:'JetBrains Mono',monospace; --serif:'Instrument Serif',serif; --sans:'DM Sans',sans-serif;
  --ease:cubic-bezier(.16,1,.3,1);
}
html[data-theme="light"]{
  --bg-deep:#faf8f4; --bg-card:#fff; --bg-card-hover:#f5f1ea; --bg-elevated:#fff; --bg-inset:#f5f1ea;
  --border:#e5dfd6; --border-active:#d8cfc1; --border-strong:#c9c0b3;
  --tp:#2a2520; --ts:#6b6157; --tm:#9e9486; --tf:#c9c0b3;
  --blue:#2d5fa0; --green:#2d7a3a; --amber:#b87333; --rose:#b83a3a; --purple:#7a3b8f;
  --accent:#c05e2b; --accent-glow:rgba(192,94,43,.16); --accent-soft:rgba(192,94,43,.09);
  --blue-soft:rgba(45,95,160,.1); --green-soft:rgba(45,122,58,.1); --amber-soft:rgba(184,115,51,.1); --rose-soft:rgba(184,58,58,.1); --purple-soft:rgba(122,59,143,.1);
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg-deep);color:var(--tp);font-family:var(--sans);line-height:1.65;-webkit-font-smoothing:antialiased;overflow-x:hidden;transition:background .3s,color .3s;}
body::after{content:'';position:fixed;inset:0;z-index:9999;pointer-events:none;opacity:.025;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='200' height='200'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.8' numOctaves='4'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");}
/* nav */
nav{position:fixed;top:0;left:0;right:0;height:54px;z-index:100;backdrop-filter:blur(20px) saturate(180%);background:color-mix(in srgb,var(--bg-deep) 82%,transparent);border-bottom:1px solid var(--border);}
.nav-in{max-width:1180px;margin:0 auto;height:100%;display:flex;align-items:center;justify-content:space-between;padding:0 1.6rem;}
.logo{font-family:var(--mono);font-size:.82rem;font-weight:600;letter-spacing:.02em;}
.logo span{color:var(--accent);}
.nav-links{display:flex;gap:.3rem;font-family:var(--mono);font-size:.68rem;}
.nav-links a{color:var(--ts);text-decoration:none;padding:.3rem .55rem;border-radius:6px;transition:.2s;}
.nav-links a:hover,.nav-links a.on{color:var(--tp);background:var(--accent-soft);}
.nav-meta{display:flex;align-items:center;gap:.45rem;font-family:var(--mono);font-size:.62rem;color:var(--tm);text-transform:uppercase;letter-spacing:.12em;}
.dot{width:7px;height:7px;border-radius:50%;background:var(--green);animation:pulse 2.5s infinite;}
.theme-btn{cursor:pointer;font-family:var(--mono);font-size:.62rem;color:var(--ts);border:1px solid var(--border);padding:.28rem .6rem;border-radius:6px;background:none;}
.progress{position:fixed;top:54px;left:0;height:2px;background:linear-gradient(90deg,var(--accent),var(--blue));z-index:101;width:0;box-shadow:0 0 8px var(--accent-glow);}
main{max-width:1180px;margin:0 auto;padding:0 1.6rem;padding-top:78px;counter-reset:sec;}
.eyebrow{font-family:var(--mono);font-size:.68rem;color:var(--accent);text-transform:uppercase;letter-spacing:.18em;display:inline-flex;align-items:center;gap:.6rem;margin-bottom:.8rem;}
.eyebrow::before{content:'';width:26px;height:1px;background:var(--accent);}
h1{font-family:var(--serif);font-size:clamp(2.4rem,6vw,4rem);font-weight:400;line-height:1.04;letter-spacing:-.025em;margin:.2rem 0;max-width:880px;}
h1 em,h2 em{font-style:italic;color:var(--accent);}
h2{font-family:var(--serif);font-size:clamp(1.7rem,3.5vw,2.4rem);font-weight:400;line-height:1.15;margin:.2rem 0 .3rem;}
.lede{color:var(--ts);font-size:1.08rem;line-height:1.7;max-width:720px;margin:.6rem 0 0;}
p{color:var(--ts);font-size:.92rem;line-height:1.7;max-width:720px;}
p code,li code{font-family:var(--mono);font-size:.8rem;background:var(--accent-soft);color:var(--accent);padding:1px 5px;border-radius:4px;}
section{padding:4rem 0 2rem;scroll-margin-top:70px;opacity:0;transform:translateY(24px);transition:opacity .7s var(--ease),transform .7s var(--ease);}
section.vis{opacity:1;transform:none;}
.sec-label{counter-increment:sec;font-family:var(--mono);font-size:.65rem;color:var(--tm);text-transform:uppercase;letter-spacing:.15em;margin-bottom:.5rem;}
.sec-label::before{content:counter(sec,decimal-leading-zero) " \2014 ";}
/* hero stats */
.hstats{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:1px;background:var(--border);border:1px solid var(--border);border-radius:12px;overflow:hidden;margin-top:1.8rem;}
.hstat{background:var(--bg-card);padding:1.1rem 1.2rem;}
.hstat .v{font-family:var(--serif);font-size:1.9rem;color:var(--tp);line-height:1;}
.hstat .v em{font-style:italic;color:var(--accent);}
.hstat .l{font-family:var(--mono);font-size:.6rem;color:var(--tm);text-transform:uppercase;letter-spacing:.1em;margin-top:.4rem;}
/* detail panel */
.panel{position:fixed;top:0;right:0;width:300px;height:100vh;background:var(--bg-card);border-left:1px solid var(--border-active);padding:24px 20px;overflow:auto;transform:translateX(100%);transition:transform .25s var(--ease);box-shadow:-20px 0 50px rgba(0,0,0,.3);z-index:200;}
.panel.open{transform:none;}
.panel .x{position:absolute;top:14px;right:16px;color:var(--tm);cursor:pointer;font-size:18px;}
.panel .pk{font-family:var(--mono);font-size:.6rem;text-transform:uppercase;letter-spacing:.12em;color:var(--accent);}
.panel h3{font-family:var(--serif);font-weight:400;font-size:1.4rem;margin:.2rem 0 .6rem;}
.panel .pb{font-size:.86rem;color:var(--ts);line-height:1.6;}
.panel code{font-family:var(--mono);font-size:.72rem;background:var(--accent-soft);color:var(--accent);padding:1px 5px;border-radius:4px;}
.panel .sf-h{font-family:var(--serif);font-weight:400;font-size:1.4rem;margin:.2rem 0 .5rem;}
.sf-summary{font-size:.86rem;color:var(--ts);line-height:1.6;margin:0 0 .8rem;}
.sf-where{display:flex;flex-wrap:wrap;gap:.35rem;margin:.2rem 0 .8rem;}
.sf-loc{font-family:var(--mono);font-size:.7rem;background:var(--accent-soft);color:var(--accent);padding:1px 6px;border-radius:4px;}
.sf-code{margin:.2rem 0 .8rem;border:1px solid var(--border);border-radius:8px;overflow:hidden;}
.sf-code figcaption{font-family:var(--mono);font-size:.6rem;color:var(--tm);background:var(--bg-inset);padding:.3rem .6rem;}
.sf-code pre{margin:0;padding:.6rem;overflow:auto;font-family:var(--mono);font-size:.72rem;color:var(--tp);}
.sf-points{margin:.2rem 0 .8rem;padding-left:1.1rem;}
.sf-points li{font-size:.84rem;color:var(--ts);margin:.25rem 0;}
.sf-related{display:flex;flex-wrap:wrap;gap:.35rem;margin-top:.6rem;}
.sf-related .chip{cursor:pointer;border:none;}
dialog.sheet{max-width:min(900px,92vw);width:100%;max-height:86vh;border:1px solid var(--border-active);border-radius:14px;background:var(--bg-card);color:var(--tp);padding:0;overflow:hidden;box-shadow:0 30px 80px -20px rgba(0,0,0,.5);}
dialog.sheet::backdrop{background:color-mix(in srgb,var(--bg-deep) 70%,transparent);backdrop-filter:blur(6px) saturate(140%);}
dialog.sheet>.x{position:absolute;top:12px;right:14px;color:var(--tm);cursor:pointer;font-size:18px;background:none;border:none;z-index:1;}
dialog.sheet .sf-body{padding:26px 24px;overflow:auto;flex:1;min-height:0;}
dialog.sheet .sf-kicker{font-family:var(--mono);font-size:.6rem;text-transform:uppercase;letter-spacing:.12em;color:var(--accent);}
dialog.sheet[open]{display:flex;flex-direction:column;animation:sheetIn .26s var(--ease);}
@keyframes sheetIn{from{opacity:0;transform:translateY(10px) scale(.98)}to{opacity:1;transform:none}}
@media(prefers-reduced-motion:reduce){dialog.sheet[open]{animation:none;}}
dialog.pane-dialog{max-width:min(360px,92vw);margin-right:0;margin-left:auto;height:100vh;max-height:100vh;border-radius:0;}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.35}}
@keyframes fadeUp{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:none}}
@media(max-width:780px){.nav-links{display:none}}
.chip{display:inline-flex;align-items:center;gap:.35rem;font-family:var(--mono);font-size:.6rem;font-weight:500;text-transform:uppercase;letter-spacing:.06em;padding:.2rem .55rem;border-radius:20px;border:1px solid var(--border);background:var(--bg-card);color:var(--ts);}
.chip::before{content:'';width:6px;height:6px;border-radius:50%;background:currentColor;}
.chip.ok{color:var(--green);background:var(--green-soft);border-color:color-mix(in srgb,var(--green) 30%,transparent);}
.chip.info{color:var(--blue);background:var(--blue-soft);border-color:color-mix(in srgb,var(--blue) 30%,transparent);}
.chip.warn{color:var(--amber);background:var(--amber-soft);border-color:color-mix(in srgb,var(--amber) 30%,transparent);}
.chip.danger{color:var(--rose);background:var(--rose-soft);border-color:color-mix(in srgb,var(--rose) 30%,transparent);}
.chip.neutral{color:var(--ts);background:var(--bg-elevated);border-color:var(--border);}
{{COMPONENT_CSS}}
</style></head>
<body>
  <nav><div class="nav-in">
    <div class="logo">◆ walk<span>through</span></div>
    <div class="nav-links">{{NAV_LINKS}}</div>
    <div style="display:flex;align-items:center;gap:.8rem">
      <div class="nav-meta"><span class="dot"></span> {{KICKER}}</div>
      <button class="theme-btn" onclick="tgl()">◑ THEME</button></div>
  </div></nav>
  <div class="progress" id="prog"></div>
  <main>
    <section id="top" class="vis">{{HERO}}</section>
    {{SECTIONS}}
  </main>
  <aside class="panel" id="panel"><span class="x" onclick="closeD()">✕</span>
    <div class="pk" id="panelKicker">Detail</div>
    <div class="pb" id="panelBody"></div></aside>
  <div id="sheets">{{SHEETS}}</div>
  <dialog class="sheet pane-dialog" id="paneDialog"><button class="x" onclick="this.closest('dialog').close()">✕</button><div class="sf-body" id="paneDialogBody"></div></dialog>
  <script>{{INTERACTIVITY_JS}}{{COMPONENT_JS}}{{DETAIL_DATA}}{{SURFACE_MAP}}</script>
</body></html>
```

## Slots

Fill each marker below. Leave a marker empty (delete it) only when its content does not apply.

| Slot | What goes in it |
|------|-----------------|
| `{{TITLE}}` | The session title, plain text (e.g. `SMS parser — HDFC patterns`). The page `<title>` becomes `{{TITLE}} — walkthrough`. |
| `{{NAV_LINKS}}` | **Generated, not hand-written.** Emit one `<a href="#ID">navLabel</a>` per entry in the model's `sections[]`, in order, where `ID` is reused verbatim from that section's own `id`. Mark the first link `class="on"`. Because the href id and the section id share one source, they cannot drift. The self-check verifies the anchor↔id bijection. |
| `{{KICKER}}` | A short mono status line for the nav, uppercase — session metadata only (date, primary type, focus/scope), never repository state (e.g. `SESSION · 2026-06-02` or `BRAINSTORM · AUTH MODEL`). Rendered after the live `.dot`. |
| `{{HERO}}` | The hero block: `<div class="eyebrow">…</div>` + `<h1>…</h1>` + `<p class="lede">…</p>`, optionally followed by a `<div class="hstats">…</div>` of headline numbers. Goes inside the always-visible `#top` section. |
| `{{SECTIONS}}` | One `<section id="…">…</section>` per session-model section after the hero. Each holds a `.sec-label`, an `<h2>`, an optional `.lede`, and the chosen component markup from the `components/` catalog. |
| `{{COMPONENT_CSS}}` | The CSS blocks for **only** the components actually used, copied verbatim from the `components/<group>.md` recipes. Omit CSS for unused components. |
| `{{COMPONENT_JS}}` | The component-specific JS handlers for **only** the components used (e.g. `setTab`, `tog`), copied from the `components/<group>.md` recipes. Omit handlers for unused components. |
| `{{INTERACTIVITY_JS}}` | The full shared behaviour bundle from `interactivity.md` — theme toggle (`tgl`), detail surfaces (`renderSurface` + `openSurface`/`openPane`, with `openD`/`openCard` aliases and `closeD`), scroll progress, and the IntersectionObserver reveal. |
| `{{DETAIL_DATA}}` | The `DET` object literal mapping detail ids to structured `{k,h,summary,where,code,points,related}` records read by `renderSurface`. Include only the ids referenced by the markup; emit an empty `const DET={};` if no detail panel is wired. |
| `{{SHEETS}}` | Pre-rendered sheet dialogs — one `<dialog class="sheet" id="sheet-<id>">` per **sheet-kind** detail (see the Sheet pattern below), placed in the `#sheets` container. Delete the marker when no detail routes to a sheet. |
| `{{SURFACE_MAP}}` | The `const SURF={ "<id>": "pane" \| "sheet", … }` map — every `openSurface` target's kind, read by the router to decide pane vs sheet. Emit `const SURF={};` when no sheets are wired. |

**`details{}` → `DET` transform:** the session model's structured `details{ "<id>": {kicker, heading, summary, where[], code[], points[], related[], surface?, components[]} }` (see `session-model.md`) compiles into the runtime `DET[id] = { k: <kicker>, h: <heading>, summary, where, code, points, related }`. Fields stay structured — arrays are preserved, not folded into a blob — and `renderSurface` builds the DOM from them (`where` → loc chips, `code` → annotated blocks, `points` → bullets, `related` → chips that call `openSurface`). `k` = kicker, `h` = heading. Emit only the ids actually wired.

**`details{}` → `SURF` + `{{SHEETS}}` transform:** compute each detail's kind (explicit `surface`, else inferred — see `authoring-guide.md` § 3). Pane-kind ids go to `DET` (above) with `SURF[id]='pane'`; sheet-kind ids are pre-rendered as `<dialog id="sheet-<id>">` blocks in `{{SHEETS}}` (header via the same `sf-*` markup, hosting each `components[]` ref with surface-suffixed internal ids) with `SURF[id]='sheet'`. `{{SURFACE_MAP}}` emits the whole `const SURF={ … }`; default any unclassified `openSurface` target to `'pane'`.

**Sheet pattern (`{{SHEETS}}`):** the assembler pre-renders one `<dialog>` per sheet-kind detail into the `#sheets` container (the pane builds its DOM at click time via `renderSurface`; the sheet's is static). It reuses the same `sf-*` content vocabulary as the pane so the two surfaces read the same, with surface-appropriate sizing — the sheet heading is an `<h2 class="sf-h">` (it picks up the larger serif `h2` scale, since `.sf-h` itself is pane-scoped), while the pane uses the compact `<h3 class="sf-h">`. The content lives in a `.sf-body` scroll container and the close `✕` is a direct child of the dialog. The sheet's surface-specific CSS — `dialog.sheet`, `::backdrop`, `dialog.sheet>.x` (which absolutely-positions the close button to float above the scroll), and `dialog.sheet .sf-kicker` — is part of the base CSS lifted verbatim from `seed.html`.

```html
<dialog class="sheet" id="sheet-<id>">
  <button class="x" onclick="this.closest('dialog').close()">✕</button>
  <div class="sf-body">
    <div class="sf-kicker"><kicker></div>
    <h2 class="sf-h"><heading></h2>
    <p class="sf-summary"><summary></p>
    <!-- where chips, code blocks, hosted components (id-suffixed), points, related chips -->
  </div>
</dialog>
```

**Rule:** copy the base CSS in the `<style>` block verbatim from `seed.html` — never invent base
styles. Component CSS comes from the `components/` catalog and is injected at `{{COMPONENT_CSS}}` only.
