"""--pr-body: the docs PR description, built from the detector and the ledger — never model prose."""
import json

import changelog
import ledger
import obligations
import repo


def _cell(s, n):
    s = " ".join(str(s).split()).replace("|", "\\|")
    return s if len(s) <= n else s[:n - 1] + "…"


def _key(o):
    """Two changelog-entry obligations can share one detail line; their entry id tells them apart."""
    return (o["kind"], o["file"], o["detail"], o.get("id"))


def _line(o):
    tail = " (`%s`)" % o["id"] if o.get("id") else ""
    return "- `%s` %s — %s%s" % (o["kind"], o["file"], o["detail"], tail)


def _load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def render(ctx, before_path, verifier_path):
    try:
        before = _load(before_path)["obligations"]
        keyed = [_key(o) for o in before]
    except (KeyError, TypeError):
        raise repo.RepoError("--before %s is not a docs-detect --out report" % before_path)
    now = obligations.collect(ctx)["obligations"]
    open_now = {_key(o) for o in now}
    done = [o for o, k in zip(before, keyed) if k not in open_now]
    led = ledger.load(ctx)
    out = ["## Release docs sync", "",
           "Range `%s..%s`. Every line below comes from `docs-detect.sh` and the ledger."
           % (ctx.base[:7], ctx.head[:7]), "",
           "### Resolved (%d)" % len(done), ""]
    out += [_line(o) for o in done] or ["- none"]
    out += ["", "### Still open (%d)" % len(now), ""]
    out += [_line(o) for o in now] or ["- none"]
    out += ["", "### Coverage ledger — this release's CHANGELOG entries", "",
            "| Entry | Disposition | Where / why |", "|---|---|---|"]
    rows = 0
    for p in ctx.plugins():
        rel = p["dir"] + "/CHANGELOG.md"
        if not ctx.exists(rel):
            continue
        for eid, _ver, text in changelog.new_entries(p["name"], ctx.read(rel),
                                                     ctx.base_version(p["dir"])):
            d = led["entries"].get(eid, {})
            if not isinstance(d, dict):
                d = {"disposition": "**invalid**"}
            at = d.get("at")
            where = ", ".join(map(str, at)) if isinstance(at, list) else ""
            where = where or d.get("reason") or "—"
            out.append("| `%s` %s | %s | %s |" % (eid, _cell(text, 70),
                                                  _cell(d.get("disposition", "**undeclared**"), 40),
                                                  _cell(where, 120)))
            rows += 1
    if not rows:
        out.append("| — | no new CHANGELOG entries in this range | — |")
    if verifier_path:
        # Disagreements are never dropped silently (spec § 6): a missing file is said so.
        try:
            verdicts = _load(verifier_path)
        except OSError:
            out += ["", "### Verifier disagreements", "",
                    "- verifier output missing: %s" % verifier_path]
            return "\n".join(out)
        if not isinstance(verdicts, list) or not all(isinstance(v, dict) for v in verdicts):
            raise repo.RepoError("--verifier %s must be a JSON list of objects" % verifier_path)
        disputes = [v for v in verdicts if v.get("verdict") != "ok"]
        out += ["", "### Verifier disagreements (%d)" % len(disputes), ""]
        out += ["- %s — %s (%s): %s" % (v.get("file"), v.get("claim"), v.get("verdict"),
                                        v.get("evidence")) for v in disputes] or ["- none"]
    return "\n".join(out)
