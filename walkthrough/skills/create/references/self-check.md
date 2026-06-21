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
| 14 | The `openSurface` reference graph is acyclic | Following each detail's `related[]` + hosted-component `openSurface` targets never returns to that detail -- an `A -> B -> A` chain fails the build. |
| 15 | Authored nesting depth is <= 3 | The longest chain of nested `openSurface` opens (sheet -> sheet/pane -> ...) is at most 3; deeper authored chains are flattened at synthesis time (runtime also caps at `MAX_DEPTH=3` via replace-topmost). |
| 16 | `paneDialog` is present when a pane is reachable from a sheet | If any sheet can open a pane-kind detail (a `related[]` or hosted node targeting a `SURF[id]==='pane'` id), the scaffold has the `<dialog class="sheet pane-dialog" id="paneDialog">` + `#paneDialogBody`. |
| 17 | `function openSurface` is defined exactly once | The inlined JS has a single `openSurface` definition (no leftover Phase 2 duplicate); the sheet path lives inside it and `openSheet` is folded into the shared `_capPush`. |
| 18 | Diagram fidelity — no force-fit state machine / message trace | If a flow / architecture / dependency diagram is rendered, its `edges` are acyclic, single-actor, and unlabelled-guard. A graph with a cycle / back-edge / self-loop or guard labels must instead be a **state / transition diagram**; an ordered multi-actor message exchange must be a **sequence / swimlane diagram** — never a box-and-arrow map silently dropping the cycle/guards/lanes. (authoring-guide § 1) |
| 19 | No in-session `path:line` silently dropped | Every code anchor the session provided appears in some rendered `where[]` (`sf-loc`) chip or `code[]` block — or is named in the coverage note with a **content** reason (out-of-scope / redundant), never "not read / unverified." An anchor handed to you in-session is first-class detail, not optional. |
| 20 | The inlined `<script>` parses as valid JS — `DET`/`SURF` string values escape `"` and `\` | Every string value in the `DET` and `SURF` object literals (`k`, `h`, `summary`, each `points[]`, each `where[]`, each `code[].file`/`.snippet`) escapes an embedded double-quote (write `\"`) and backslash (write `\\`); a literal `</script>` is written `<\/script>`. One unescaped `"` ends the string early → a `SyntaxError` that aborts the **entire** `<script>`, leaving every handler (`openSurface`, `tgl`, `setTab`…) undefined so nothing opens on click. Mentally parse each emitted DET/SURF value as JS — author them as if `JSON.stringify`-d. |

Failure on any row -> revise the assembled HTML (or the model, then re-assemble) and re-run before write.

## Ledger + new-component assertions

These extend the table above; reason about each the same way (scope to where it applies, fix and re-run on failure).

- **Ledger cross-reference (when `concepts[]` is present):**
  - every `concepts[].renderedBy` (when non-null) names a component key that actually appears in the
    assembled HTML;
  - every rendered structural component (`.dtree`, `.erd`, `.htree`, `.lstack`, `.ladder`, and the
    existing diagrams) traces back to a `concepts[]` entry;
  - no `concepts[]` entry has `bespoke:true` without a `bespokeReason`.
- **New-component structural checks:**
  - decision-tree guard `<text>` escapes `<`/`>` as `&lt;`/`&gt;`;
  - ERD/causal/tree style blocks contain no raw hex (tokens only) and glyphs use CSS/HTML escapes;
  - any component hosted in a sheet has its internal `id=` suffixed with the surface id.
