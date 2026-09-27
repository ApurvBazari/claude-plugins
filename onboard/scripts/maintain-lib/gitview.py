"""Read-only git plumbing for maintain-detect: the changed set and the base/now file views."""
import os
import posixpath
import subprocess

from tables import VENDOR_DIRS


class DetectError(Exception):
    """An input problem, reported as the report's error object (exit 2)."""

    def __init__(self, code, message):
        Exception.__init__(self, message)
        self.code = code
        self.message = message


def git(top, *args):
    """Run git in `top`; return stdout as text. Raises CalledProcessError on failure."""
    proc = subprocess.run(
        ["git", "-c", "core.quotepath=off"] + list(args),
        cwd=top, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return proc.stdout.decode("utf-8", "surrogateescape")


def split_z(text):
    return [p for p in text.split("\0") if p]


def toplevel(cwd):
    try:
        return git(cwd, "rev-parse", "--show-toplevel").strip()
    except (subprocess.CalledProcessError, OSError):
        raise DetectError("not-a-repo", "not inside a git work tree: %s" % cwd)


def resolve_commit(top, ref):
    try:
        return git(top, "rev-parse", "--verify", "--quiet", ref + "^{commit}").strip()
    except subprocess.CalledProcessError:
        raise DetectError("bad-ref", "base ref does not resolve to a commit: %s" % ref)


def is_tooling(path):
    """Tooling paths never enter the changed set (spec § 7 step 3)."""
    return (posixpath.basename(path) in ("CLAUDE.md", "CLAUDE.local.md")
            or path == ".claude" or path.startswith(".claude/") or path == ".mcp.json")


def is_vendor(path):
    return any(seg in VENDOR_DIRS for seg in path.split("/")[:-1])


class Change(object):
    """One changed path: status A (added), M (modified), D (deleted) or R (renamed from `old`)."""
    __slots__ = ("status", "path", "old")

    def __init__(self, status, path, old=None):
        self.status = status
        self.path = path
        self.old = old


def _excluded(path):
    return is_tooling(path) or is_vendor(path)


def changed_set(top, base):
    """git diff <base> (working tree incl. staged) + untracked, minus tooling and vendor paths."""
    fields = split_z(git(top, "diff", "--name-status", "-z", "-M", "--no-ext-diff", base))
    raw = []
    i = 0
    while i < len(fields):
        status = fields[i]
        if status[0] in "RC":
            old, new = fields[i + 1], fields[i + 2]
            i += 3
            raw.append(Change("R", new, old) if status[0] == "R" else Change("A", new))
        else:
            raw.append(Change(status[0] if status[0] in "AD" else "M", fields[i + 1]))
            i += 2
    for path in split_z(git(top, "ls-files", "--others", "--exclude-standard", "-z")):
        raw.append(Change("A", path))
    kept = []
    for c in raw:
        if c.status == "R" and (_excluded(c.path) or _excluded(c.old)):
            # A rename across the tooling/vendor boundary keeps only its code-side half.
            if not _excluded(c.path):
                kept.append(Change("A", c.path))
            elif not _excluded(c.old):
                kept.append(Change("D", c.old))
            continue
        if not _excluded(c.path):
            kept.append(c)
    return kept


def base_files(top, base):
    return split_z(git(top, "ls-tree", "-r", "-z", "--name-only", base))


def now_files(top):
    """Tracked + untracked (not ignored) paths that exist in the working tree."""
    listed = split_z(git(top, "ls-files", "-z", "--cached", "--others", "--exclude-standard"))
    return sorted(set(p for p in listed if os.path.lexists(os.path.join(top, p))))


def show(top, base, path):
    """Content of `path` at `base`, or None when it did not exist there."""
    try:
        proc = subprocess.run(["git", "show", "%s:%s" % (base, path)], cwd=top, check=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError:
        return None
    return proc.stdout.decode("utf-8", "replace")


def read_now(top, path):
    try:
        with open(os.path.join(top, path), "rb") as f:
            return f.read().decode("utf-8", "replace")
    except (IOError, OSError):
        return None


def parent_dirs(paths):
    """Every ancestor directory of every path (repo-relative, no trailing slash)."""
    dirs = set()
    for p in paths:
        d = posixpath.dirname(p)
        while d and d not in dirs:
            dirs.add(d)
            d = posixpath.dirname(d)
    return dirs
