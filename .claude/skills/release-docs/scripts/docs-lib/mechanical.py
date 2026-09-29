"""--fix-mechanical: rewrite version badges and landing-card text from plugin.json. The only
edits the detector ever makes; everything else is the model's, under the ledger gate."""
import html

import pages
import surfaces


def _write(ctx, rel, text):
    with open(ctx.path(rel), "w", encoding="utf-8", newline="") as f:
        f.write(text)


def fix(ctx):
    surf = surfaces.load(ctx)
    plugins = {p["name"]: p for p in ctx.plugins()}
    changed = []
    for name, p in plugins.items():
        rel = surfaces.page_of(surf, name)
        if not ctx.exists(rel):
            continue
        text = ctx.read(rel)
        new = pages.NAV_BADGE.sub(lambda m: m.group(1) + p["version"], text, count=1)
        new = pages.FOOT_BADGE.sub(lambda m: m.group(1) + p["version"], new, count=1)
        if new != text:
            _write(ctx, rel, new)
            changed.append("%s: badges → v%s" % (rel, p["version"]))
    rel = surf["landing"]
    if ctx.exists(rel):
        text = ctx.read(rel)

        def card(m):
            p = plugins.get(m.group(2))
            if p is None:
                return m.group(0)
            return (m.group(1) + p["version"] + m.group(4)
                    + html.escape(p["description"], quote=False) + m.group(6))

        new = pages.CARD.sub(card, text)
        if new != text:
            _write(ctx, rel, new)
            changed.append("%s: landing cards synced to plugin.json" % rel)
    return changed
