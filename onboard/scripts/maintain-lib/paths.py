"""Path mentions in tooling: extraction and walk-up resolution (D27, § 7.3), breakage (D18),
and the unique-basename recheck key (D28)."""
import os
import posixpath
import re
from collections import Counter

from gitview import is_tooling, is_vendor, parent_dirs
from tables import LOCKFILES, SOURCE_EXTS, TOOL_CONFIG_RE, CONFIG_PATTERNS

_BACKTICK = re.compile(r"`([^`\n]+)`")
_LINE_SUFFIX = re.compile(r":\d+(?:-\d+)?$")


def path_mentions(text):
    """(as written, normalised token) for each backticked token containing '/' — once per line."""
    seen = set()
    out = []
    for span in _BACKTICK.findall(text):
        for raw in span.split():
            written = raw.strip("'\"").lstrip("(").rstrip(".,;:)!?")
            t = written
            if "/" not in t or "://" in t or not t or t[0] in "/~$":
                continue
            if any(c in t for c in "*?[]{}<>|"):
                continue
            t = _LINE_SUFFIX.sub("", t)
            if t.startswith("./"):
                t = t[2:]
            t = t.rstrip("/")
            if t and t not in (".", "..") and t not in seen:
                seen.add(t)
                out.append((written, t))
    return out


class Resolver(object):
    def __init__(self, top, base_files, now_files, changes):
        self.top = top
        self.base_files = set(base_files)
        self.base_dirs = parent_dirs(base_files)
        self.now_files = set(now_files)
        self.now_dirs = parent_dirs(now_files)
        self.deleted = set(c.path for c in changes if c.status == "D")
        self.renames = dict((c.old, c.path) for c in changes if c.status == "R")
        self._base_list = sorted(base_files)

    def existed_at_base(self, p):
        return p in self.base_files or p in self.base_dirs

    def exists_now(self, p):
        return (p in self.now_files or p in self.now_dirs
                or os.path.lexists(os.path.join(self.top, p)))

    def resolve(self, token, holder):
        """D27: from the holder's directory, then each parent, then the root; rules: root only."""
        if holder.startswith(".claude/"):
            dirs = [""]
        else:
            dirs = []
            d = posixpath.dirname(holder)
            while True:
                dirs.append(d)
                if not d:
                    break
                d = posixpath.dirname(d)
        for d in dirs:
            cand = posixpath.normpath(posixpath.join(d, token) if d else token)
            if cand in (".", "..") or cand.startswith("../"):
                continue
            if self.existed_at_base(cand) or self.exists_now(cand):
                return cand
        return None

    def _under(self, files, prefix):
        return [f for f in files if f.startswith(prefix + "/")
                and not is_tooling(f) and not is_vendor(f)]

    def breakage(self, path):
        """(broken, renamedTo) for a resolved path; broken only if it existed at base (D18).

        A file is broken when the diff deletes or renames it. A directory is deleted when no
        non-tooling file is left under it, and renamed when every base file under it was
        renamed under one new prefix with the same relative path.
        """
        if is_tooling(path) or not self.existed_at_base(path):
            return False, None
        if path in self.base_files:
            if path in self.renames:
                return True, self.renames[path]
            return (path in self.deleted), None
        if self._under(self.now_files, path):
            return False, None
        prefixes = set()
        for f in self._under(self._base_list, path):
            g = self.renames.get(f)
            suffix = f[len(path):]
            if g is None or not g.endswith(suffix):
                return True, None
            prefixes.add(g[:len(g) - len(suffix)])
        if len(prefixes) == 1:
            return True, prefixes.pop()
        return True, None


def is_source(path):
    base = posixpath.basename(path)
    ext = posixpath.splitext(base)[1].lower()
    if ext not in SOURCE_EXTS or base in LOCKFILES or TOOL_CONFIG_RE.match(base):
        return False
    return not any(p.match(base) for p in CONFIG_PATTERNS)


def unique_basename_keys(changes, base_files, now_files):
    """D28: basename -> changed path, for changed source files whose basename is unique
    among the files at base and among the files now."""
    at_base = Counter(posixpath.basename(p) for p in base_files)
    at_now = Counter(posixpath.basename(p) for p in now_files)
    keys = {}
    for c in changes:
        for p in ([c.path] + ([c.old] if c.old else [])):
            b = posixpath.basename(p)
            if is_source(p) and at_base[b] <= 1 and at_now[b] <= 1:
                keys.setdefault(b, c.path)
    return keys


def basename_regex(b):
    return re.compile(r"(?<![A-Za-z0-9_.\-])" + re.escape(b)
                      + r"(?![A-Za-z0-9_\-])(?!\.[A-Za-z0-9])")


def path_mention_broken(ctx):
    """D18/D27: one item per (tooling line, resolved path) whose path the diff deleted or renamed."""
    items = []
    for tl in ctx.tlines:
        for written, token in path_mentions(tl.text):
            path = ctx.resolver.resolve(token, tl.file)
            if path is None:
                continue
            broken, renamed_to = ctx.resolver.breakage(path)
            if not broken:
                continue
            item = {"kind": "path-mention-broken", "line": tl.ref, "mention": written,
                    "path": path}
            if renamed_to:
                item["renamedTo"] = renamed_to
            item.update({"disposition": "defer", "reason": "stale-reference",
                         "hint": ("edit by hand: the path was renamed to %s" % renamed_to)
                         if renamed_to else "edit by hand: the path was deleted"})
            items.append(item)
    return items
