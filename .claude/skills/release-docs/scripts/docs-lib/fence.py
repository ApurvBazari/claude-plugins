"""The write fence (release-docs spec § 6): the only barrier between an unattended apply and CI's
`git add -A`. It must not be widenable, bypassable, or able to destroy the owner's work, so:

- the allowlist comes from docs-surfaces.json and the marketplace as committed at the snapshot's
  HEAD, never from the working tree the run may have edited (surfaces.allowlist_at);
- `git status --porcelain -z` is parsed, never the quoted text form, so every file name — spaces,
  " -> ", quotes, backslashes, newlines, non-ASCII — is the path it names; git is told to take
  paths literally, so a file named `*` is not a pathspec;
- the snapshot (--snapshot) records each path dirty before the run with a digest of its content.
  Such a path is never restored or removed: when the run changed it outside the allowlist, that is
  reported as a failure and left for the owner.
"""
import hashlib
import json
import os
import shutil
import subprocess

import repo
import surfaces

KIND = "release-docs-snapshot"
MUTABLE = ("og", "retired")  # the only docs-surfaces.json keys a run may change


def _git(ctx, *args):
    return subprocess.run(["git", "--literal-pathspecs"] + list(args), cwd=ctx.root,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def _err(p):
    return p.stderr.decode("utf-8", "replace").strip()


def show(rel):
    """A path for the report: as-is when printable, else JSON-quoted so it stays on one line."""
    s = rel.encode("utf-8", "surrogateescape").decode("utf-8", "backslashreplace")
    return s if s.isprintable() else json.dumps(s, ensure_ascii=False)


def head(ctx):
    p = _git(ctx, "rev-parse", "--verify", "--quiet", "HEAD^{commit}")
    if p.returncode != 0:
        raise repo.RepoError("no HEAD commit")
    return p.stdout.decode("ascii").strip()


def status(ctx):
    """[(XY, path)] for every changed, staged or untracked path. Renames are off, so a rename is a
    deletion plus an addition; a rename record, should one appear anyway, yields both its paths."""
    p = _git(ctx, "status", "--porcelain", "-z", "--untracked-files=all", "--no-renames")
    if p.returncode != 0:
        raise repo.RepoError("git status failed: %s" % _err(p))
    fields, out, i = p.stdout.split(b"\0"), [], 0
    while i < len(fields):
        rec, i = fields[i], i + 1
        if len(rec) < 4:
            continue  # the empty field after the last NUL
        xy = rec[:2].decode("ascii", "replace")
        out.append((xy, os.fsdecode(rec[3:])))
        if ("R" in xy or "C" in xy) and i < len(fields):
            out.append((xy, os.fsdecode(fields[i])))
            i += 1
    return out


def digest(ctx, rel):
    p = ctx.path(rel)
    if os.path.islink(p):
        return "link:" + os.readlink(p)
    if os.path.isdir(p):
        return "dir"
    if not os.path.exists(p):
        return "absent"
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def snapshot(ctx, out_path):
    """Write the pre-run snapshot: HEAD plus every dirty path's status and content digest."""
    entries = {rel: {"xy": xy, "digest": digest(ctx, rel)} for xy, rel in status(ctx)}
    doc = {"schemaVersion": 1, "kind": KIND, "head": head(ctx), "entries": entries}
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=1, sort_keys=True)
        f.write("\n")


def load_snapshot(path):
    how = "take one with post-checks.sh --snapshot FILE before the apply"
    try:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
    except (OSError, ValueError) as e:
        raise repo.RepoError("--before %s is not a post-checks snapshot (%s); %s" % (path, e, how))
    ents = d.get("entries") if isinstance(d, dict) else None
    if not (isinstance(ents, dict) and d.get("kind") == KIND and d.get("schemaVersion") == 1
            and isinstance(d.get("head"), str)
            and all(isinstance(v, dict) and isinstance(v.get("xy"), str)
                    and isinstance(v.get("digest"), str) for v in ents.values())):
        raise repo.RepoError("--before %s is not a post-checks snapshot; %s" % (path, how))
    return d


def _tree(ctx, ref):
    p = _git(ctx, "ls-tree", "-r", "-z", "--name-only", ref)
    if p.returncode != 0:
        raise repo.RepoError("git ls-tree %s failed: %s" % (ref, _err(p)))
    return {os.fsdecode(x) for x in p.stdout.split(b"\0") if x}


def surfaces_drift(ctx, ref):
    """Report lines when the run changed docs-surfaces.json beyond og and retired."""
    raw = ctx.show(ref, surfaces.SURFACES)
    try:
        was = json.loads(raw) if raw is not None else None
    except ValueError:
        was = None
    if not isinstance(was, dict):
        return []  # nothing to compare with; the allowlist has already failed on it
    if not ctx.exists(surfaces.SURFACES):
        return ["- FAIL: the run deleted %s" % surfaces.SURFACES]
    try:
        now = json.loads(ctx.read(surfaces.SURFACES))
    except (OSError, ValueError) as e:
        return ["- FAIL: the run left %s unreadable (%s); only og and retired may change"
                % (surfaces.SURFACES, e)]
    if not isinstance(now, dict):
        return ["- FAIL: the run left %s not a JSON object" % surfaces.SURFACES]
    changed = sorted(k for k in set(was) | set(now) if k not in MUTABLE and was.get(k) != now.get(k))
    if not changed:
        return []
    return ["- FAIL: the run changed %s key(s) %s; only og and retired may change"
            % (surfaces.SURFACES, ", ".join(changed))]


def _revert(ctx, rel, tracked):
    """Put a run-made change back: restore a HEAD path, remove a new one. None, or why it failed."""
    if tracked:
        p = _git(ctx, "checkout", "-q", "HEAD", "--", rel)
        if p.returncode != 0:
            return _err(p) or "git checkout failed"
        return None
    _git(ctx, "rm", "-q", "--cached", "--ignore-unmatch", "--", rel)
    path = ctx.path(rel)
    try:
        if os.path.islink(path) or os.path.isfile(path):
            os.remove(path)
        elif os.path.isdir(path):
            shutil.rmtree(path)
    except OSError as e:
        return str(e)
    return None


def fence(ctx, before_path):
    """Run the fence. Returns (report lines, exit code): 0 clean, 1 anything fenced or failed."""
    snap = load_snapshot(before_path)
    before = snap["entries"]
    dirs = [k for k in before if k.endswith("/")]

    def owner_dirty(rel):
        return rel in before or any(rel.startswith(d) for d in dirs)

    lines = []
    ref, now_head = snap["head"], head(ctx)
    if now_head != ref:
        lines.append("- FAIL: HEAD moved during the run (%s -> %s); a run must not commit, and the "
                     "fence cannot see committed changes" % (ref[:7], now_head[:7]))
    try:
        allow = surfaces.allowlist_at(ctx, ref)
    except repo.RepoError as e:
        allow = surfaces.Allowlist()
        lines.append("- FAIL: the fence allowlist could not be built (%s); fenced against the "
                     "static minimum: %s" % (e, ", ".join(surfaces.EXTRA_ALLOWED)))
    lines += surfaces_drift(ctx, ref)

    # Owner-dirty paths: compared with the snapshot, never reverted.
    now = dict((rel, xy) for xy, rel in status(ctx))
    for rel in sorted(set(now) | {k for k in before if not k.endswith("/")}):
        rec = before.get(rel)
        if rec is not None and not allow(rel) \
                and (now.get(rel, ""), digest(ctx, rel)) != (rec["xy"], rec["digest"]):
            lines.append("- FAIL: run touched an owner-dirty file: %s (outside the doc surfaces; "
                         "left as it is for the owner)" % show(rel))

    # Run-made paths outside the allowlist: reverted. Restoring a file such as .gitignore can make
    # hidden ones visible, so it repeats until nothing new turns up.
    tree, handled = _tree(ctx, "HEAD"), set()
    for _pass in range(5):
        todo = sorted({rel for _xy, rel in status(ctx)
                       if rel not in handled and not allow(rel) and not owner_dirty(rel)})
        if not todo:
            break
        for rel in todo:
            handled.add(rel)
            tracked = rel in tree
            why = _revert(ctx, rel, tracked)
            if why:
                lines.append("- FAIL: the fence could not %s %s: %s"
                             % ("restore" if tracked else "remove", show(rel), why))
            elif tracked:
                lines.append("- FENCE: restored %s (outside the doc surfaces)" % show(rel))
            else:
                lines.append("- FENCE: removed new file %s (outside the doc surfaces)" % show(rel))

    # Trust the result, not the actions: anything still outside the fence is reported.
    for rel in sorted({rel for _xy, rel in status(ctx) if not allow(rel) and not owner_dirty(rel)}):
        lines.append("- FAIL: still outside the doc surfaces after the fence: %s" % show(rel))
    if not lines:
        return ["- ok: write fence"], 0
    return lines, 1


def render_pages(ctx):
    """The changed site pages to render: the landing page and each plugin's page (from HEAD's
    config), minus frozen paths. Never og-card.html, which is a 1200px card, not a page."""
    surf = surfaces.load_at(ctx, "HEAD")
    pages = {surf["landing"]} | {surfaces.page_of(surf, p["name"]) for p in ctx.plugins_at("HEAD")}
    frozen = [surfaces.globre(f) for f in surf["frozen"]]
    changed = {rel for _xy, rel in status(ctx)}
    return sorted(r for r in pages & changed
                  if os.path.isfile(ctx.path(r)) and not any(f.match(r) for f in frozen))
