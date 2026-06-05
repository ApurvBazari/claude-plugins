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
| 6 | Every `data-d`/`openD('x')` has a `DET[x]` key | No dead detail-panel clicks. |

Failure on any row -> revise the assembled HTML (or the model, then re-assemble) and re-run before write.
