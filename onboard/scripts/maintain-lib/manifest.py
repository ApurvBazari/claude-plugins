"""package.json kinds (script-/dependency- added/removed) and manifest-changed (D11, D15, D16)."""
import json
import posixpath

import gitview
import mentions
from tables import MANIFEST_NAMES, MANIFEST_RE

UPDATE = "/onboard:update"


def _parse(text):
    """(object, ok): absent -> ({}, True); invalid JSON or a non-object -> (None, False)."""
    if text is None:
        return {}, True
    try:
        data = json.loads(text)
    except ValueError:
        return None, False
    return (data, True) if isinstance(data, dict) else (None, False)


def _section(data, key):
    value = data.get(key)
    return value if isinstance(value, dict) else {}


def _deps(data):
    merged = dict(_section(data, "devDependencies"))
    merged.update(_section(data, "dependencies"))
    return merged


class PackageChanges(object):
    def __init__(self):
        self.dep_added = []        # (file, name, version)
        self.dep_removed = []      # (file, name)
        self.script_added = []     # (file, package, name, run)
        self.script_removed = []   # (file, package, name)
        self.version_changes = []  # (file, name, base version, now version)
        self.unparsed = []         # package.json paths that did not parse

    @property
    def dep_names(self):
        """Every added or removed dependency name — the recheck name/stem keys."""
        return set(n for _, n, _ in self.dep_added) | set(n for _, n in self.dep_removed)


def package_changes(ctx):
    pc = PackageChanges()
    for c in ctx.changes:
        if posixpath.basename(c.path) != "package.json":
            continue
        base_text = None if c.status == "A" else gitview.show(ctx.top, ctx.base, c.old or c.path)
        now_text = None if c.status == "D" else gitview.read_now(ctx.top, c.path)
        base, ok_base = _parse(base_text)
        now, ok_now = _parse(now_text)
        if not (ok_base and ok_now):
            pc.unparsed.append(c.path)
            continue
        name = now.get("name") if c.status != "D" else base.get("name")
        pkg = name if isinstance(name, str) else None
        base_deps, now_deps = _deps(base), _deps(now)
        for d in sorted(set(now_deps) - set(base_deps)):
            pc.dep_added.append((c.path, d, str(now_deps[d])))
        for d in sorted(set(base_deps) - set(now_deps)):
            pc.dep_removed.append((c.path, d))
        for d in sorted(set(base_deps) & set(now_deps)):
            if base_deps[d] != now_deps[d]:
                pc.version_changes.append((c.path, d, str(base_deps[d]), str(now_deps[d])))
        base_scripts, now_scripts = _section(base, "scripts"), _section(now, "scripts")
        for s in sorted(set(now_scripts) - set(base_scripts)):
            pc.script_added.append((c.path, pkg, s, str(now_scripts[s])))
        for s in sorted(set(base_scripts) - set(now_scripts)):
            pc.script_removed.append((c.path, pkg, s))
    return pc


def dependency_added(ctx, pc):
    items = []
    for file, name, version in pc.dep_added:
        if not mentions.dep_mention_refs(ctx.tlines, name):          # D15
            items.append({"kind": "dependency-added", "name": name, "version": version,
                          "file": file, "disposition": "inform"})
    return items


def dependency_removed(ctx, pc):
    items, seen = [], set()
    for file, name in pc.dep_removed:
        if name in seen:                                              # one per removed name
            continue
        seen.add(name)
        refs = mentions.dep_mention_refs(ctx.tlines, name)
        if refs:
            items.append({"kind": "dependency-removed", "name": name, "file": file,
                          "line": refs[0], "alsoAt": refs[1:], "disposition": "defer",
                          "reason": "stale-line",
                          "hint": "edit by hand: this line names a removed dependency"})
    return items


def _script_refs(ctx, file, pkg, name):
    return mentions.script_mention_refs(ctx.tlines, ctx.packages, name, pkg,
                                        posixpath.dirname(file))


def script_added(ctx, pc):
    items = []
    for file, pkg, name, run in pc.script_added:
        if not _script_refs(ctx, file, pkg, name):                    # D15, D24
            items.append({"kind": "script-added", "name": name, "run": run, "file": file,
                          "package": pkg, "disposition": "apply"})
    return items


def script_removed(ctx, pc):
    items = []
    for file, pkg, name in pc.script_removed:
        refs = _script_refs(ctx, file, pkg, name)
        if refs:
            items.append({"kind": "script-removed", "name": name, "file": file, "package": pkg,
                          "line": refs[0], "alsoAt": refs[1:], "disposition": "defer",
                          "reason": "stale-line",
                          "hint": "edit by hand: this line names a removed script"})
    return items


def manifest_changed(ctx, pc):
    files = list(pc.unparsed)
    for c in ctx.changes:
        base = posixpath.basename(c.path)
        if base in MANIFEST_NAMES or MANIFEST_RE.match(base):
            files.append(c.path)
    return [{"kind": "manifest-changed", "file": f, "disposition": "defer",
             "reason": "unparsed-ecosystem", "command": UPDATE} for f in sorted(set(files))]
