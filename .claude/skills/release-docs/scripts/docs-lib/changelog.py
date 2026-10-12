"""CHANGELOG parsing: versions, their entries, and stable entry ids.

An entry is a top-level bullet (`- ` or `* `) with its indented continuation lines, or a standalone
paragraph. `###` headings and blank lines end an entry; they are not entries themselves."""
import hashlib
import re

import repo

HEAD_RE = re.compile(r"^## \[?(\d+)\.(\d+)\.(\d+)\]?")


def vtuple(v):
    """(major, minor, patch, ...) as ints; a non-numeric part (e.g. 1.0.0-beta.1) is bad input."""
    try:
        return tuple(int(x) for x in v.split("."))
    except (AttributeError, ValueError):
        raise repo.RepoError("unparseable version %r: expected numeric MAJOR.MINOR.PATCH"
                             % (v,)) from None


def _walk(text):
    """{version: [(entry text, the `###` heading it sits under, or None)]}, in file order."""
    versions, cur, buf, state = {}, None, [], {"kind": None, "section": None}

    def flush():
        if cur is not None and buf:
            versions[cur].append((" ".join(s for s in buf if s), state["section"]))
        del buf[:]
        state["kind"] = None

    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        m = HEAD_RE.match(line)
        if m:
            flush()
            cur = ".".join(m.groups())
            versions.setdefault(cur, [])
            state["section"] = None
            continue
        if line.startswith("# ") or line.startswith("## "):
            flush()
            cur = None
            continue
        if cur is None:
            continue
        if not line.strip() or line.startswith("#"):
            flush()
            if re.match(r"#{3,}\s", line):
                state["section"] = line.lstrip("#").strip()
        elif re.match(r"[-*] ", line):
            flush()
            buf.append(line[2:].strip())
            state["kind"] = "bullet"
        elif line[:1] in (" ", "\t"):
            if buf:
                buf.append(line.strip())
        else:
            if state["kind"] != "para":
                flush()
                state["kind"] = "para"
            buf.append(line.strip())
    flush()
    return versions


def parse(text):
    """{version: [entry text]}. The section heading is deliberately not part of an entry: ids hash the
    text alone, so moving a bullet between `###` sections never reopens it."""
    return {ver: [t for t, _section in entries] for ver, entries in _walk(text).items()}


def entry_id(plugin, version, text):
    norm = " ".join(text.split())
    return "%s@%s#%s" % (plugin, version, hashlib.sha1(norm.encode("utf-8")).hexdigest()[:8])


def new_entries(plugin, text, base_version):
    """[(id, version, text)] for every version newer than base_version (all when None)."""
    out = []
    for ver, entries in parse(text).items():
        if base_version is None or vtuple(ver) > vtuple(base_version):
            out.extend((entry_id(plugin, ver, e), ver, e) for e in entries)
    return out


def new_sectioned(plugin, text, base_version):
    """new_entries, each with the `###` heading it sits under (None outside one). For stale-mention
    only, where a verbless bullet under `### Removed` is a retirement; the ids are new_entries' own."""
    out = []
    for ver, entries in _walk(text).items():
        if base_version is None or vtuple(ver) > vtuple(base_version):
            out.extend((entry_id(plugin, ver, e), ver, e, s) for e, s in entries)
    return out
