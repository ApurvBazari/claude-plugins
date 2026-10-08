"""stale-mention: retired identifiers still named on a doc surface.

Candidates for one range: repo paths the range deleted or renamed away (a removed script or schema
file also as its plugin-relative path and basename), skills it removed (`/plugin:name`), and
backticked identifiers that new CHANGELOG entries say are renamed / removed / retired / dropped /
replaced / deleted / relocated / moved / superseded, in any tense (the verb's clause, up to its
`to` / `with` / `in favor of` / `→`; the subject of a present form that has no object), or that sit in a bullet
under a `### Removed`-style heading. Anything that
still exists is dropped: a tracked path, or a current skill or agent of any plugin (`/p:s`, `p:s`,
the skill's name or directory, the agent's name or `p:agent`), since "Removed the `--x` flag from
`/lens:review`" retires the flag, not the skill. surfaces.json `retired[]` carries confirmed tokens
forward across releases, and is never filtered: a retired name is the owner's call. `live[]` is
its opposite, for a name a retirement sentence only mentions: a declared name that a plugin source
still has (live.py) is dropped from the range's candidates. A name in both lists is retired."""
import os
import re
import subprocess

import changelog
import inventory
import ledger
import live
import surfaces
from kinds import ob

# Not behind a hyphen: "unanimous-drop" is a compound name, not a verb.
VERB = re.compile(r"(?<!-)\b(renam(?:e|es|ed)|remov(?:e|es|ed)|retir(?:e|es|ed)|drop(?:s|ped)?|"
                  r"replac(?:e|es|ed)|delet(?:e|es|ed)|relocat(?:e|es|ed)|mov(?:e|es|ed)|"
                  r"supersed(?:e|es|ed))\b(?!-)", re.I)
# A `###` heading that retires every bullet under it; anchored, so "Fixes — … the rename" is not one.
RETIRING = re.compile(r"(?:removed|deprecated|renamed|retired|dropped|deleted)\b", re.I)
SPLIT = re.compile(r"\s(?:to|with|by|into|→|in favou?r of)\s")
TICK = re.compile(r"`([^`\n]+)`")
BOUND = re.compile(r"[:—–()]")  # clause edges, looked for outside backticks only
HANDOFF = ":—–"  # the edges across which a name-less verb clause hands over to its neighbour
MARKUP = re.compile(r"[\s*_]*\Z")
# What follows a present or base form used without an object: nothing, or a word that says where the
# subject goes.
NO_OBJECT = re.compile(r"\s*(?:(?:to|into|out|from|away)\b|→|[\s*_.;!?]*\Z)")


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
    a retiring `###` heading the first sentence reads as if it opened with the verb.

    Only a past form (`removed`, `dropped`, …) reads the names before the verb in its clause, as its
    object ("`x` is removed", "`x` — removed"). Before a present or base form stands the actor
    ("`/onboard:evolve` now removes …", "`new-api` replaces `old-api`"), so that verb reads only
    what follows it. On the full CHANGELOG history, this and VERB's hyphen guard lost no true
    candidate and dropped two false ones (`detect-{config,dep,structure}-changes.sh`, `pipeline.md`).

    A present or base form with no object has no actor either ("`oldKey` renames to `newKey`",
    "`old-flag` drops out"): its subject is the thing retired. So when nothing follows the verb in
    its clause, or a word that says where the subject goes, the verb reads the names before it, back
    to the previous verb of the clause (in "`a` replaces `b` and moves to the top", `a` is still the
    actor of the first verb), and none after it: those name where the thing went. No entry in the
    history has this shape; the rule is there so that the first one is not missed."""
    out = set()
    retiring = section is not None and RETIRING.match(section.strip("*_` ")) is not None
    for n, sent in enumerate(re.split(r"(?<=[.;])\s+", " ".join(text.split()))):
        # Same offsets with backticked text blanked, so no edge, verb or split is read inside a token.
        bare = TICK.sub(lambda m: "`%s`" % ("x" * len(m.group(1))), sent)
        edges = [m.start() for m in BOUND.finditer(bare)]
        # (start, end, past): a past form reads its whole clause, any other form only what follows.
        anchors = [(v.start(), v.end(), v.group(1).lower().endswith("ed"))
                   for v in VERB.finditer(bare)]
        if retiring and n == 0:
            # the heading's verb, an empty span at the sentence start (ve == 0)
            anchors.insert(0, (0, 0, True))
        for vs, ve, past in anchors:
            left = [e for e in edges if e < vs]
            right = [e for e in edges if e >= ve]
            lo = left[-1] + 1 if left else 0
            hi = right[0] if right else len(sent)
            if not past and NO_OBJECT.match(bare, ve, hi):
                # no object, so no actor: the subject, back to the previous verb, is the thing retired
                lo = max([e for _s, e, _p in anchors if lo <= e <= vs], default=lo)
                toks, later = TICK.findall(sent[lo:vs]), set()
            else:
                if not past:
                    lo = ve  # the actor before a present or base form with an object is never retired
                toks, later = _names(sent, bare, lo, hi, ve)
            if not TICK.search(sent[lo:hi]):
                if right and bare[hi] in HANDOFF and (ve == 0 or MARKUP.match(bare, ve, hi)):
                    nxt = [e for e in edges if e > hi]
                    toks, later = _names(sent, bare, hi + 1, nxt[0] if nxt else len(sent), hi + 1)
                elif past and left and bare[left[-1]] in HANDOFF and MARKUP.match(bare, lo, vs):
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


def _live_names(ctx):
    """Every current skill and agent of every marketplace plugin, in each form a doc names it."""
    live = set()
    for p in ctx.plugins():
        root = ctx.path(p["dir"] + "/skills")
        on_disk = [d for d in os.listdir(root)
                   if os.path.isfile(os.path.join(root, d, "SKILL.md"))] if os.path.isdir(root) else []
        for s in set(inventory.skills(ctx, p["dir"])) | set(on_disk):
            live |= {"/%s:%s" % (p["name"], s), "%s:%s" % (p["name"], s), s}
        for a in inventory.agents(ctx, p["dir"]):
            live |= {"%s:%s" % (p["name"], a), a}
    return live


def range_candidates(ctx):
    files, basenames = _tracked(ctx)
    dirs = [p["dir"] for p in ctx.plugins()]
    live = _live_names(ctx)
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
        if t in live:
            return True
        roots = [t] + ["%s/%s" % (d, t) for d in dirs]
        if any(r in files or any(f.startswith(r + "/") for f in files) for r in roots):
            return True
        return "/" not in t and t in basenames

    return sorted(c for c in cands if not alive(c))


def undecided(ctx, surf):
    """The range candidates that no proven live[] entry covers: what --candidates lists and what
    check() flags. An entry that no plugin source has is ignored, so it stops working by itself on
    the day the code drops the name. Plugin sources are read only when live[] names a candidate."""
    cands = range_candidates(ctx)
    declared = [t for t in surf["live"] if t in cands]
    if not declared:
        return cands
    ok = live.proven(live.sources(ctx, surf, ctx.plugins()), declared)
    return [c for c in cands if c not in ok]


def _plugin_of(ctx, rel):
    for p in ctx.plugins():
        if rel.startswith(p["dir"] + "/") or rel.startswith("site/%s/" % p["name"]):
            return p["name"]
    return "marketplace"


def check(ctx, surf, led):
    # retired[] wins: a name in both lists stays flagged.
    tokens = set(surf["retired"]) | set(undecided(ctx, surf))
    if not tokens:
        return []
    rx = {t: live.whole(t) for t in tokens}
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
