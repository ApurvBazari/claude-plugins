"""--pr-body: the docs PR description, built by this script, never written by the model. The
obligations come from the detector, the coverage table from the ledger, the edit and config lists
from git. The one model-written input is verifier.json. Every value a run could have written (the
verifier's fields, the ledger, docs-surfaces.json, a doc's text) is shown inside a code span, so no
`<!--`, tag, link or @mention in it renders, or hides the post-checks report placed around it."""
import collections
import json
import re
import subprocess

import changelog
import fence
import ledger
import live
import obligations
import repo
import stale
import surfaces

PLUGIN_INTERNAL = "plugin-internal: needs a version bump + CHANGELOG if kept"
MAX_ITEMS = 60


def _code(s, n=None, table=False):
    """s as one inline code span: whitespace collapsed, backticks swapped for ' (a span cannot hold
    its own delimiter safely), cut at n characters; pipes escaped in a table cell. Empty is —."""
    s = " ".join(str(s).split()).replace("`", "'")
    if n is not None and len(s) > n:
        s = s[:n - 1] + "…"
    if table:
        s = s.replace("|", "\\|")
    return "`%s`" % s if s else "—"


def _key(o):
    """What matches an obligation before and after the run. A stale-mention is matched by file and
    token, never by its line: an edit above it shifts the line, which is not a fix."""
    if o["kind"] == "stale-mention" and isinstance(o.get("token"), str):
        return ("stale-mention", o["file"], o["token"])
    # Two changelog-entry obligations can share one detail line; their entry id tells them apart.
    return (o["kind"], o["file"], o["detail"], o.get("id"))


def _line(o):
    tail = " (%s)" % _code(o["id"]) if o.get("id") else ""
    return "- `%s` %s — %s%s" % (o["kind"], _code(o["file"]), _code(o["detail"], 300), tail)


def _capped(lines, what):
    if len(lines) <= MAX_ITEMS:
        return lines
    return lines[:MAX_ITEMS] + ["- … and %d more %s" % (len(lines) - MAX_ITEMS, what)]


def _load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _head_json(ctx, rel):
    """rel as committed at HEAD, parsed, or None when it is missing or unreadable."""
    raw = ctx.show("HEAD", rel)
    try:
        return json.loads(raw) if raw is not None else None
    except (ValueError, RecursionError):
        return None


def _new_intentional(ctx, led):
    """The ledger's intentional entries HEAD's ledger lacks: the ones this run added."""
    was = _head_json(ctx, ledger.LEDGER)
    old = was.get("intentional") if isinstance(was, dict) else None
    old = old if isinstance(old, list) else []
    return [i for i in led["intentional"] if i not in old]


def _resolved(before, now, added, gone):
    """The Resolved lines. A stale-mention counts per file and token ("1 of 2 mentions"), and says
    when a new intentional entry covers it, so the owner can check that it is truly historical, or
    when a live[] entry dismissed its token (gone): no doc was edited for those."""
    left = collections.Counter(_key(o) for o in now)
    done = []
    for o in before:
        k = _key(o)
        if left[k]:
            left[k] -= 1
        else:
            done.append(o)
    total = collections.Counter(_key(o) for o in before)
    fixed = collections.Counter(_key(o) for o in done)
    lines, shown = [], set()
    for o in done:
        k = _key(o)
        if k[0] != "stale-mention" or len(k) != 3:
            lines.append(_line(o))
            continue
        if k in shown:
            continue
        shown.add(k)
        how = [i for i in added if i.get("file") == o["file"] and i.get("token") == o["token"]]
        note = ", resolved by a new intentional entry (reason %s)" % _code(how[0].get("reason"), 200) \
            if how else ""
        if o["token"] in gone:
            note = ", closed by a `live[]` entry, not by a doc edit"
        lines.append("- `stale-mention` %s — retired %s: %d of %d mention(s) resolved%s"
                     % (_code(o["file"]), _code(o["token"]), fixed[k], total[k], note))
    return len(done), lines


def _numstat(ctx):
    """{path: "+a −d"} for the tracked files the working tree changed against HEAD."""
    p = subprocess.run(["git", "-c", "core.quotepath=off", "diff", "--numstat", "-z", "--no-renames",
                        "HEAD"], cwd=ctx.root, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out = {}
    for rec in p.stdout.split(b"\0") if p.returncode == 0 else []:
        parts = rec.split(b"\t", 2)
        if len(parts) == 3:
            a, d = parts[0].decode("ascii", "replace"), parts[1].decode("ascii", "replace")
            out[parts[2].decode("utf-8", "replace")] = "binary" if a == "-" else "+%s −%s" % (a, d)
    return out


def _other_edits(ctx, named, cited):
    """Every file the run changed that no obligation names, grouped by class (spec § 6's "included
    vs omitted"): edits beyond the obligations are exactly what the owner must accept by reading.
    Only paths inside HEAD's fence are listed; anything else is the owner's or the fence's."""
    try:
        allow = surfaces.allowlist_at(ctx, "HEAD")
    except Exception:  # an unbuildable allowlist: list every change rather than hide one
        allow = None
    stat = _numstat(ctx)
    dirs = [p["dir"] for p in ctx.plugins()]
    groups = collections.OrderedDict((c, []) for c in ("site", "docs", PLUGIN_INTERNAL))
    for xy, rel in sorted(fence.status(ctx), key=lambda r: r[1]):
        if rel in named or rel in (ledger.LEDGER, surfaces.SURFACES) or (allow and not allow(rel)):
            continue
        cls = "site" if rel.startswith("site/") else "docs"
        if any(rel.startswith(d + "/references/")
               or re.match(re.escape(d) + r"/skills/[^/]+/references/", rel) for d in dirs):
            cls = PLUGIN_INTERNAL
        how = "new file" if "?" in xy or "A" in xy else "deleted" if "D" in xy else stat.get(rel, "changed")
        groups[cls].append("  - %s (%s%s)" % (_code(rel), how,
                                               "; cited by the coverage ledger" if rel in cited else ""))
    out = []
    for cls, items in groups.items():
        if items:
            out.append("- %s" % cls)
            out += _capped(items, "file(s)")
    return out


def _live_sources(ctx):
    """The plugin sources as HEAD's config and marketplace define them, which is the fence's view,
    or none when HEAD's config cannot be read."""
    try:
        return live.sources_at(ctx, "HEAD")
    except repo.RepoError:
        return []


def _live_lines(ctx, gone):
    """The live[] section: what the list dismissed in this range (gone, from stale.dismissed), then
    what the run changed in it. A dismissal closes every flag that a retirement sentence would have
    opened for the name, so each is listed with the plugin source line that proves the entry, for
    the owner to read: a legacy or migrated-from mention there is not a live use. An entry already
    in HEAD's list is listed too, in every range where it dismisses something.

    render() puts these lines first, ahead of every list a run can lengthen: CI cuts the body at a
    fixed size from the tail, and retired[] additions placed before them would push them out. The
    fence fails a run that adds more than live.MAX_ADDED, so no accepted entry is left out here."""
    out = ["- `live[]` dismisses %s in this range (still in %s)" % (_code(t, 200), _code("%s:%d" % w))
           for t, w in gone.items()]
    was = _head_json(ctx, surfaces.SURFACES)
    try:
        now = json.loads(ctx.read(surfaces.SURFACES))
    except (OSError, ValueError, RecursionError):
        return out  # _config_changes says that the config is unreadable
    if not isinstance(was, dict) or not isinstance(now, dict):
        return out
    wl = was.get("live") if isinstance(was.get("live"), list) else []
    nl = now.get("live") if isinstance(now.get("live"), list) else []
    new_live = [t for t in nl if t not in wl]
    shown = new_live[:live.MAX_ADDED]
    srcs = _live_sources(ctx) if shown else []
    for t in shown:
        where = live.proof(srcs, t)
        if not where:
            out.append("- `live[]` added %s: not accepted, no plugin source mentions it" % _code(t, 200))
            continue
        # isinstance: a list is not hashable, and gone holds only strings
        needed = isinstance(t, str) and t in gone
        out.append("- `live[]` added %s (still in %s)%s" % (
            _code(t, 200), _code("%s:%d" % where), "" if needed else "; it dismisses nothing in this range"))
    if len(new_live) > len(shown):
        out.append("- `live[]`: %d more addition(s) not shown; the write fence fails a run that "
                   "adds more than %d" % (len(new_live) - len(shown), live.MAX_ADDED))
    return out + _capped(["- `live[]` dropped %s" % _code(t, 200) for t in wl if t not in nl],
                         "dropped `live[]` entries")


def _config_changes(ctx, led, added):
    """What the run changed in docs-surfaces.json beside live[], which has its own section (retired[]
    and og), and the intentional entries it added: each one silences or renames something, so each is
    listed."""
    out = []
    was = _head_json(ctx, surfaces.SURFACES)
    try:
        now = json.loads(ctx.read(surfaces.SURFACES))
    except (OSError, ValueError, RecursionError):
        now = None
    if not isinstance(now, dict):
        out.append("- `%s` is unreadable" % surfaces.SURFACES)
    elif isinstance(was, dict):
        wr = was.get("retired") if isinstance(was.get("retired"), list) else []
        nr = now.get("retired") if isinstance(now.get("retired"), list) else []
        out += ["- `retired[]` added %s" % _code(t, 200) for t in nr if t not in wr]
        out += ["- `retired[]` dropped %s (the write fence fails this)" % _code(t, 200)
                for t in wr if t not in nr]
        wo = was.get("og") if isinstance(was.get("og"), dict) else {}
        no = now.get("og") if isinstance(now.get("og"), dict) else {}
        for page in sorted(set(wo) | set(no)):
            a, b = wo.get(page), no.get(page)
            if a == b:
                continue
            if not isinstance(a, dict) or not isinstance(b, dict):
                out.append("- `og` %s %s" % (_code(page), "added" if a is None else
                                              "removed" if b is None else "replaced"))
                continue
            out += ["- `og` %s %s → %s" % (_code(page), _code(k), _code(b[k], 200) if k in b else "removed")
                    for k in sorted(set(a) | set(b)) if a.get(k) != b.get(k)]
    out += ["- new `intentional` entry: %s names %s, context %s, reason %s"
            % (_code(i.get("file")), _code(i.get("token")), _code(i.get("context"), 120),
               _code(i.get("reason"), 200)) for i in added]
    return out


def _ledger_table(ctx, led):
    out = ["| Entry | Disposition | Where / why |", "|---|---|---|"]
    rows = 0
    for p in ctx.plugins():
        rel = p["dir"] + "/CHANGELOG.md"
        if not ctx.exists(rel):
            continue
        for eid, _ver, text in changelog.new_entries(p["name"], ctx.read(rel),
                                                     ctx.base_version(p["dir"])):
            d = led["entries"].get(eid)
            if d is None:
                disp, where = "**undeclared**", "—"
            elif not isinstance(d, dict):
                disp, where = "**invalid**", "—"
            else:
                disp = _code(d.get("disposition"), 40, table=True)
                at = d.get("at")
                where = ", ".join(map(str, at)) if isinstance(at, list) else ""
                where = _code(where or d.get("reason") or "", 120, table=True)
            out.append("| %s %s | %s | %s |" % (_code(eid, table=True), _code(text, 70, table=True),
                                                  disp, where))
            rows += 1
    if not rows:
        out.append("| — | no new CHANGELOG entries in this range | — |")
    return out


def _verifier(path):
    """The verifier section. verifier.json is the model's, so anything but a JSON list of objects is
    one line saying so: never an exit 2 that leaves the PR without a body (spec § 6: disagreements
    are never dropped silently, and neither is the fact that they could not be read)."""
    try:
        with open(path, encoding="utf-8") as f:
            raw = f.read()
    except FileNotFoundError:
        return ["", "### Verifier disagreements", "", "- verifier output missing: %s" % path]
    except (OSError, UnicodeDecodeError) as e:
        return ["", "### Verifier disagreements", "",
                "- verifier output unreadable: %s" % _code(fence.describe(e), 200)]
    try:
        verdicts = json.loads(raw)
    except (ValueError, RecursionError) as e:
        return ["", "### Verifier disagreements", "",
                "- verifier output unreadable: not JSON (%s)" % _code(fence.describe(e), 200)]
    if not isinstance(verdicts, list) or not all(isinstance(v, dict) for v in verdicts):
        return ["", "### Verifier disagreements", "",
                "- verifier output unreadable: not a JSON list of objects"]
    disputes = [v for v in verdicts if v.get("verdict") != "ok"]
    out = ["", "### Verifier disagreements (%d)" % len(disputes), "",
           "From the verifier's last round, as the model saved it in `verifier.json`. A claim the "
           "model fixed after that round is still listed until a later round re-checks it, so read "
           "each against the diff.", ""]
    items = ["- %s — %s (%s): %s" % (_code(v.get("file"), 120), _code(v.get("claim"), 300),
                                     _code(v.get("verdict"), 20), _code(v.get("evidence"), 300))
             for v in disputes]
    return out + (_capped(items, "in `verifier.json`") or ["- none"])


def render(ctx, before_path, verifier_path):
    try:
        before = _load(before_path)["obligations"]
        if not isinstance(before, list) or not all(
                isinstance(o, dict) and all(isinstance(o.get(k), str) for k in ("kind", "file", "detail"))
                for o in before):
            raise TypeError
    except (KeyError, TypeError):
        raise repo.RepoError("--before %s is not a docs-detect --out report" % before_path)
    now = obligations.collect(ctx)["obligations"]
    led = ledger.load(ctx)
    added = _new_intentional(ctx, led)
    gone = stale.dismissed(ctx, surfaces.load(ctx))
    n_done, done = _resolved(before, now, added, gone)
    named = {o["file"] for o in before + now}
    cited = {t.split("#", 1)[0] for d in led["entries"].values() if isinstance(d, dict)
             and isinstance(d.get("at"), list) for t in d["at"] if isinstance(t, str)}
    out = ["## Release docs sync", "",
           "Range `%s..%s`. `docs-detect.sh --pr-body` builds this, not the model: the obligations "
           "come from the detector, the coverage table from the ledger, and the edit and config "
           "lists from git. Only the verifier section comes from the model's `verifier.json`. "
           "Anything a run could have written is shown as code." % (ctx.base[:7], ctx.head[:7]), ""]
    live_lines = _live_lines(ctx, gone)
    if live_lines:
        out += ["### `live[]`: names declared still alive", "",
                "A dismissal closes every flag that a retirement sentence in this range would have "
                "opened for the name. Read the plugin source line shown as its evidence: a legacy "
                "or migrated-from mention there is not a live use, and the name belongs in "
                "`retired[]`. This section comes first so that nothing below can push it past the "
                "size cut.", ""] + live_lines + [""]
    out += ["### Resolved (%d)" % n_done, ""]
    out += _capped(done, "obligation(s)") or ["- none"]
    out += ["", "### Still open (%d)" % len(now), ""]
    out += _capped([_line(o) for o in now], "obligation(s)") or ["- none"]
    out += ["", "### Other edits", "",
            "Files this run changed that no obligation names. The ledger and docs-surfaces.json "
            "have their own sections.", ""]
    out += _other_edits(ctx, named, cited) or ["- none"]
    out += ["", "### Ledger and config changes", ""]
    out += _config_changes(ctx, led, added) or ["- none"]
    out += ["", "### Coverage ledger — this release's CHANGELOG entries", ""]
    out += _ledger_table(ctx, led)
    if verifier_path:
        out += _verifier(verifier_path)
    return "\n".join(out)
