# Design System — the one look-and-feel

The single invariant of every walkthrough. Components vary; these tokens, fonts, and signature
patterns never do. The `:root` token blocks and base CSS are materialized once in `page-scaffold.md`
— the base-CSS home — and copied verbatim into every generated document's `<style>`; this file
documents what those tokens mean and the signature patterns they compose.

## Fonts (one `@import`, system fallback)

```css
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Instrument+Serif:ital@0;1&family=DM+Sans:wght@300;400;500;600&display=swap');
```
Roles: `--serif` (Instrument Serif) = display headings + italic-accent `<em>`; `--sans` (DM Sans)
= body; `--mono` (JetBrains Mono) = eyebrows, labels, pills, code, trees. Each var ends in a
generic family (`serif`/`sans-serif`/`monospace`) so offline degrades cleanly.

## Tokens — two themes (materialized in `page-scaffold.md`)

Both palettes live once as the `:root` (dark, default) and `html[data-theme="light"]` (warm light)
blocks in `page-scaffold.md` — the base-CSS home. The toggle swaps token sets, not stylesheets, so
components never branch on theme. The token families are identical in shape across both themes:

| Family | Tokens | Role |
|--------|--------|------|
| Surfaces | `--bg-deep`, `--bg-card`, `--bg-card-hover`, `--bg-elevated`, `--bg-inset` | page + card backgrounds (near-black in dark, warm paper in light) |
| Borders | `--border`, `--border-active`, `--border-strong` | resting → hover → emphasis hairlines |
| Text | `--tp`, `--ts`, `--tm`, `--tf` | primary → secondary → muted → faint |
| Palette | `--blue`, `--green`, `--amber`, `--rose`, `--purple` (+ a `-soft` fill each) | semantic status colours |
| Accent | `--accent`, `--accent-glow`, `--accent-soft` | the one signature accent (cyan in dark, terracotta in light) |
| Type + motion | `--mono`, `--serif`, `--sans`, `--ease` | the three families + the shared easing curve |

## Signature patterns (must reproduce — full CSS in `page-scaffold.md`)

- **Eyebrow:** mono, uppercase, `letter-spacing:.18em`, `color:var(--accent)`, 26px accent rule via `::before`.
- **Headings:** `--serif`, weight 400; `<em>` is `font-style:italic;color:var(--accent)`.
- **Active/selected:** `border-color:var(--accent); box-shadow:0 0 0 1px var(--accent),0 8px 32px -8px var(--accent-glow)`.
- **Grain overlay:** `body::after` with the inline data-URI fractal-noise SVG at `opacity:.025` (the exact rule lives in `page-scaffold.md`).
- **Frosted nav:** fixed, `backdrop-filter:blur(20px) saturate(180%)`; 2px scroll-progress bar below it.
- **Motion:** transitions use `var(--ease)`; reveals via IntersectionObserver; width animations use the double-`requestAnimationFrame` reset-then-grow pattern.
- **Section kicker (auto-numbered):** `.sec-label` carries `counter-increment:sec` (reset on `main`);
  `.sec-label::before` prints `counter(sec,decimal-leading-zero) " \2014 "`. Authors write only the
  label text — never a hand-typed number. The hero has no `.sec-label`, so numbering starts at the
  first real section.
- **Sheet (detail modal):** a centered native `<dialog class="sheet">` (`max-width:min(900px,92vw)`, `max-height:86vh`, internal scroll) opened with `showModal()` so it lives in the browser top layer (free focus-trap, top-down Escape, stacking). Its `::backdrop` is a token dim — `color-mix(in srgb,var(--bg-deep) …,transparent)` — plus `backdrop-filter:blur(6px) saturate(140%)`, with the solid dim as the no-`backdrop-filter` fallback; entrance via the `sheetIn` keyframe on `var(--ease)`, disabled under `prefers-reduced-motion`. Tokens only — the backdrop never uses raw hex.
- **Structured detail (`sf-*`):** the glance pane and the sheet render ONE structured-content vocabulary — `sf-h` heading, `sf-summary`, `sf-where`/`sf-loc` location chips, `sf-code` annotated blocks, `sf-points`, `sf-related` chips — built by the shared `renderSurface` for the pane and pre-rendered for the sheet. Omit-empty per field; tokens only.

**Rule:** components reference ONLY these tokens — never raw hex. That is what keeps one look across both themes.

## Chip primitive (status roles)

`.chip` is the canonical small status/label token. A leading dot uses `currentColor`. Five semantic
roles map onto the palette:

| Class | Role | Foreground | Fill |
|-------|------|-----------|------|
| `.chip.ok` | success | `--green` | `--green-soft` |
| `.chip.info` | info | `--blue` | `--blue-soft` |
| `.chip.warn` | warning | `--amber` | `--amber-soft` |
| `.chip.danger` | danger | `--rose` | `--rose-soft` |
| `.chip.neutral` | neutral | `--ts` | `--bg-elevated` |

Use `.chip` for source / tier / status / gate labels. Tokens only — never raw hex.
