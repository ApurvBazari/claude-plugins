"""live[]: names declared still alive, so that a retirement sentence naming one opens nothing
(docs-surfaces.json `live`, beside `retired`).

A declaration counts only while it is proven: the token appears, as a whole token, in a plugin
source. A plugin source is a tracked regular file under a marketplace plugin's directory that is not
a path the write fence lets a run change (every doc surface is one), not a frozen doc, not a
CHANGELOG.md and not under a fixtures/ directory. So tests, fixtures, the ledger, this skill's own
references and every file a run may write prove nothing, and an entry stops counting on the day the
code drops the name.

Proof is necessary, never sufficient: a source can still name a retired thing as the legacy side of
a migration. Whether a proven token is live is the playbook's judgement. proof() returns where the
token was found so that the PR body can show the line to the owner."""
import os
import re
import stat
import subprocess

import surfaces

# How many entries one run may add. Any phrase of a plugin source is provable, the PR body shows the
# evidence for each addition, and that body is cut at a fixed size: without a bound, a flood of
# provable entries would push the evidence out of the body. The write fence fails a run above it,
# so the body never has to leave out an entry that was accepted. The whole history has two.
MAX_ADDED = 20


def added(old, new):
    """The distinct entries of new that old lacks, in order, cut off one past MAX_ADDED. A repeated
    name is one entry, for the fence's bound and the PR body alike: if only the bound ignored
    repeats, copies of one name would fill the body and hide the next entry. The cut-off is enough
    to know that a run is over the bound, and keeps the work from growing with what the run wrote."""
    out = []
    for t in new:
        if t not in old and t not in out:
            out.append(t)
            if len(out) > MAX_ADDED:
                break
    return out


def whole(tok):
    """tok as a whole name. A name ends where the next char cannot continue it: `/lens:render`
    never matches `/lens:render-review`, nor `foo` `foo.json`, while sentence punctuation still
    ends a name."""
    return re.compile(r"(?<![\w-])%s(?![\w-]|\.\w)" % re.escape(tok))


def _regular(ctx, rel):
    """A regular file, never a symlink: one into a doc surface would let a run write its own proof."""
    try:
        return stat.S_ISREG(os.lstat(ctx.path(rel)).st_mode)
    except OSError:
        return False


def sources(ctx, surf, plugins):
    """[(path, text)] for every plugin source, in path order. `surf` and `plugins` say what a doc
    surface and a plugin directory are; callers take both from a commit (sources_at)."""
    dirs = [p["dir"] for p in plugins]
    allow = surfaces.Allowlist(surf, plugins)  # the doc surfaces, the landing page, each plugin's page
    frozen = [surfaces.globre(p) for p in surf["frozen"]]
    p = subprocess.run(["git", "ls-files", "-z"], cwd=ctx.root, stdout=subprocess.PIPE)
    out = []
    for rel in sorted({os.fsdecode(r) for r in p.stdout.split(b"\0") if r}):
        if not any(rel.startswith(d + "/") for d in dirs):
            continue
        if allow(rel) or any(r.match(rel) for r in frozen):
            continue
        if rel.rsplit("/", 1)[-1] == "CHANGELOG.md" or "/fixtures/" in "/" + rel:
            continue
        if not _regular(ctx, rel):
            continue
        try:
            with open(ctx.path(rel), encoding="utf-8", errors="replace") as f:
                out.append((rel, f.read()))
        except OSError:
            continue
    return out


def sources_at(ctx, ref):
    """sources(), with a doc surface and a plugin directory as the config and marketplace committed
    at ref define them. The detector, the fence and the PR body all judge from a commit, never from
    the working tree: its config is the run's to edit, and one that drops a doc from `surfaces`
    would turn a doc the run wrote into the proof of its own entry. Raises repo.RepoError when ref
    has no readable config."""
    return sources(ctx, surfaces.load_at(ctx, ref), ctx.plugins_at(ref))


def proof(srcs, tok):
    """(path, line number) of the first plugin source, in path order, that names tok as a whole
    token, or None. Anything but a non-blank string is never proven."""
    if not isinstance(tok, str) or not tok.strip():
        return None
    rx = whole(tok)
    for rel, text in srcs:
        for n, line in enumerate(text.splitlines(), 1):
            if rx.search(line):
                return rel, n
    return None
