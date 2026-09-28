"""stale-mention: retired identifiers still named on a doc surface.

Candidates for one range: repo paths the range deleted or renamed away (a removed script or schema
file also as its plugin-relative path and basename), skills it removed (`/plugin:name`), and
backticked identifiers that new CHANGELOG entries say are renamed / removed / retired / dropped /
replaced / deleted / relocated / moved / superseded, in any tense (the verb's clause, up to its
`to` / `with` / `→`), or that sit in a bullet under a `### Removed`-style heading. Anything that
still exists as a tracked path is dropped. surfaces.json `retired[]` carries confirmed tokens
forward across releases."""
import os
import re
import subprocess

import changelog
import inventory
import ledger
import surfaces
from kinds import ob

VERB = re.compile(r"\b(renam(?:e|es|ed)|remov(?:e|es|ed)|retir(?:e|es|ed)|drop(?:s|ped)?|"
                  r"replac(?:e|es|ed)|delet(?:e|es|ed)|relocat(?:e|es|ed)|mov(?:e|es|ed)|"
                  r"supersed(?:e|es|ed))\b(?!-)", re.I)
# A `###` heading that retires every bullet under it; anchored, so "Fixes — … the rename" is not one.
RETIRING = re.compile(r"(?:removed|deprecated|renamed|retired|dropped|deleted)\b", re.I)
SPLIT = re.compile(r"\s(?:to|with|by|into|→)\s")
TICK = re.compile(r"`([^`\n]+)`")
BOUND = re.compile(r"[:—–()]")  # clause edges, looked for outside backticks only
HANDOFF = ":—–"  # the edges across which a name-less verb clause hands over to its neighbour
MARKUP = re.compile(r"[\s*_]*\Z")


def _keep(tok):
    """Identifier-shaped: 4+ chars, no spaces, and a path/flag/dotted char or a camelCase hump."""
    return len(tok) >= 4 and " " not in tok and (
        re.search(r"[/._:\[\]-]", tok) is not None or re.search(r"[a-z][A-Z]", tok) is not None)


def _names(sent, bare, lo, hi, frm):
    """Backticked names in sent[lo:hi] ahead of the first split word at or after frm, and the names
    after that split (the new names, which are never candidates)."""
    s = SPLIT.search(bare, frm, hi)
    later = set(TICK.findall(sent[s.end():])) if s else set()
    return TICK.findall(sent[lo:s.start() if s else hi]), later


def sentence_candidates(text, section=None):
    """Every verb, not only the first, reads its own clause — bounded by `:`, `—`, `–` and
    parentheses outside backticks — up to its split word. A name in a lead-in, an aside or a
    parenthetical of the same sentence is context, not the thing retired (V4: 10 of the full
    history's 13 false candidates were exactly that). A clause that names nothing, beside a colon
    or dash (`**Removed**: …`, `` `x` — removed``), reads the clause across that edge instead. Under
    a retiring `###` heading the first sentence reads as if it opened with the verb."""
    out = set()
    retiring = section is not None and RETIRING.match(section.strip("*_` ")) is not None
    for n, sent in enumerate(re.split(r"(?<=[.;])\s+", " ".join(text.split()))):
        # Same offsets with backticked text blanked, so no edge, verb or split is read inside a token.
        bare = TICK.sub(lambda m: "`%s`" % ("x" * len(m.group(1))), sent)
        edges = [m.start() for m in BOUND.finditer(bare)]
        anchors = [(v.start(), v.end()) for v in VERB.finditer(bare)]
        if retiring and n == 0:
            anchors.insert(0, (0, 0))  # the heading's verb, an empty span at the sentence start (ve == 0)
        for vs, ve in anchors:
            left = [e for e in edges if e < vs]
            right = [e for e in edges if e >= ve]
            lo = left[-1] + 1 if left else 0
            hi = right[0] if right else len(sent)
            toks, later = _names(sent, bare, lo, hi, ve)
            if not TICK.search(sent[lo:hi]):
                if right and bare[hi] in HANDOFF and (ve == 0 or MARKUP.match(bare, ve, hi)):
                    nxt = [e for e in edges if e > hi]
                    toks, later = _names(sent, bare, hi + 1, nxt[0] if nxt else len(sent), hi + 1)
                elif left and bare[left[-1]] in HANDOFF and MARKUP.match(bare, lo, vs):
                    start = left[-2] + 1 if len(left) > 1 else 0
                    toks, later = _names(sent, bare, start, left[-1], start)
            for tok in toks:
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


def _short_names(path, dirs):
    """A removed script's or schema file's plugin-relative path and basename — the names docs use
    (`scripts/tool.sh`, `tool.sh`) — per spec § 5's "removed … script names and schema files"."""
    for d in dirs:
        if path.startswith(d + "/"):
            rel = path[len(d) + 1:]
            if rel.startswith("scripts/") or "/schemas/" in "/" + rel or rel.endswith(".schema.json"):
                return {t for t in (rel, os.path.basename(rel)) if _keep(t)}
    return set()


def range_candidates(ctx):
    files, basenames = _tracked(ctx)
    dirs = [p["dir"] for p in ctx.plugins()]
    cands = set()
    for st, old, _new in ctx.name_status():
        if st in ("D", "R"):  # name_status reports a deletion as (D, old, old)
            cands.add(old)
            cands |= _short_names(old, dirs)
    for p in ctx.plugins():
        ls = subprocess.run(["git", "ls-tree", "--name-only", ctx.base, p["dir"] + "/skills/"],
                            cwd=ctx.root, stdout=subprocess.PIPE, text=True).stdout.split()
        now = set(inventory.skills(ctx, p["dir"]))
        cands |= {"/%s:%s" % (p["name"], os.path.basename(d)) for d in ls
                  if os.path.basename(d) not in now}
        rel = p["dir"] + "/CHANGELOG.md"
        if ctx.exists(rel):
            for _id, _v, text, section in changelog.new_sectioned(p["name"], ctx.read(rel),
                                                                  ctx.base_version(p["dir"])):
                cands |= sentence_candidates(text, section)

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
    # A name ends where the next char cannot continue it: `/lens:render` never matches
    # `/lens:render-review`, nor `foo` `foo.json`, while sentence punctuation still ends a name.
    rx = {t: re.compile(r"(?<![\w-])%s(?![\w-]|\.\w)" % re.escape(t)) for t in tokens}
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
