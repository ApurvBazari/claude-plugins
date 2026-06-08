# Self-Check -- structural assertions before write

Run this against the assembled HTML BEFORE writing. It is a reasoned check, not a blind grep -- scope
every test to where the rule applies. If any fails, fix the HTML and re-run.

| # | Assert | How to reason about it |
|---|--------|------------------------|
| 1 | Exactly one CSS `@import` and it is the only external URL | Count `@import url(` in the `<style>` block (ignore prose mentions of "@import"). No other `http(s)` URL except that font. |
| 2 | No `<script src>`, `<link rel=stylesheet>`, or `<img>` | None anywhere in the document. |
| 3 | Tokens only -- no raw hex | No `#rrggbb`/`#rgb` outside the two token blocks (`:root`, `[data-theme="light"]`). Ignore the grain data-URI (`%23` is encoded `#`) and anchor hrefs/ids (e.g. `#decisions`). |
| 4 | No non-ASCII inside the `<style>` block | Glyphs like arrows or em-dashes belong in HTML/JS, never CSS -- use CSS escapes (`\2014`). HTML body glyphs are fine. |
| 5 | Nav anchors match section ids (bijection) | Every `{{NAV_LINKS}}` href has a matching `<section id>` and every section has a link. |
| 6 | Every `data-d`/`data-id`/`openD('x')`/`openSurface('x')` target resolves per `SURF` | No dead detail-surface clicks -- a `SURF[x]==='pane'` (or default) target has a `DET[x]` key; a `SURF[x]==='sheet'` target has a `<dialog id="sheet-x">`. Nodes, cards (`data-id`), and `related` chips all resolve. |
| 7 | Every `details{}` entry uses the structured fields, no `body` blob | Source entries carry `{kicker, heading, summary, where[], code[]?, points[]?, related[]?}` -- never a single `body` HTML blob. |
| 8 | Every `DET[id]` record is structured, not blobbed | Compiled records are `{k, h, summary, where, code?, points?, related?}` (`k`=kicker, `h`=heading) -- never a `{b}` blob. |
| 9 | `where` is an array | In each `details{}` entry and `DET[id]` record, `where` is an array of `path:line` strings (rendered as `sf-loc` chips), never a scalar string. |
| 10 | Every sheet-kind id in `SURF` has a `<dialog id="sheet-<id>">` | For each `SURF[id]==='sheet'`, the pre-rendered `<dialog class="sheet" id="sheet-<id>">` exists in `{{SHEETS}}` -- otherwise the sheet branch of `openSurface` opens nothing. |
| 11 | `SURF` covers every `openSurface` target | Every id wired to `openSurface('<id>')` (nodes, cards, `related` chips) has a `SURF[id]` (`'pane'` or `'sheet'`); unclassified targets default to `'pane'`. |
| 12 | Sheet + backdrop CSS is tokens-only | `dialog.sheet` and `dialog.sheet::backdrop` use `var(--...)` / `color-mix` only; the one allowed literal is the `rgba(0,0,0,...)` shadow (matches the existing `.panel`). No raw `#hex` in sheet/backdrop rules. |
| 13 | Component ids are unique across all surfaces | A catalog component hosted inside a sheet has its internal ids surface-suffixed (`xpTabs` -> `xpTabs-rich` inside `sheet-rich`); no element `id` appears in two surfaces. |

Failure on any row -> revise the assembled HTML (or the model, then re-assemble) and re-run before write.
