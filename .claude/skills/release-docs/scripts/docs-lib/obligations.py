"""Assemble every obligation check into one report (docs-detect's JSON)."""
import changelog
import ledger
import surfaces
from kinds import ob


def changelog_obligations(ctx, led):
    obs = []
    for p in ctx.plugins():
        rel = p["dir"] + "/CHANGELOG.md"
        if not ctx.exists(rel):
            continue
        for eid, ver, text in changelog.new_entries(p["name"], ctx.read(rel),
                                                   ctx.base_version(p["dir"])):
            decl = led["entries"].get(eid)
            why = "undeclared in the ledger" if decl is None else ledger.entry_problem(ctx, decl)
            if why:
                obs.append(ob("changelog-entry", p["name"], rel, "%s %s: %s" % (p["name"], ver, why),
                              id=eid, version=ver, text=" ".join(text.split())[:200]))
    return obs


def collect(ctx):
    led = ledger.load(ctx)
    surfaces.load(ctx)
    obs = changelog_obligations(ctx, led)
    return {"schemaVersion": 1, "range": {"base": ctx.base, "head": ctx.head},
            "open": len(obs), "obligations": obs}
