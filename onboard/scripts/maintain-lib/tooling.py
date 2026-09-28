"""Tooling files — every CLAUDE.md and .claude/rules/**/*.md — read from the working tree."""
import os
import posixpath
import re

from gitview import is_vendor

_NEWLINE = re.compile(r"\r\n|\r|\n")


class ToolingLine(object):
    __slots__ = ("file", "n", "text")

    def __init__(self, file, n, text):
        self.file = file
        self.n = n
        self.text = text

    @property
    def ref(self):
        return "%s:%d" % (self.file, self.n)


def split_lines(text):
    """Physical lines without terminators; CRLF, CR and a leading BOM are tolerated."""
    if text.startswith("﻿"):
        text = text[1:]
    lines = _NEWLINE.split(text)
    if lines and lines[-1] == "":
        lines.pop()
    return lines


def read_lines(top, rel):
    try:
        with open(os.path.join(top, rel), "rb") as f:
            return split_lines(f.read().decode("utf-8", "replace"))
    except (IOError, OSError):
        return []


def tooling_files(top, now_files):
    """Root CLAUDE.md first, then nested CLAUDE.md files by path, then rule files by path."""
    claude = [p for p in now_files if posixpath.basename(p) == "CLAUDE.md" and not is_vendor(p)]
    claude.sort(key=lambda p: (p != "CLAUDE.md", p))
    rules = []
    for dirpath, dirnames, filenames in os.walk(os.path.join(top, ".claude", "rules")):
        dirnames.sort()
        for name in sorted(filenames):
            if name.endswith(".md"):
                rules.append(os.path.relpath(os.path.join(dirpath, name), top).replace(os.sep, "/"))
    return claude + sorted(rules)


def load(top, files):
    """Every line of the given tooling files, in file order then line order."""
    out = []
    for rel in files:
        for i, text in enumerate(read_lines(top, rel), 1):
            out.append(ToolingLine(rel, i, text))
    return out


def frontmatter(lines):
    """The lines between a leading '---' fence and the next '---', or []."""
    if not lines or lines[0].strip() != "---":
        return []
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return lines[1:i]
    return []


def _unquote(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1].strip()
    return value


def _split_commas(value):
    """Split on commas outside {...}, so `src/**/*.{ts,tsx}` stays one glob."""
    parts, depth, cur = [], 0, []
    for ch in value:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth = max(0, depth - 1)
        if ch == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    parts.append("".join(cur))
    return parts


def _clean(values):
    return [v for v in (_unquote(x) for x in values) if v]


def paths_field(lines):
    """D31: a rule's `paths:` as a list of globs, or None. No other frontmatter field is read."""
    fm = frontmatter(lines)
    for i, line in enumerate(fm):
        m = re.match(r"^paths\s*:\s*(.*)$", line)
        if not m:
            continue
        rest = m.group(1).strip()
        if rest.startswith("["):
            inner = rest[1:rest.rfind("]")] if "]" in rest else rest[1:]
            return _clean(_split_commas(inner))
        if rest:
            return _clean(_split_commas(_unquote(rest)))
        items = []
        for nxt in fm[i + 1:]:
            item = re.match(r"^\s*-\s*(.*)$", nxt)
            if item:
                items.append(item.group(1))
            elif nxt.strip() and not nxt[0].isspace():
                break
        return _clean(items)
    return None
