"""recheck-line (D17): tooling lines that mention a changed path or an added/removed dependency.

Keys in rank order: 1 path (a resolved mention of a changed path, or a unique source basename,
D28), 2 the dependency's exact name, 3 its stem. One item per line; ranked; capped.
"""
import mentions
import paths
from tables import GENERIC_STEMS, RECHECK_CAP

_RANK = {"path": 1, "name": 2, "stem": 3}


def stem(name):
    """Drop an @scope/ prefix and a .js / -js suffix; None when that adds no new key."""
    s = name.split("/", 1)[1] if name.startswith("@") and "/" in name else name
    for suffix in (".js", "-js"):
        if s.lower().endswith(suffix):
            s = s[:-len(suffix)]
            break
    if s.lower() == name.lower() or len(s) < 4 or s.lower() in GENERIC_STEMS:
        return None
    return s


def recheck_items(ctx, dep_names, excluded_refs):
    """(items kept after the cap, count dropped by the cap)."""
    by_basename = sorted(paths.unique_basename_keys(ctx.changes, ctx.base_files,
                                                    ctx.now_files).items())
    basename_rx = [(paths.basename_regex(b), changed) for b, changed in by_basename]
    name_rx = [(n, mentions.dep_regex(n)) for n in sorted(dep_names)]
    stems, stem_rx = set(), []
    for n in sorted(dep_names):
        s = stem(n)
        if s and s.lower() not in stems:
            stems.add(s.lower())
            stem_rx.append((s, mentions.dep_regex(s)))
    order = dict((f, i) for i, f in enumerate(ctx.tooling_files))
    status = {}
    for c in ctx.changes:
        status[c.path] = c.status
        if c.old:
            status[c.old] = c.status
    path_keys = set(p for p, s in status.items() if s != "M" or paths.is_source(p))
    found = []
    for tl in ctx.tlines:
        if tl.ref in excluded_refs:
            continue
        matched = []

        def add(by, value):
            entry = {"by": by, "value": value}
            if entry not in matched:
                matched.append(entry)

        for _, token in paths.path_mentions(tl.text):
            p = ctx.resolver.resolve(token, tl.file)
            if p is not None and p in path_keys:
                add("path", p)
        for rx, changed in basename_rx:
            if rx.search(tl.text):
                add("path", changed)
        for n, rx in name_rx:
            if rx.search(tl.text):
                add("name", n)
        for s, rx in stem_rx:
            if rx.search(tl.text):
                add("stem", s)
        if matched:
            rank = min(_RANK[m["by"]] for m in matched)
            code = -sum(1 for m in matched if m["by"] == "path" and paths.is_source(m["value"]))
            found.append((rank, code, order.get(tl.file, len(order)), tl.n, tl.ref, matched))
    found.sort(key=lambda f: f[:4])
    items = [{"kind": "recheck-line", "line": ref, "matched": matched, "disposition": "inform"}
             for _, _, _, _, ref, matched in found[:RECHECK_CAP]]
    return items, max(0, len(found) - RECHECK_CAP)
