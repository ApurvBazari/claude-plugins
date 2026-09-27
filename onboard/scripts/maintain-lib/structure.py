"""File-set kinds: config-changed, directory-new, language-new, signal-mcp,
signal-builtin-skill, lessons-large (spec § 6.5)."""
import os
import posixpath

import gitview
from tables import (BUILTIN_SKILL_SIGNALS, CONFIG_PATTERNS, DIRECTORY_NEW_MIN_FILES,
                    LANGUAGES, LESSONS_LARGE_LINES, MCP_SIGNALS, SOURCE_EXTS)
from tooling import read_lines

UPDATE = "/onboard:update"


def _ext(path):
    return posixpath.splitext(path)[1].lower()


def _counted(paths):
    return [p for p in paths if not gitview.is_vendor(p) and not gitview.is_tooling(p)]


def config_changed(ctx):
    files = sorted(set(c.path for c in ctx.changes
                       if any(p.match(posixpath.basename(c.path)) for p in CONFIG_PATTERNS)))
    return [{"kind": "config-changed", "file": f, "disposition": "defer",
             "reason": "needs-review", "command": UPDATE} for f in files]


def directory_new(ctx):
    """The topmost directory absent at base holding >= 5 source files now (recursively) and no
    CLAUDE.md of its own — one item per such directory, not one per nested subdirectory."""
    counts = {}
    for f in _counted(ctx.now_files):
        if _ext(f) not in SOURCE_EXTS:
            continue
        d = posixpath.dirname(f)
        if not d or d in ctx.base_dirs:
            continue
        while posixpath.dirname(d) and posixpath.dirname(d) not in ctx.base_dirs:
            d = posixpath.dirname(d)
        counts[d] = counts.get(d, 0) + 1
    now = set(ctx.now_files)
    return [{"kind": "directory-new", "path": d, "count": n, "disposition": "defer",
             "reason": "needs-prompt", "command": UPDATE}
            for d, n in sorted(counts.items())
            if n >= DIRECTORY_NEW_MIN_FILES and d + "/CLAUDE.md" not in now]


def _language_counts(paths):
    counts = dict((lang, 0) for lang, _, _ in LANGUAGES)
    for p in _counted(paths):
        ext = _ext(p)
        for lang, _, exts in LANGUAGES:
            if ext in exts:
                counts[lang] += 1
    return counts


def language_new(ctx):
    base, now = _language_counts(ctx.base_files), _language_counts(ctx.now_files)
    return [{"kind": "language-new", "name": lang, "count": now[lang], "disposition": "defer",
             "reason": "needs-install", "command": UPDATE}
            for lang, _, _ in LANGUAGES if base[lang] == 0 and now[lang] > 0]


class _TreeView(object):
    def __init__(self, files, dirs, package_text):
        self.files, self.dirs = files, dirs
        self.root_package_text = package_text or ""

    def has_dir(self, p):
        return p in self.dirs

    def has_file(self, p):
        return p in self.files


def signal_mcp(ctx):
    base = _TreeView(set(ctx.base_files), ctx.base_dirs,
                     gitview.show(ctx.top, ctx.base, "package.json"))
    now = _TreeView(set(ctx.now_files), ctx.now_dirs, gitview.read_now(ctx.top, "package.json"))
    return [{"kind": "signal-mcp", "name": server, "signal": signal, "disposition": "defer",
             "reason": "needs-prompt", "command": UPDATE}
            for server, signal, present in MCP_SIGNALS if not present(base) and present(now)]


def signal_builtin_skill(ctx, pc):
    added = set(n for _, n, _ in pc.dep_added)
    items = []
    for skill, deps in BUILTIN_SKILL_SIGNALS:
        hit = sorted(added & deps)
        if hit:
            items.append({"kind": "signal-builtin-skill", "name": skill, "dependency": hit[0],
                          "disposition": "defer", "reason": "needs-prompt", "command": UPDATE})
    return items


def lessons_large(ctx):
    rel = ".claude/rules/lessons.md"
    if not os.path.isfile(os.path.join(ctx.top, rel)):
        return []
    n = len(read_lines(ctx.top, rel))
    if n <= LESSONS_LARGE_LINES:
        return []
    return [{"kind": "lessons-large", "file": rel, "lines": n, "threshold": LESSONS_LARGE_LINES,
             "disposition": "defer", "reason": "needs-review",
             "hint": "prune it, or split it into path-targeted lesson files"}]
