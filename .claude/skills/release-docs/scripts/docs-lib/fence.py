"""The write fence (release-docs spec § 6): the only barrier between an unattended apply and CI's
`git add -A`. It must not be widenable, bypassable, or able to destroy the owner's work, so:

- the allowlist comes from docs-surfaces.json and the marketplace as committed at the snapshot's
  HEAD, never from the working tree the run may have edited (surfaces.allowlist_at). If it cannot
  be built for any reason, the fence still runs, against the static minimum;
- the order is: ignore rules, then reverts, then diagnostics. Every .gitignore the run changed or
  created is put back first, so `git status` is read under the original rules and an owner's
  ignored file can never look like a new run file. The reverts come before anything that parses
  run-written content, and a diagnostic that crashes becomes a FAIL line;
- `git status --porcelain -z` is parsed, never the quoted text form, so every file name is the path
  it names; git takes paths literally, so a file named `*` is not a pathspec;
- only regular files may change. A symlink, FIFO, device, directory or type change the run left
  anywhere — an allowed path included — is reverted and fails. Nothing is ever read or hashed
  through a symlink, and nothing but a regular file is ever opened;
- the snapshot (--snapshot, never overwritten) records each path dirty before the run with a digest
  of its content. Such a path is never restored or removed: the run changing one outside the
  allowlist fails, and is left for the owner. --expect-clean (CI) requires an empty snapshot at
  HEAD, so a snapshot re-taken after the apply cannot pass the run's files off as the owner's.

`--fence` prints its report lines, then a last line `FENCE-COMPLETE <ok|fail|untrusted>`; without
that line (a crash, exit 2) the fence did not complete, and the tree must not be trusted.
"""
import hashlib
import json
import os
import shutil
import stat
import subprocess

import repo
import surfaces

KIND = "release-docs-snapshot"
MARKER = "FENCE-COMPLETE"
MUTABLE = ("og", "retired")  # the only docs-surfaces.json keys a run may change


class Incomplete(Exception):
    """The fence cannot finish safely. docs-detect exits 2: do not trust or commit this tree."""


def describe(e):
    return "%s: %s" % (type(e).__name__, str(e)[:300])


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


def kind(ctx, rel):
    """What the working tree holds at rel, as git sees it: never following a symlink, and "absent"
    when a parent directory is itself a symlink (git does not look through one either)."""
    p = ctx.path(rel.rstrip("/"))
    parent = os.path.dirname(rel.rstrip("/"))
    root = os.path.realpath(ctx.root)
    try:
        if os.path.realpath(os.path.dirname(p)) != (os.path.join(root, parent) if parent else root):
            return "absent"
        m = os.lstat(p).st_mode
    except (FileNotFoundError, NotADirectoryError):
        return "absent"
    if stat.S_ISREG(m):
        return "file"
    if stat.S_ISLNK(m):
        return "symlink"
    if stat.S_ISDIR(m):
        return "dir"
    if stat.S_ISFIFO(m):
        return "FIFO"
    return "special file"


def digest(ctx, rel):
    k = kind(ctx, rel)
    if k == "symlink":
        return "link:" + os.readlink(ctx.path(rel.rstrip("/")))
    if k != "file":
        return k  # absent, dir, FIFO, special file: never opened
    h = hashlib.sha256()
    fd = os.open(ctx.path(rel), os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    with os.fdopen(fd, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def snapshot(ctx, out_path):
    """Write the pre-run snapshot: HEAD plus every dirty path's status and content digest. It is
    taken once: an existing file is never overwritten (O_EXCL), so a run cannot re-take it."""
    entries = {rel: {"xy": xy, "digest": digest(ctx, rel)} for xy, rel in status(ctx)}
    doc = {"schemaVersion": 1, "kind": KIND, "head": head(ctx), "entries": entries}
    try:
        fd = os.open(out_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    except FileExistsError:
        raise repo.RepoError("snapshot %s already exists: a snapshot is taken once, before the "
                             "apply, and never overwritten" % out_path) from None
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=1, sort_keys=True)
        f.write("\n")


def load_snapshot(path):
    how = "take one with post-checks.sh --snapshot FILE before the apply"
    try:
        if not stat.S_ISREG(os.stat(path).st_mode):
            raise repo.RepoError("not a regular file")
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
    except (OSError, ValueError, repo.RepoError) as e:
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


def _is_ignore_file(rel):
    return rel.rsplit("/", 1)[-1] == ".gitignore"


def _revert(ctx, rel, tracked, owned):
    """Put a run-made change back: whatever the run left at rel goes, then HEAD's version returns
    (tracked) or the index entry goes (new). None, or why it failed. `owned` holds the snapshot's
    paths: a directory holding any of them is never removed. The kind is read now, not when the
    path was listed: reverting a parent (a directory the run put where a file was) may already
    have taken it away."""
    path = ctx.path(rel.rstrip("/"))
    k = kind(ctx, rel)
    try:
        if k == "dir" and not tracked:
            # A `?? dir/` entry is a nested repository. Only its .git goes: the files then show one
            # by one, and anything the ignore rules hide (possibly the owner's) stays.
            inner = os.path.join(path, ".git")
            if os.path.isdir(inner) and not os.path.islink(inner):
                shutil.rmtree(inner)
            elif os.path.lexists(inner):
                os.remove(inner)
            return None
        if k == "dir":
            prefix = rel.rstrip("/") + "/"
            if any(o.startswith(prefix) for o in owned):
                return "it holds files that were dirty before the run"
            shutil.rmtree(path)
        elif k != "absent" and (k != "file" or not tracked):
            os.remove(path)  # a symlink, FIFO, device or new file: the link itself, never its target
    except OSError as e:
        return str(e)
    if tracked:
        p = _git(ctx, "checkout", "-q", "HEAD", "--", rel)
        if p.returncode != 0:
            return _err(p) or "git checkout failed"
    else:
        _git(ctx, "rm", "-q", "--cached", "--ignore-unmatch", "--", rel)
    return None


def _restore_ignores(ctx, before, owner_dirty, tree):
    """Put every .gitignore back as HEAD has it, before anything else reads `git status`: under the
    run's rules an owner's ignored file looks new, and the fence would delete it. A restored rule
    can reveal another new .gitignore, so it repeats until none is left."""
    lines = []
    for _pass in range(10):
        cur = {rel: xy for xy, rel in status(ctx) if _is_ignore_file(rel)}
        todo = []
        for rel in sorted(set(cur) | {k for k in before if _is_ignore_file(k)}):
            if owner_dirty(rel):
                rec = before.get(rel)
                if rec is None or (cur.get(rel, ""), digest(ctx, rel)) != (rec["xy"], rec["digest"]):
                    raise Incomplete("the run changed %s, which was already dirty before it: the "
                                     "original ignore rules are unknown, so no file can be removed "
                                     "safely" % show(rel))
                continue
            todo.append(rel)
        if not todo:
            return lines
        for rel in todo:
            tracked = rel in tree
            why = _revert(ctx, rel, tracked, before)
            if why:
                raise Incomplete("could not put back %s: %s" % (show(rel), why))
            lines.append("- FAIL: the run %s %s (%s); ignore files are never doc surfaces"
                         % ("changed" if tracked else "created", show(rel),
                            "restored" if tracked else "removed"))
    raise Incomplete("ignore files were still changing after 10 passes")


def _odd(xy, k):
    return "T" in xy or k not in ("file", "absent")


def _revert_run_changes(ctx, allow, before, owner_dirty, tree):
    """Revert every run-made change outside the allowlist, and every non-regular one anywhere."""
    lines, handled = [], set()
    for _pass in range(5):
        todo = []
        for xy, rel in status(ctx):
            if rel in handled or owner_dirty(rel):
                continue
            k = kind(ctx, rel)
            if _odd(xy, k) or not allow(rel):
                todo.append((rel, k, _odd(xy, k)))
        if not todo:
            break
        for rel, k, odd in sorted(todo):
            handled.add(rel)
            tracked = rel in tree
            why = _revert(ctx, rel, tracked, before)
            if why:
                lines.append("- FAIL: the fence could not %s %s: %s"
                             % ("restore" if tracked else "remove", show(rel), why))
            elif odd and k == "dir" and not tracked:
                lines.append("- FAIL: the run left a nested repository at %s (its .git removed; "
                             "its files are fenced one by one)" % show(rel))
            elif odd:
                what = {"file": "type change", "absent": "type change", "dir": "directory"}.get(k, k)
                lines.append("- FAIL: the run left a %s at %s (%s); only regular files may change"
                             % (what, show(rel), "restored" if tracked else "removed"))
            elif tracked:
                lines.append("- FENCE: restored %s (outside the doc surfaces)" % show(rel))
            else:
                lines.append("- FENCE: removed new file %s (outside the doc surfaces)" % show(rel))
    return lines


def _plain(ctx, rel):
    """A regular file reached through no symlink: the only kind of file the fence ever reads."""
    return kind(ctx, rel) == "file"


def surfaces_drift(ctx, ref):
    """Report lines when the run changed docs-surfaces.json beyond og and retired."""
    try:
        raw = ctx.show(ref, surfaces.SURFACES)
        was = json.loads(raw) if raw is not None else None
    except Exception:  # an unreadable committed config: the allowlist has already failed on it
        was = None
    if not isinstance(was, dict):
        return []
    k = kind(ctx, surfaces.SURFACES)
    if k == "absent":
        return ["- FAIL: the run deleted %s" % surfaces.SURFACES]
    if not _plain(ctx, surfaces.SURFACES):
        return ["- FAIL: the run left %s a %s; it must stay a regular file"
                % (surfaces.SURFACES, k)]
    try:
        now = json.loads(ctx.read(surfaces.SURFACES))
    except (OSError, ValueError, RecursionError) as e:
        return ["- FAIL: the run left %s unreadable (%s); only og and retired may change"
                % (surfaces.SURFACES, describe(e))]
    if not isinstance(now, dict):
        return ["- FAIL: the run left %s not a JSON object" % surfaces.SURFACES]
    changed = sorted(k for k in set(was) | set(now) if k not in MUTABLE and was.get(k) != now.get(k))
    if not changed:
        return []
    return ["- FAIL: the run changed %s key(s) %s; only og and retired may change"
            % (surfaces.SURFACES, ", ".join(changed))]


def fence(ctx, before_path, expect_clean=False):
    """Run the fence. Returns (report lines, verdict: ok | fail | untrusted). Raises when it cannot
    complete; the caller turns that into exit 2 with no FENCE-COMPLETE line."""
    snap = load_snapshot(before_path)
    before, ref = snap["entries"], snap["head"]
    dirs = [k for k in before if k.endswith("/")]

    def owner_dirty(rel):
        return rel in before or any(rel.startswith(d) for d in dirs)

    lines = []
    # 1. The allowlist, from the snapshot's HEAD. Any failure at all falls back to the minimum.
    try:
        allow = surfaces.allowlist_at(ctx, ref)
    except Exception as e:
        allow = surfaces.Allowlist()
        lines.append("- FAIL: the fence allowlist could not be built (%s); fenced against the "
                     "static minimum: %s" % (describe(e), ", ".join(surfaces.EXTRA_ALLOWED)))
    tree = _tree(ctx, "HEAD")
    # 2. The original ignore rules, then 3. the reverts. Nothing run-written is parsed before this.
    lines += _restore_ignores(ctx, before, owner_dirty, tree)
    lines += _revert_run_changes(ctx, allow, before, owner_dirty, tree)

    # 4. Diagnostics, each of which fails on its own rather than crashing the fence.
    untrusted = []

    def check(name, fn):
        try:
            return fn()
        except Exception as e:
            return ["- FAIL: the %s check could not complete (%s)" % (name, describe(e))]

    def head_moved():
        now_head = head(ctx)
        if now_head == ref:
            return []
        untrusted.append("head")
        return ["- FAIL: HEAD moved during the run (%s -> %s); a run must not commit, and the "
                "fence cannot see committed changes" % (ref[:7], now_head[:7])]

    def owner_touched():
        out, now = [], {rel: xy for xy, rel in status(ctx)}
        for rel in sorted(set(now) | {k for k in before if not k.endswith("/")}):
            rec = before.get(rel)
            if rec is not None and not allow(rel) \
                    and (now.get(rel, ""), digest(ctx, rel)) != (rec["xy"], rec["digest"]):
                out.append("- FAIL: run touched an owner-dirty file: %s (outside the doc surfaces; "
                           "left as it is for the owner)" % show(rel))
        return out

    def clean_snapshot():
        if not expect_clean or not before:
            return []
        untrusted.append("entries")
        shown = ", ".join(show(k) for k in sorted(before)[:5]) + (", …" if len(before) > 5 else "")
        return ["- FAIL: --expect-clean: the snapshot lists %d dirty path(s) (%s), but CI starts "
                "from a fresh checkout; the snapshot is not trusted" % (len(before), shown)]

    lines += check("HEAD", head_moved)
    lines += check("docs-surfaces.json", lambda: surfaces_drift(ctx, ref))
    lines += check("owner-file", owner_touched)
    lines += check("--expect-clean", clean_snapshot)

    # 5. Trust the result, not the actions: anything still outside the fence is reported.
    for xy, rel in status(ctx):
        if not owner_dirty(rel) and (_odd(xy, kind(ctx, rel)) or not allow(rel)):
            lines.append("- FAIL: still outside the doc surfaces after the fence: %s" % show(rel))
    if expect_clean and untrusted:
        return lines, "untrusted"
    if not lines:
        return ["- ok: write fence"], "ok"
    return lines, "fail"


def render_pages(ctx):
    """The changed site pages to render: the landing page and each plugin's page (from HEAD's
    config), minus frozen paths. Never og-card.html, which is a 1200px card, not a page."""
    surf = surfaces.load_at(ctx, "HEAD")
    pages = {surf["landing"]} | {surfaces.page_of(surf, p["name"]) for p in ctx.plugins_at("HEAD")}
    frozen = [surfaces.globre(f) for f in surf["frozen"]]
    changed = {rel for _xy, rel in status(ctx)}
    return sorted(r for r in pages & changed
                  if _plain(ctx, r) and not any(f.match(r) for f in frozen))
