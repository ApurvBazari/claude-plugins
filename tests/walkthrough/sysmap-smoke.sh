#!/usr/bin/env bash
# Static checks on the golden system-map page: the page contract of components/system-map.md and
# self-check rows 24 and 26, executed on a real built page.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
F="$ROOT/tests/walkthrough/fixtures/sysmap-sample.html"
fail(){ echo "FAIL: $1"; exit 1; }
ok(){ echo "ok: $1"; }
[ -s "$F" ] || fail "fixture missing: tests/walkthrough/fixtures/sysmap-sample.html"

# --- self-contained, tokens only, no retired or foreign class ---
if grep -q '<script src' "$F"; then fail "not self-contained: external <script src>"; fi
if grep -q '<img' "$F"; then fail "not self-contained: <img> present"; fi
if grep -qi '<link[^>]*stylesheet' "$F"; then fail "not self-contained: external stylesheet"; fi
if grep -vE 'data:image|feTurbulence' "$F" | grep -vE '^[[:space:]]*--' | grep -Eq '#[0-9a-fA-F]{6}'; then
  fail "raw hex outside the grain SVG and the token definitions: tokens only"
fi
if grep -qE 'class="(archmap|depgraph|flow-node|dg-node)' "$F"; then fail "a retired architecture-map or dependency-graph class is used"; fi
if grep -qE 'class="sm-' "$F"; then fail "the sm- prefix belongs to the state diagram; the system map uses sys-"; fi
ok "self-contained, tokens only, no retired class"

# --- the engine block: once, inserted, sentinels at both ends ---
[ "$(grep -c '<script id="wt-sysmap">' "$F")" -eq 1 ] || fail "a page with a system map carries exactly one engine block"
if grep -q '@@SYSMAP-ENGINE@@' "$F"; then fail "the engine marker is still in the page"; fi
[ "$(grep -cx '/\* walkthrough system-map engine v1 \*/' "$F")" -eq 1 ] || fail "the start sentinel must be in the page exactly once"
[ "$(grep -cx '/\* end walkthrough system-map engine \*/' "$F")" -eq 1 ] || fail "the end sentinel must be in the page exactly once"
ok "one engine block, inserted, with both sentinels"

# --- the page contract, map by map ---
python3 - "$F" <<'PY' || fail "the page contract does not hold (see above)"
import re
import sys
from html.parser import HTMLParser

VOID = {"meta", "link", "br", "hr", "img", "input"}
KINDS = ["actor", "service", "store", "queue", "external"]
CHANGES = ["added", "modified", "deleted"]
MARK = {"added": "+ added", "modified": "~ modified", "deleted": "- deleted"}


class Node:
    def __init__(self, tag, attrs, parent):
        self.tag, self.a, self.kids, self.parent, self.text = tag, dict(attrs), [], parent, ""

    def has(self, c):
        return c in (self.a.get("class") or "").split()

    def walk(self):
        yield self
        for k in self.kids:
            yield from k.walk()

    def find(self, c):
        return [n for n in self.walk() if n is not self and n.has(c)]

    def alltext(self):
        return self.text + "".join(k.alltext() for k in self.kids)

    def up(self, c):
        p = self.parent
        while p is not None and not p.has(c):
            p = p.parent
        return p


class Tree(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("root", [], None)
        self.cur = self.root

    def handle_starttag(self, tag, attrs):
        n = Node(tag, attrs, self.cur)
        self.cur.kids.append(n)
        if tag not in VOID:
            self.cur = n

    def handle_endtag(self, tag):
        c = self.cur
        while c is not self.root and c.tag != tag:
            c = c.parent
        if c is not self.root:
            self.cur = c.parent

    def handle_data(self, data):
        self.cur.text += data


t = Tree()
t.feed(open(sys.argv[1], encoding="utf-8").read())
maps = t.root.find("sysmap")
errs = []


def bad(m, msg):
    errs.append("%s: %s" % (m.a.get("data-graph", "?"), msg))


def read(m):
    boxes = [n for n in m.walk() if "data-id" in n.a and (n.has("sys-node") or n.has("sys-group"))]
    rows = [n for n in m.walk() if n.tag == "li" and n.up("sys-links") is not None]
    return boxes, rows


def own(group, cls):
    """elements of class `cls` in this group's own title strip"""
    head = [k for k in group.kids if k.has("sys-ghead")]
    return head[0].find(cls) if head else []


def inside(box, group):
    p = box.up("sys-group")
    while p is not None:
        if p is group:
            return True
        p = p.up("sys-group")
    return False


if len(maps) < 3:
    errs.append("expected at least 3 system maps on the golden page, found %d" % len(maps))
graphs = {}
for m in maps:
    boxes, rows = read(m)
    ids = [b.a["data-id"] for b in boxes]
    by = dict(zip(ids, boxes))
    graphs[m.a.get("data-graph")] = (boxes, rows)
    if not m.a.get("data-graph"):
        bad(m, "the .sysmap must name its graph in data-graph")
    if len(set(ids)) != len(ids):
        bad(m, "data-id is not unique inside the map")
    for i in ids:
        if not re.fullmatch(r"[A-Za-z0-9_-]+", i):
            bad(m, "data-id %r is not a slug: it is written into onclick and attributes, so letters, digits, - and _ only" % i)
    if len(m.find("sys-stage")) != 1 or len(m.find("sys-wires")) != 1 or len(m.find("sys-bar")) != 1:
        bad(m, "a map needs exactly one .sys-stage, one .sys-wires and one .sys-bar")
    # connections: every end resolves, the summary counts the rows, the text repeats the marks
    summary = [n for n in m.walk() if n.tag == "summary"]
    if not summary or ("(%d)" % len(rows)) not in summary[0].alltext():
        bad(m, "the summary must say connections (%d)" % len(rows))
    for r in rows:
        for end in ("data-from", "data-to"):
            if r.a.get(end) not in by:
                bad(m, "a connection row's %s=%r names no box in this map" % (end, r.a.get(end)))
        if r.a.get("data-flow") not in ("sync", "async"):
            bad(m, "data-flow must be sync or async, got %r" % r.a.get("data-flow"))
        if "data-label" not in r.a:
            bad(m, "a connection row must carry data-label, even when it is empty")
        txt = r.alltext()
        if (r.a.get("data-flow") == "async") != ("(async)" in txt):
            bad(m, "row text and data-flow disagree about async: %r" % txt)
        if ("data-inferred" in r.a) != ("(inferred)" in txt):
            bad(m, "row text and data-inferred disagree: %r" % txt)
    for x in boxes + rows:
        c = x.a.get("data-change")
        if c is not None and c not in CHANGES:
            bad(m, "data-change must be added, modified or deleted, got %r" % c)
        marks = own(x, "sys-mark") if x.has("sys-group") else [k for k in x.kids if k.has("sys-mark")]
        if c and (len(marks) != 1 or marks[0].a.get("data-m") != c or marks[0].alltext() != MARK[c]):
            bad(m, "%s is %s but does not carry the matching .sys-mark" % (x.a.get("data-id") or x.alltext()[:30], c))
        if not c and marks:
            bad(m, "%s carries a .sys-mark with no data-change" % (x.a.get("data-id") or x.alltext()[:30]))
    # boxes: kinds, counts, wiring
    for b in boxes:
        if b.has("sys-node"):
            k = b.a.get("data-kind")
            if k is not None and k not in KINDS:
                bad(m, "%s has an unknown data-kind %r" % (b.a["data-id"], k))
            kind_line = [x for x in b.kids if x.has("sys-kind")]
            if (k is not None or "data-inferred" in b.a) != bool(kind_line):
                bad(m, "%s: a kind line is written exactly when the box has a kind or is inferred" % b.a["data-id"])
            if "data-inferred" in b.a and (not kind_line or "inferred" not in kind_line[0].alltext()):
                bad(m, "%s is inferred but its kind line does not say so" % b.a["data-id"])
            wired = b
        else:
            leaves = [x for x in boxes if x.has("sys-node") and inside(x, b)]
            count = own(b, "sys-count")
            if len(count) != 1 or count[0].alltext() != str(len(leaves)):
                bad(m, "group %s: .sys-count must be its leaf count %d" % (b.a["data-id"], len(leaves)))
            want = len([x for x in boxes if x.a.get("data-change") and inside(x, b)]) + len(
                [r for r in rows if r.a.get("data-change") and r.a.get("data-from") in by and r.a.get("data-to") in by
                 and inside(by[r.a["data-from"]], b) and inside(by[r.a["data-to"]], b)])
            chg = own(b, "sys-chg")
            if want and (len(chg) != 1 or chg[0].alltext() != "%d changed" % want):
                bad(m, "group %s: .sys-chg must read %r" % (b.a["data-id"], "%d changed" % want))
            if not want and chg:
                bad(m, "group %s carries a .sys-chg but holds nothing marked" % b.a["data-id"])
            tog = own(b, "sys-tog")
            if len(tog) != 1 or tog[0].tag != "button" or "role" in tog[0].a or not tog[0].a.get("aria-label"):
                bad(m, "group %s needs one native <button class=sys-tog> with an aria-label and no role" % b.a["data-id"])
            if b.a.get("data-open") not in (None, "true", "false"):
                bad(m, "group %s: data-open must be true or false" % b.a["data-id"])
            label = own(b, "sys-label")
            wired = label[0] if label else b
        four = ("role" in wired.a, "tabindex" in wired.a, "aria-label" in wired.a, "onclick" in wired.a)
        if any(four) and not (wired.a.get("role") == "button" and wired.a.get("tabindex") == "0" and wired.a.get("aria-label") and "openSurface(" in wired.a.get("onclick", "")):
            bad(m, "%s: a wired box carries role=button, tabindex=0, an aria-label and onclick=openSurface together, or none of them" % b.a["data-id"])
    # the key lists exactly what appears, in the documented order
    leaves = [b for b in boxes if b.has("sys-node")]
    want = [k for k in KINDS if any(b.a.get("data-kind") == k for b in leaves)]
    if any(r.a.get("data-flow") == "async" for r in rows):
        want.append("async")
    if any("data-inferred" in x.a for x in boxes + rows):
        want.append("inferred")
    want += [c for c in CHANGES if any(x.a.get("data-change") == c for x in boxes + rows)]
    key = m.find("sys-key")
    got = [i.a.get("data-k") for i in key[0].walk() if i.tag == "i"] if key else []
    if got != want:
        bad(m, "the key lists %s, the map shows %s" % (got, want))

# change marks against the before-graph (self-check row 26)
compared = 0
for m in maps:
    ref = m.a.get("data-compare")
    if not ref:
        continue
    compared += 1
    if ref not in graphs:
        bad(m, "data-compare names %r, which is not a map on this page" % ref)
        continue
    boxes, rows = read(m)
    bboxes, brows = graphs[ref]
    before_ids = {b.a["data-id"] for b in bboxes}
    by = {b.a["data-id"]: b for b in boxes}

    def keys(rs, other):
        pair = lambda r: (r.a.get("data-from"), r.a.get("data-to"))
        many = {p for group in (rs, other) for p in {pair(r) for r in group} if sum(1 for r in group if pair(r) == p) > 1}
        return {(pair(r) + (r.a.get("data-label"),) if pair(r) in many else pair(r)): r for r in rs}

    ak, bk = keys(rows, brows), keys(brows, rows)
    for name, item, was in [(b.a["data-id"], b, b.a["data-id"] in before_ids) for b in boxes] + [("%s -> %s" % k[:2], r, k in bk) for k, r in ak.items()]:
        c = item.a.get("data-change")
        if c == "added" and was:
            bad(m, "%s is marked added but is in the before-graph" % name)
        if c in ("deleted", "modified", None) and not was:
            bad(m, "%s is %s but is not in the before-graph" % (name, c or "unmarked"))
    for gone in sorted(before_ids - set(by)):
        bad(m, "%s is in the before-graph and missing from the after-graph: mark it deleted, do not drop it" % gone)
    for k in bk:
        if k not in ak:
            bad(m, "connection %s -> %s is in the before-graph and missing from the after-graph" % k[:2])
    for r in rows:
        ends = [by[r.a[e]].a.get("data-change") for e in ("data-from", "data-to") if r.a.get(e) in by]
        for c in ("added", "deleted"):
            if c in ends and r.a.get("data-change") != c:
                bad(m, "connection %s -> %s touches a box that is %s, so it must be %s too" % (r.a.get("data-from"), r.a.get("data-to"), c, c))
    for b in boxes:
        g = b.up("sys-group")
        while g is not None:
            gc = g.a.get("data-change")
            if gc in ("added", "deleted") and b.a.get("data-change") != gc:
                bad(m, "%s sits in a group that is %s, so it must be %s too" % (b.a["data-id"], gc, gc))
            g = g.up("sys-group")
if not compared:
    errs.append("the golden page must hold one map with data-compare, so the change-mark rules are exercised")

for e in errs[:12]:
    print("  - " + e)
sys.exit(1 if errs else 0)
PY
ok "page contract and change-mark rules hold on every map"

# --- every script still parses (the engine block included) ---
if command -v node >/dev/null 2>&1; then
  TMP="$(mktemp "${TMPDIR:-/tmp}/sysmapjs.XXXXXX")"
  awk '/<script id="wt-sysmap">$/{f=1;next} f&&/^<\/script>$/{exit} f' "$F" > "$TMP"
  [ -s "$TMP" ] || { rm -f "$TMP"; fail "the engine block is empty"; }
  cp "$TMP" "$TMP.js"
  node --check "$TMP.js" || { rm -f "$TMP" "$TMP.js"; fail "the engine block in the page does not parse"; }
  rm -f "$TMP" "$TMP.js"
else
  echo "  (node absent: skipped node --check)"
fi
echo "PASS: system-map golden page"
