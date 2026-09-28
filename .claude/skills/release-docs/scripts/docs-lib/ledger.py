"""The committed coverage ledger (.github/docs-ledger.json): loading, anchors, dispositions,
and the `intentional` allowances for deliberate historical mentions."""
import json
import os
import re

import repo

LEDGER = ".github/docs-ledger.json"
DISPOSITIONS = ("covered", "not-user-facing", "waived")
INTENTIONAL_KEYS = ("file", "token", "context", "reason")
EMPTY = {"schemaVersion": 1, "entries": {}, "intentional": []}


def load(ctx):
    if not ctx.exists(LEDGER):
        return dict(EMPTY)
    try:
        d = json.loads(ctx.read(LEDGER))
    except ValueError as e:
        raise repo.RepoError("%s is not valid JSON: %s" % (LEDGER, e))
    if not isinstance(d, dict) or d.get("schemaVersion") != 1 \
            or not isinstance(d.get("entries"), dict) or not isinstance(d.get("intentional"), list):
        raise repo.RepoError("%s needs schemaVersion 1, an entries object and an intentional list"
                             % LEDGER)
    for i in d["intentional"]:
        if not isinstance(i, dict) or not all(isinstance(i.get(k), str) and i[k].strip()
                                              for k in INTENTIONAL_KEYS):
            raise repo.RepoError("%s: every intentional entry must be an object whose %s are "
                                 "non-empty strings, got %s"
                                 % (LEDGER, "/".join(INTENTIONAL_KEYS), json.dumps(i)[:120]))
    return d


def slug(heading):
    """GitHub's heading anchor: lowercase, punctuation dropped, spaces to hyphens."""
    s = re.sub(r"[^\w\- ]", "", heading.strip().lower())
    return s.replace(" ", "-")


def anchor_ok(ctx, target):
    """'file#anchor' exists: the file holds id="anchor" (HTML) or a heading with that slug (md).
    A non-string target, or one naming a directory, is simply not found."""
    if not isinstance(target, str) or "#" not in target:
        return False
    rel, anchor = target.split("#", 1)
    if not anchor or not os.path.isfile(ctx.path(rel)):
        return False
    text = ctx.read(rel)
    if rel.endswith(".md"):
        return any(slug(m.group(1)) == anchor
                   for m in re.finditer(r"^#{1,6}\s+(.+?)\s*#*\s*$", text, re.M))
    return re.search(r'\bid="%s"' % re.escape(anchor), text) is not None


def entry_problem(ctx, decl):
    """None when a declaration resolves its changelog entry, else a one-line reason."""
    if not isinstance(decl, dict):
        return "declaration is not an object"
    disp = decl.get("disposition")
    if disp not in DISPOSITIONS:
        return "unknown disposition %r" % disp
    if disp == "covered":
        at = decl.get("at")
        if not at:
            return "covered needs a non-empty at list"
        if not isinstance(at, list) or not all(isinstance(t, str) for t in at):
            return "covered needs `at` to be a list of 'file#anchor' strings"
        bad = [t for t in at if not anchor_ok(ctx, t)]
        return "at target(s) not found: %s" % ", ".join(bad) if bad else None
    if not str(decl.get("reason") or "").strip():
        return "%s needs a reason" % disp
    return None


def intentional(led, rel, token, line):
    """A deliberate mention: same file and token, the entry's context phrase is on this line,
    and a reason is given. Context keeps one allowance from hiding new stale lines."""
    for i in led["intentional"]:
        ctx_phrase = str(i.get("context") or "")
        if i.get("file") == rel and i.get("token") == token and ctx_phrase \
                and ctx_phrase in line and str(i.get("reason") or "").strip():
            return True
    return False
