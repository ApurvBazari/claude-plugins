# Design System — the one look-and-feel

The single invariant of every walkthrough. Components vary; these tokens, fonts, and signature
patterns never do. Paste the `:root` block verbatim into every generated document's `<style>`.

## Fonts (one `@import`, system fallback)

```css
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Instrument+Serif:ital@0;1&family=DM+Sans:wght@300;400;500;600&display=swap');
```
Roles: `--serif` (Instrument Serif) = display headings + italic-accent `<em>`; `--sans` (DM Sans)
= body; `--mono` (JetBrains Mono) = eyebrows, labels, pills, code, trees. Each var ends in a
generic family (`serif`/`sans-serif`/`monospace`) so offline degrades cleanly.

## Tokens — dark (default)

```css
:root{
  --bg-deep:#08090c;--bg-card:#0f1117;--bg-card-hover:#151821;--bg-elevated:#1a1d28;--bg-inset:#060709;
  --border:#1e2230;--border-active:#2d3348;--border-strong:#3a4159;
  --tp:#e8eaf0;--ts:#7d8399;--tm:#4a5068;--tf:#2e3349;
  --blue:#3b82f6;--green:#22c55e;--amber:#f59e0b;--rose:#f43f5e;--purple:#a78bfa;
  --accent:#22d3ee;--accent-glow:rgba(34,211,238,.16);--accent-soft:rgba(34,211,238,.08);
  --blue-soft:rgba(59,130,246,.1);--green-soft:rgba(34,197,94,.1);--amber-soft:rgba(245,158,11,.1);--rose-soft:rgba(244,63,94,.1);--purple-soft:rgba(167,139,250,.1);
  --mono:'JetBrains Mono',monospace;--serif:'Instrument Serif',serif;--sans:'DM Sans',sans-serif;
  --ease:cubic-bezier(.16,1,.3,1);
}
```

## Tokens — warm light (toggle)

```css
html[data-theme="light"]{
  --bg-deep:#faf8f4;--bg-card:#fff;--bg-card-hover:#f5f1ea;--bg-elevated:#fff;--bg-inset:#f5f1ea;
  --border:#e5dfd6;--border-active:#d8cfc1;--border-strong:#c9c0b3;
  --tp:#2a2520;--ts:#6b6157;--tm:#9e9486;--tf:#c9c0b3;
  --blue:#2d5fa0;--green:#2d7a3a;--amber:#b87333;--rose:#b83a3a;--purple:#7a3b8f;
  --accent:#c05e2b;--accent-glow:rgba(192,94,43,.16);--accent-soft:rgba(192,94,43,.09);
  --blue-soft:rgba(45,95,160,.1);--green-soft:rgba(45,122,58,.1);--amber-soft:rgba(184,115,51,.1);--rose-soft:rgba(184,58,58,.1);--purple-soft:rgba(122,59,143,.1);
}
```

## Signature patterns (must reproduce — full CSS in `seed.html`)

- **Eyebrow:** mono, uppercase, `letter-spacing:.18em`, `color:var(--accent)`, 26px accent rule via `::before`.
- **Headings:** `--serif`, weight 400; `<em>` is `font-style:italic;color:var(--accent)`.
- **Active/selected:** `border-color:var(--accent); box-shadow:0 0 0 1px var(--accent),0 8px 32px -8px var(--accent-glow)`.
- **Grain overlay:** `body::after` with the inline data-URI fractal-noise SVG at `opacity:.025` (paste the exact rule from seed.html below).
- **Frosted nav:** fixed, `backdrop-filter:blur(20px) saturate(180%)`; 2px scroll-progress bar below it.
- **Motion:** transitions use `var(--ease)`; reveals via IntersectionObserver; width animations use the double-`requestAnimationFrame` reset-then-grow pattern.

```css
/* grain overlay — copy the exact body::after rule from seed.html */
body::after{content:'';position:fixed;inset:0;z-index:9999;pointer-events:none;opacity:.025;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='200' height='200'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.8' numOctaves='4'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");}
```

**Rule:** components reference ONLY these tokens — never raw hex. That is what keeps one look across both themes.
