""".github/docs-surfaces.json: which files are doc surfaces, the page map, OG strings, retired
identifiers. It lives outside .claude/ because the unattended CI model must be able to write it."""
import json
import re
import subprocess

import repo

SURFACES = ".github/docs-surfaces.json"
LEDGER = ".github/docs-ledger.json"
EXTRA_ALLOWED = (LEDGER, SURFACES, "site/og.png", "site/og-card.html")


def globre(pattern):
    """A path glob as a regex: `**/` spans zero or more directories, `*` and `?` stay in one segment."""
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pattern[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pattern[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pattern[i]), i + 1
    return re.compile(out + r"\Z")


def parse(raw, where):
    """A docs-surfaces.json text, validated; `where` names it in errors."""
    try:
        d = json.loads(raw)
    except ValueError as e:
        raise repo.RepoError("cannot read %s: %s" % (where, e))
    if not isinstance(d, dict) or d.get("schemaVersion") != 1:
        raise repo.RepoError("%s: schemaVersion must be 1" % where)
    for key, typ in (("surfaces", list), ("frozen", list), ("landing", str), ("pages", dict),
                     ("og", dict), ("retired", list)):
        if not isinstance(d.get(key), typ):
            raise repo.RepoError("%s: %r must be a %s" % (where, key, typ.__name__))
    # The fence turns these into path patterns: a non-string would crash it.
    if not all(isinstance(t, str) for t in d["surfaces"] + d["frozen"] + list(d["pages"].values())):
        raise repo.RepoError("%s: surfaces, frozen and pages must hold strings" % where)
    # The unattended model appends to retired[]: a non-string would crash the matcher, and an
    # empty or blank one would match every line of every surface.
    bad = [t for t in d["retired"] if not isinstance(t, str) or not t.strip()]
    if bad:
        raise repo.RepoError("%s: every 'retired' entry must be a non-empty string, got %s"
                             % (where, ", ".join(json.dumps(t) for t in bad)))
    return d


def load(ctx):
    try:
        raw = ctx.read(SURFACES)
    except OSError as e:
        raise repo.RepoError("cannot read %s: %s" % (SURFACES, e))
    return parse(raw, SURFACES)


def load_at(ctx, ref):
    """docs-surfaces.json as committed at ref."""
    raw = ctx.show(ref, SURFACES)
    if raw is None:
        raise repo.RepoError("cannot read %s:%s" % (ref, SURFACES))
    return parse(raw, "%s:%s" % (ref, SURFACES))


def _listed(ctx):
    p = subprocess.run(["git", "-c", "core.quotepath=off", "ls-files", "--cached", "--others",
                        "--exclude-standard"], cwd=ctx.root, stdout=subprocess.PIPE, text=True)
    return sorted(set(p.stdout.splitlines()))


def _patterns(surf, plugins):
    pats = []
    for p in surf["surfaces"]:
        if "{plugin}" in p:
            pats.extend(globre(p.replace("{plugin}", pl["dir"])) for pl in plugins)
        else:
            pats.append(globre(p))
    return pats


def files(ctx, surf):
    """Every doc-surface file present in the working tree, frozen ones excluded."""
    pats = _patterns(surf, ctx.plugins())
    frozen = [globre(p) for p in surf["frozen"]]
    return [f for f in _listed(ctx)
            if any(r.match(f) for r in pats) and not any(r.match(f) for r in frozen)
            and ctx.exists(f)]


def page_of(surf, name):
    return surf["pages"].get(name, "site/%s/index.html" % name)


class Allowlist:
    """The write fence as a predicate over repo paths: the doc surfaces (frozen ones excluded), the
    landing page, every plugin's page path (so a generated page for a new plugin is allowed) and
    EXTRA_ALLOWED. With no config it is the static minimum, EXTRA_ALLOWED alone."""

    def __init__(self, surf=None, plugins=()):
        self.exact = set(EXTRA_ALLOWED)
        self.pats, self.frozen = [], []
        if surf is not None:
            self.exact |= {surf["landing"]} | {page_of(surf, p["name"]) for p in plugins}
            self.pats = _patterns(surf, plugins)
            self.frozen = [globre(p) for p in surf["frozen"]]

    def __call__(self, rel):
        # Never a .gitignore (it decides what the fence can see), never a name with a control
        # character (no doc is named that way, and `**` would match a newline).
        if rel.rsplit("/", 1)[-1] == ".gitignore" or any(ord(c) < 32 or ord(c) == 127 for c in rel):
            return False
        return rel in self.exact or (any(r.match(rel) for r in self.pats)
                                     and not any(r.match(rel) for r in self.frozen))


def allowlist_at(ctx, ref):
    """The fence as of a commit — never the working tree, which the run may edit to widen it."""
    return Allowlist(load_at(ctx, ref), ctx.plugins_at(ref))


def allowed_paths(ctx):
    """The write fence as a listing: the files it allows today plus every plugin page path. Built
    from HEAD's docs-surfaces.json and marketplace, exactly as the fence itself is."""
    allow = allowlist_at(ctx, "HEAD")
    return sorted({f for f in _listed(ctx) if ctx.exists(f) and allow(f)} | allow.exact)
