"""Mention matching shared by detect and apply.

Dependencies (D21): the name as a whole word, case-insensitive.
Scripts (D24): the one mention predicate — the script name as a whole token on a line with
a JS runner word; a package selector on the line must name the item's package; a line without
one counts for the package nearest the file holding it (spec § 7.2).
"""
import fnmatch
import json
import os
import posixpath
import re

from gitview import is_vendor
from tables import RUNNERS


def dep_regex(name):
    return re.compile(r"(?<![A-Za-z0-9_@/.\-])" + re.escape(name)
                      + r"(?![A-Za-z0-9_\-/])(?!\.[A-Za-z0-9])", re.IGNORECASE)


def dep_mention_refs(tlines, name):
    rx = dep_regex(name)
    return [tl.ref for tl in tlines if rx.search(tl.text)]


class Package(object):
    __slots__ = ("name", "dir", "manifest")

    def __init__(self, name, dir, manifest):
        self.name = name
        self.dir = dir
        self.manifest = manifest


def load_packages(top, now_files):
    """Every package.json outside vendor dirs, plus a nameless root entry if the root has none."""
    pkgs = []
    for p in now_files:
        if posixpath.basename(p) != "package.json" or is_vendor(p):
            continue
        name = None
        try:
            with open(os.path.join(top, p)) as f:
                data = json.load(f)
            if isinstance(data, dict) and isinstance(data.get("name"), str):
                name = data["name"]
        except (ValueError, IOError, OSError):
            pass
        pkgs.append(Package(name, posixpath.dirname(p), p))
    if not any(pk.dir == "" for pk in pkgs):
        pkgs.append(Package(None, "", None))
    return pkgs


def holder_dir(packages, tooling_file):
    """Rule 3: the directory of the package nearest the file; root for CLAUDE.md and rules."""
    if tooling_file == "CLAUDE.md" or tooling_file.startswith(".claude/"):
        return ""
    d = posixpath.dirname(tooling_file)
    best = ""
    for pk in packages:
        if pk.dir and (d == pk.dir or d.startswith(pk.dir + "/")) and len(pk.dir) > len(best):
            best = pk.dir
    return best


_SPLIT = re.compile(r"[\s`'\"]+")
_LEAD = "([{"
_TRAIL = ")]}.,;:!?"
_VALUE_FLAGS = ("--filter", "-F", "--workspace")
_ROOT = "\0root"


def tokens(text):
    """Whole tokens: split on whitespace, backticks and quotes; `:` stays inside a name."""
    out = []
    for raw in _SPLIT.split(text):
        t = raw.lstrip(_LEAD).rstrip(_TRAIL)
        if t:
            out.append(t)
    return out


def _selectors(toks):
    """(selector values, token indexes the selectors consumed, recursive flag seen)."""
    sels, used, recursive = [], set(), False
    pnpm = "pnpm" in toks
    i = 0
    while i < len(toks):
        t = toks[i]
        if (t in _VALUE_FLAGS or (t == "-w" and not pnpm)) and i + 1 < len(toks):
            sels.append(toks[i + 1])
            used.update((i, i + 1))
            i += 2
            continue
        if t == "-w" and pnpm:              # pnpm -w is --workspace-root
            sels.append(_ROOT)
            used.add(i)
        elif t.startswith("--filter=") or t.startswith("--workspace="):
            sels.append(t.split("=", 1)[1])
            used.add(i)
        elif t in ("-r", "--recursive"):
            recursive = True
            used.add(i)
        elif t == "workspace" and i > 0 and toks[i - 1] == "yarn" and i + 1 < len(toks):
            sels.append(toks[i + 1])
            used.update((i, i + 1))
            i += 2
            continue
        i += 1
    return sels, used, recursive


def _names(selector, pkg_name, pkg_dir):
    """Does one selector name the package, by its name or its directory (globs allowed)?"""
    if selector == _ROOT:
        return pkg_dir == ""
    s = selector
    if s.startswith("!"):
        return False
    for _ in range(2):                      # pnpm graph forms: foo... ...foo ^...foo {./dir}
        if s.startswith("..."):
            s = s[3:]
        if s.endswith("..."):
            s = s[:-3]
        s = s.strip("^")
        if s.startswith("{") and s.endswith("}"):
            s = s[1:-1]
    if s.startswith("./"):
        s = s[2:]
    s = s.rstrip("/")
    if s in ("", "."):
        return pkg_dir == ""
    for cand in (pkg_name, pkg_dir):
        if cand and (s == cand or fnmatch.fnmatchcase(cand, s)):
            return True
    return False


def line_mentions_script(text, script, pkg_name, pkg_dir, holder):
    toks = tokens(text)
    if not any(t in RUNNERS for t in toks):
        return False
    sels, used, recursive = _selectors(toks)
    if not any(t == script for i, t in enumerate(toks) if i not in used and t not in RUNNERS):
        return False
    if sels:
        return any(_names(s, pkg_name, pkg_dir) for s in sels)
    if recursive:
        return True
    return pkg_dir is not None and holder == pkg_dir


def script_mention_refs(tlines, packages, script, pkg_name, pkg_dir):
    holders = {}
    refs = []
    for tl in tlines:
        if tl.file not in holders:
            holders[tl.file] = holder_dir(packages, tl.file)
        if line_mentions_script(tl.text, script, pkg_name, pkg_dir, holders[tl.file]):
            refs.append(tl.ref)
    return refs


def package_dir_for(packages, name, manifest):
    """The item's package directory: from --manifest, else by name, else root for `-`."""
    if manifest:
        return posixpath.dirname(manifest)
    if name is None:
        return ""
    for pk in packages:
        if pk.name == name:
            return pk.dir
    return None
