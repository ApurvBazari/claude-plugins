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


def parse(text):
    versions, cur, buf, state = {}, None, [], {"kind": None}

    def flush():
        if cur is not None and buf:
            versions[cur].append(" ".join(s for s in buf if s))
        del buf[:]
        state["kind"] = None

    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        m = HEAD_RE.match(line)
        if m:
            flush()
            cur = ".".join(m.groups())
            versions.setdefault(cur, [])
            continue
        if line.startswith("# ") or line.startswith("## "):
            flush()
            cur = None
            continue
        if cur is None:
            continue
        if not line.strip() or line.startswith("#"):
            flush()
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
