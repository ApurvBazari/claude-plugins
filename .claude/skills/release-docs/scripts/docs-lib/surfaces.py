"""surfaces.json: which files are doc surfaces, the page map, OG strings, retired identifiers."""
import json
import re
import subprocess

import repo

SURFACES = ".claude/skills/release-docs/surfaces.json"
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


def load(ctx):
    try:
        d = json.loads(ctx.read(SURFACES))
    except (OSError, ValueError) as e:
        raise repo.RepoError("cannot read %s: %s" % (SURFACES, e))
    if not isinstance(d, dict) or d.get("schemaVersion") != 1:
        raise repo.RepoError("%s: schemaVersion must be 1" % SURFACES)
    for key, typ in (("surfaces", list), ("frozen", list), ("landing", str), ("pages", dict),
                     ("og", dict), ("retired", list)):
        if not isinstance(d.get(key), typ):
            raise repo.RepoError("%s: %r must be a %s" % (SURFACES, key, typ.__name__))
    return d


def _listed(ctx):
    p = subprocess.run(["git", "-c", "core.quotepath=off", "ls-files", "--cached", "--others",
                        "--exclude-standard"], cwd=ctx.root, stdout=subprocess.PIPE, text=True)
    return sorted(set(p.stdout.splitlines()))


def files(ctx, surf):
    """Every doc-surface file present in the working tree, frozen ones excluded."""
    pats = []
    for p in surf["surfaces"]:
        if "{plugin}" in p:
            pats.extend(globre(p.replace("{plugin}", pl["dir"])) for pl in ctx.plugins())
        else:
            pats.append(globre(p))
    frozen = [globre(p) for p in surf["frozen"]]
    return [f for f in _listed(ctx)
            if any(r.match(f) for r in pats) and not any(r.match(f) for r in frozen)
            and ctx.exists(f)]


def page_of(surf, name):
    return surf["pages"].get(name, "site/%s/index.html" % name)


def allowed_paths(ctx):
    """The write fence: doc surfaces, the ledger, surfaces.json, the OG card and every plugin's
    page path (so a generated page for a new plugin is allowed)."""
    surf = load(ctx)
    extra = list(EXTRA_ALLOWED) + [page_of(surf, p["name"]) for p in ctx.plugins()]
    return sorted(set(files(ctx, surf)) | set(extra))
