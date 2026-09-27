"""Read-only lesson helpers for onboard:maintain: which lessons file a `paths` target uses
(D7, D31) and whether a lesson is already present (D8, mechanical half)."""
import os
import re

from tooling import load, paths_field, read_lines, tooling_files

_STOP_SEGMENTS = frozenset(["apps", "app", "packages", "src"])
_LIST_MARKER = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")


def normalise_globs(globs):
    out = set()
    for g in globs:
        g = g.strip().strip("'\"").strip()
        if g.startswith("./"):
            g = g[2:]
        if g:
            out.add(g)
    return sorted(out)


def slug(globs):
    """`apps/crm/src/lib/**` -> `crm-lib`: last two literal segments of the first glob, minus
    glob segments and apps/app/packages/src; `scoped` when nothing is left."""
    first = normalise_globs(globs)[0]
    segs = [s for s in first.split("/")
            if s and not any(c in s for c in "*?[]{}") and s.lower() not in _STOP_SEGMENTS]
    text = re.sub(r"[^a-z0-9]+", "-", "-".join(segs[-2:]).lower()).strip("-")
    return text[:40].strip("-") or "scoped"


def lesson_file(top, globs):
    """{"file", "exists"}: reuse the lessons-*.md whose paths: set is identical, else a new
    lessons-<slug>.md (suffixed -2, -3... when that name is taken by a different set)."""
    wanted = normalise_globs(globs)
    rules = os.path.join(top, ".claude", "rules")
    if os.path.isdir(rules):
        for name in sorted(os.listdir(rules)):
            if name.startswith("lessons-") and name.endswith(".md"):
                have = paths_field(read_lines(top, ".claude/rules/" + name))
                if have is not None and normalise_globs(have) == wanted:
                    return {"file": ".claude/rules/" + name, "exists": True}
    base = slug(wanted)
    n = 1
    while True:
        name = "lessons-%s.md" % base if n == 1 else "lessons-%s-%d.md" % (base, n)
        if not os.path.exists(os.path.join(rules, name)):
            return {"file": ".claude/rules/" + name, "exists": False}
        n += 1


def normalise_text(text):
    t = _LIST_MARKER.sub("", text).strip().lower()
    t = re.sub(r"\s+", " ", t)
    return t.rstrip(".!;:, ")


def lesson_present(top, now_files, lesson_id, text):
    """{"status": present-id | present-text | absent, "at": file:line or null}."""
    tlines = load(top, tooling_files(top, now_files))
    marker = "<!-- lesson:%s -->" % lesson_id
    for tl in tlines:
        if marker in tl.text:
            return {"status": "present-id", "at": tl.ref}
    want = normalise_text(text)
    for tl in tlines:
        if want and normalise_text(tl.text) == want:
            return {"status": "present-text", "at": tl.ref}
    return {"status": "absent", "at": None}
