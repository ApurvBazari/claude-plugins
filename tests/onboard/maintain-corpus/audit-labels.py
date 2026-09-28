#!/usr/bin/env python3
"""audit-labels.py [ranges.json] — check every labelled item against plain git evidence.

A label drafted from detect's own output would pass the corpus belt by construction. This audit
shares no code with maintain-detect: for each item it asks git whether the claim is true — the
dependency or script really was added/removed in that package.json, the cited tooling line exists
at base and names what the item says, the path really was deleted or renamed, the file really is
in the diff. It proves each label item is supported, not that the label is complete.
Exit 0 when every item of every available range is supported; 1 otherwise. Missing repos skip.
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
problems = []


def git(repo, *args):
    return subprocess.run(["git", "-C", repo] + list(args), stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=False).stdout.decode("utf-8", "replace")


def pkg(repo, ref, path):
    text = git(repo, "show", "%s:%s" % (ref, path))
    try:
        data = json.loads(text) if text else {}
    except ValueError:
        return {}, {}
    deps = dict(data.get("devDependencies") or {})
    deps.update(data.get("dependencies") or {})
    return deps, (data.get("scripts") or {})


def line_text(repo, base, ref):
    path, n = ref.rsplit(":", 1)
    lines = git(repo, "show", "%s:%s" % (base, path)).splitlines()
    return lines[int(n) - 1] if 0 < int(n) <= len(lines) else None


def audit(r):
    repo = os.path.expanduser(r["repo"])
    if not os.path.isdir(os.path.join(repo, ".git")):
        print("SKIP %s (repo not on this machine)" % r["id"])
        return
    base, head = r["base"], r["head"]
    status = {}
    for rec in git(repo, "diff", "--name-status", "-M", base, head).splitlines():
        parts = rec.split("\t")
        if parts[0].startswith("R"):
            status[parts[1]] = ("R", parts[2])
            status[parts[2]] = ("A", None)
        else:
            status[parts[1]] = (parts[0][0], None)
    base_files = set(git(repo, "ls-tree", "-r", "--name-only", base).splitlines())
    head_files = set(git(repo, "ls-tree", "-r", "--name-only", head).splitlines())

    def bad(item, why):
        problems.append("%s: %s — %s" % (r["id"], json.dumps(item)[:160], why))

    def cites(item, ref, needle, token=False):
        text = line_text(repo, base, ref)
        if text is None:
            bad(item, "%s does not exist at base" % ref)
        elif token and needle not in re.split(r"[\s`'\"]+", text):
            bad(item, "%s does not carry the token %s" % (ref, needle))
        elif not token and needle.lower() not in text.lower():
            bad(item, "%s does not mention %s" % (ref, needle))

    for item in r["expected"]["items"]:
        kind = item["kind"]
        if kind in ("dependency-added", "dependency-removed", "script-added", "script-removed"):
            b_deps, b_scripts = pkg(repo, base, item["file"])
            h_deps, h_scripts = pkg(repo, head, item["file"])
            b, h = (b_deps, h_deps) if kind.startswith("dependency") else (b_scripts, h_scripts)
            added = item["name"] in h and item["name"] not in b
            removed = item["name"] in b and item["name"] not in h
            if kind.endswith("added") and not added:
                bad(item, "not added in %s" % item["file"])
            if kind.endswith("removed"):
                if not removed:
                    bad(item, "not removed in %s" % item["file"])
                for ref in [item["line"]] + item["alsoAt"]:
                    cites(item, ref, item["name"], token=kind == "script-removed")
        elif kind == "recheck-line":
            for m in item["matched"]:
                if m["by"] == "path":
                    if m["value"] not in status:
                        bad(item, "%s is not in the diff" % m["value"])
                    else:
                        cites(item, item["line"], os.path.basename(m["value"]))
                else:
                    cites(item, item["line"], m["value"])
        elif kind == "path-mention-broken":
            cites(item, item["line"], item["mention"])
            p, to = item["path"], item.get("renamedTo")
            if p in base_files:
                st = status.get(p, (None, None))
                ok = (st[0] == "R" and to == st[1]) or (st[0] == "D" and to is None)
            else:
                under = [f for f in base_files if f.startswith(p + "/") and os.path.basename(f) != "CLAUDE.md"]
                ok = bool(under) and all(status.get(f, ("", None))[0] in ("D", "R") for f in under)
                if ok and to is not None:
                    ok = all(status[f][0] == "R" and status[f][1] == to + f[len(p):] for f in under)
            if not ok:
                bad(item, "%s was not deleted/renamed as labelled" % p)
        elif kind in ("config-changed", "manifest-changed"):
            if item["file"] not in status:
                bad(item, "%s is not in the diff" % item["file"])
        elif kind == "directory-new":
            p = item["path"]
            if any(f.startswith(p + "/") for f in base_files):
                bad(item, "%s existed at base" % p)
            if sum(1 for f in head_files if f.startswith(p + "/")) < 5:
                bad(item, "%s has fewer than 5 files at head" % p)
        else:
            bad(item, "no audit rule for kind %s" % kind)
    print("audited %s: %d item(s)" % (r["id"], len(r["expected"]["items"])))


def main(argv):
    path = argv[0] if argv else os.path.join(HERE, "ranges.json")
    for r in json.load(open(path))["ranges"]:
        audit(r)
    for p in problems:
        print("UNSUPPORTED " + p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
