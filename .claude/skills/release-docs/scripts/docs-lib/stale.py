"""stale-mention: retired identifiers still named on a doc surface.

Candidates for one range: repo paths the range deleted or renamed away, skills it removed
(`/plugin:name`), and backticked identifiers that new CHANGELOG entries say were renamed /
removed / retired / dropped / replaced / deleted / relocated / moved / superseded (the verb's
clause, up to its `to` / `with` / `→`). Anything that still exists as a tracked path is dropped. surfaces.json `retired[]` carries confirmed tokens forward across releases."""
import os
import re
import subprocess

import changelog
import inventory
import ledger
import surfaces
from kinds import ob

VERB = re.compile(r"\b(renamed|removed|retired|dropped|replaced|deleted|relocated|moved|"
                  r"superseded)\b", re.I)
SPLIT = re.compile(r"\s(?:to|with|by|into|→)\s")
TICK = re.compile(r"`([^`\n]+)`")
BOUND = re.compile(r"[:—–()]")  # clause edges, looked for outside backticks only


def _keep(tok):
    """Identifier-shaped: 4+ chars, no spaces, and a path/flag/dotted char or a camelCase hump."""
    return len(tok) >= 4 and " " not in tok and (
        re.search(r"[/._:\[\]-]", tok) is not None or re.search(r"[a-z][A-Z]", tok) is not None)


def sentence_candidates(text):
    """Every verb, not only the first, reads its own clause — bounded by `:`, `—`, `–` and
    parentheses outside backticks — up to its split word. A name in a lead-in, an aside or a
    parenthetical of the same sentence is context, not the thing retired (V4: 10 of the full
    history's 13 false candidates were exactly that)."""
    out = set()
    for sent in re.split(r"(?<=[.;])\s+", " ".join(text.split())):
        # Same offsets with backticked text blanked, so no edge, verb or split is read inside a token.
        bare = TICK.sub(lambda m: "`%s`" % ("x" * len(m.group(1))), sent)
        edges = [m.start() for m in BOUND.finditer(bare)]
        for v in VERB.finditer(bare):
            lo = max([e + 1 for e in edges if e < v.start()], default=0)
            hi = min([e for e in edges if e >= v.end()], default=len(sent))
            s = SPLIT.search(bare, v.end(), hi)
            later = set(TICK.findall(sent[s.end():])) if s else set()
            for tok in TICK.findall(sent[lo:s.start() if s else hi]):
                if tok in later or not _keep(tok):
                    continue
                out.add(tok)
                base = os.path.basename(tok.rstrip("/"))
                if "/" in tok and "." in base and _keep(base):
                    out.add(base)
    return out


def _tracked(ctx):
    """Tracked paths, and the basenames that keep a bare file name alive. A copy under a fixtures/
    dir does not: a rename with a migration keeps its legacy file there to test the migration."""
    p = subprocess.run(["git", "-c", "core.quotepath=off", "ls-files"], cwd=ctx.root,
                       stdout=subprocess.PIPE, text=True)
    files = set(p.stdout.splitlines())
    return files, {os.path.basename(f) for f in files if "/fixtures/" not in "/" + f}


def range_candidates(ctx):
    files, basenames = _tracked(ctx)
    dirs = [p["dir"] for p in ctx.plugins()]
    cands = set()
    for st, old, _new in ctx.name_status():
        if st in ("D", "R"):  # name_status reports a deletion as (D, old, old)
            cands.add(old)
    for p in ctx.plugins():
        ls = subprocess.run(["git", "ls-tree", "--name-only", ctx.base, p["dir"] + "/skills/"],
                            cwd=ctx.root, stdout=subprocess.PIPE, text=True).stdout.split()
        now = set(inventory.skills(ctx, p["dir"]))
        cands |= {"/%s:%s" % (p["name"], os.path.basename(d)) for d in ls
                  if os.path.basename(d) not in now}
        rel = p["dir"] + "/CHANGELOG.md"
        if ctx.exists(rel):
            for _id, _v, text in changelog.new_entries(p["name"], ctx.read(rel),
                                                       ctx.base_version(p["dir"])):
                cands |= sentence_candidates(text)

    def alive(tok):
        t = tok.rstrip("/")
        roots = [t] + ["%s/%s" % (d, t) for d in dirs]
        if any(r in files or any(f.startswith(r + "/") for f in files) for r in roots):
            return True
        return "/" not in t and t in basenames

    return sorted(c for c in cands if not alive(c))


def _plugin_of(ctx, rel):
    for p in ctx.plugins():
        if rel.startswith(p["dir"] + "/") or rel.startswith("site/%s/" % p["name"]):
            return p["name"]
    return "marketplace"


def check(ctx, surf, led):
    tokens = set(surf["retired"]) | set(range_candidates(ctx))
    if not tokens:
        return []
    rx = {t: re.compile(r"(?<![\w-])%s(?!\w)" % re.escape(t)) for t in tokens}
    obs = []
    for rel in surfaces.files(ctx, surf):
        for n, line in enumerate(ctx.read(rel).splitlines(), 1):
            hits = [t for t, r in rx.items() if r.search(line)]
            hits = [t for t in hits if not any(t != u and t in u for u in hits)]
            for t in sorted(hits):
                if not ledger.intentional(led, rel, t, line):
                    obs.append(ob("stale-mention", _plugin_of(ctx, rel), rel,
                                  "line %d names retired %s" % (n, t), token=t, line=n))
    return obs
