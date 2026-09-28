"""maintain-write — the writes onboard:maintain makes through a script instead of the model's tools.

`.claude/` is a protected path in Claude Code: the model's Write/Edit calls there are prompted,
denied (unattended `-p`) or classifier-gated, and allow rules cannot pre-approve them. So the
lesson entries (`.claude/rules/**`, D7) and the result file (usually under `.claude/`, D30) are
written here (owner decision 2026-09-27, narrowing D13). The model still makes every judgement —
targets, duplicates, near-duplicates, styles — and still edits CLAUDE.md script lines itself.

  record --state <file> applied  --id <id> --file <path> --summary <text>
  record --state <file> skipped  --id <id> [--file <path>]
  record --state <file> deferred --id <id> --reason <reason> (--command <cmd> | --hint <text>)
                                 [--summary <text>] [--existing <file:line>]
  record --state <file> item --detect <detect.json> --id <id>     copy a detect defer item
  lesson --id <id> --text <text> --summary <text> --ref <ref> [--paths <glob>... | --file <path>]
  early --out <file> --id <id> --reason bad-input|not-onboarded (--hint <text> | --command <cmd>)

Exit 0 on success (lesson prints {"file": ...}), 2 on bad input, 3 when a lesson id is already
in its destination file.
"""
import json
import os
import posixpath
import re
import sys

import gitview
import lessons

REASONS = frozenset([
    "needs-prompt", "needs-install", "needs-research", "needs-review", "stale-line",
    "stale-reference", "unrecognized-style", "unparsed-ecosystem", "no-matching-section",
    "possible-duplicate", "target-outside-tooling", "not-onboarded", "bad-input", "guard-violation",
])
ITEM_CONTEXT = ("kind", "name", "file", "line", "alsoAt", "path", "mention", "renamedTo", "glob")
LESSON_ID = re.compile(r"^(?!.*--)[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
START, END = "<!-- onboard:lessons:start -->", "<!-- onboard:lessons:end -->"


class Bad(Exception):
    pass


def _opts(argv, valued, multi=()):
    opts, i = {}, 0
    while i < len(argv):
        flag = argv[i]
        if flag in multi:
            vals = []
            i += 1
            while i < len(argv) and not argv[i].startswith("--"):
                vals.append(argv[i])
                i += 1
            if not vals:
                raise Bad("%s needs at least one value" % flag)
            opts[flag] = vals
        elif flag in valued and i + 1 < len(argv):
            opts[flag] = argv[i + 1]
            i += 2
        else:
            raise Bad("unexpected argument: %s" % flag)
    return opts


def _single_line(name, value):
    if not value or "\n" in value or "\r" in value:
        raise Bad("%s must be one non-empty line" % name)
    return value


def _read_raw(path):
    """A file's text with its bytes and line endings exactly as on disk."""
    with open(path, encoding="utf-8", errors="surrogateescape", newline="") as f:
        return f.read()


def write_atomic(path, text):
    # Write through a symlink (CLAUDE.md -> AGENTS.md is common), never over it; bytes as given.
    path = os.path.realpath(path)
    tmp = path + ".tmp-maintain-write"
    with open(tmp, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
        f.write(text)
    os.replace(tmp, path)


def _load_state(path):
    if not path or not os.path.isfile(path):
        raise Bad("missing or unreadable --state file (run maintain-guard.sh before first)")
    with open(path) as f:
        state = json.load(f)
    state.setdefault("entries", {"applied": [], "deferred": [], "skipped": []})
    return state


def _deferred(opts):
    entry = {"id": opts["--id"], "reason": opts.get("--reason", "")}
    if entry["reason"] not in REASONS:
        raise Bad("unknown reason: %s" % entry["reason"])
    if "--command" in opts:
        if not re.match(r"^/onboard:[a-z]+$", opts["--command"]):
            raise Bad("--command must be an /onboard: slash command")
        entry["command"] = opts["--command"]
    elif "--hint" in opts:
        entry["hint"] = _single_line("--hint", opts["--hint"])
    else:
        raise Bad("a deferred entry needs --command or --hint")
    for flag, key in (("--summary", "summary"), ("--existing", "existing"), ("--path", "path")):
        if flag in opts:
            entry[key] = opts[flag]
    return entry


def _from_item(detect_path, item_id):
    with open(detect_path) as f:
        items = json.load(f).get("items", [])
    hits = [i for i in items if i.get("id") == item_id]
    if not hits or hits[0].get("disposition") != "defer":
        raise Bad("%s is not a defer item in %s" % (item_id, detect_path))
    item = hits[0]
    entry = {"id": item["id"], "reason": item["reason"]}
    entry.update((k, item[k]) for k in ("command", "hint") if k in item)
    entry.update((k, item[k]) for k in ITEM_CONTEXT if k in item)
    detail = item.get("name") or item.get("path") or item.get("line") or item.get("file") or ""
    if item["kind"] == "research-stale":
        detail = ", ".join(item.get("dimensions", []))
    entry["summary"] = ("%s: %s" % (item["kind"], detail)).rstrip(": ")
    return entry


def _repo_rel(top, path):
    """A path the model passed (relative, absolute, or via a symlinked prefix such as macOS's
    /var -> /private/var) as the repo-relative form the result carries (§ 6.3)."""
    full = os.path.abspath(path)
    full = os.path.join(os.path.realpath(os.path.dirname(full)), os.path.basename(full))
    rel = os.path.relpath(full, os.path.realpath(top)).replace(os.sep, "/")
    if rel == ".." or rel.startswith("../"):
        raise Bad("path outside the repo: %s" % path)
    return rel


def cmd_record(argv):
    if len(argv) < 3 or argv[0] != "--state":
        raise Bad("usage: record --state <file> applied|skipped|deferred|item ...")
    state_path, kind, rest = argv[1], argv[2], argv[3:]
    state = _load_state(state_path)
    top = state.get("top") or os.getcwd()
    if kind == "applied":
        o = _opts(rest, ("--id", "--file", "--summary"))
        if not all(k in o for k in ("--id", "--file", "--summary")):
            raise Bad("applied needs --id, --file and --summary")
        entry, bucket = {"id": o["--id"], "file": _repo_rel(top, o["--file"]), "summary": o["--summary"]}, "applied"
    elif kind == "skipped":
        o = _opts(rest, ("--id", "--file"))
        if "--id" not in o:
            raise Bad("skipped needs --id")
        entry, bucket = {"id": o["--id"], "reason": "already-present"}, "skipped"
        if "--file" in o:
            entry["file"] = _repo_rel(top, o["--file"])
    elif kind == "deferred":
        o = _opts(rest, ("--id", "--reason", "--command", "--hint", "--summary", "--existing", "--path"))
        if "--id" not in o:
            raise Bad("deferred needs --id")
        entry, bucket = _deferred(o), "deferred"
        path, sep, line = entry.get("existing", "").rpartition(":")
        if sep and path and line.isdigit():
            entry["existing"] = _repo_rel(top, path) + ":" + line
    elif kind == "item":
        o = _opts(rest, ("--detect", "--id"))
        if "--detect" not in o or "--id" not in o:
            raise Bad("item needs --detect and --id")
        entry, bucket = _from_item(o["--detect"], o["--id"]), "deferred"
    else:
        raise Bad("unknown record kind: %s" % kind)
    state["entries"][bucket].append(entry)
    write_atomic(state_path, json.dumps(state))
    return 0


def _is_tooling_target(rel):
    return posixpath.basename(rel) == "CLAUDE.md" or rel.startswith(".claude/rules/")


def _entry(lesson_id, text, summary, ref):
    return "<!-- lesson:%s -->\n- %s\n  _evidence: %s (%s)_\n" % (lesson_id, text, summary, ref)


def _append_block(existing, block):
    """Existing text + one blank line + block (existing entries are never touched)."""
    if existing and not existing.endswith("\n"):
        existing += "\n"
    if existing and not existing.endswith("\n\n"):
        existing += "\n"
    return existing + block


def cmd_lesson(argv):
    o = _opts(argv, ("--id", "--text", "--summary", "--ref", "--file"), multi=("--paths",))
    for key in ("--id", "--text", "--summary", "--ref"):
        if key not in o:
            raise Bad("lesson needs --id, --text, --summary and --ref")
    if not LESSON_ID.match(o["--id"]):
        raise Bad("lesson id is not marker-safe: %s" % o["--id"])
    entry = _entry(o["--id"], _single_line("--text", o["--text"]),
                   _single_line("--summary", o["--summary"]), _single_line("--ref", o["--ref"]))
    top = gitview.toplevel(os.getcwd())
    if "--paths" in o and "--file" in o:
        raise Bad("a lesson has --paths or --file, not both")
    if "--file" in o:
        rel = os.path.relpath(os.path.abspath(o["--file"]), top).replace(os.sep, "/")
        if rel.startswith("../") or not _is_tooling_target(rel):
            raise Bad("target-outside-tooling: %s" % rel)
    elif "--paths" in o:
        rel = lessons.lesson_file(top, o["--paths"])["file"]
    else:
        rel = ".claude/rules/lessons.md"
    full = os.path.join(top, rel)
    existing = _read_raw(full) if os.path.isfile(full) else None
    if existing is not None and ("<!-- lesson:%s -->" % o["--id"]) in existing:
        sys.stderr.write("maintain-write: lesson %s is already in %s\n" % (o["--id"], rel))
        return 3
    # A CRLF file is edited as LF and written back as CRLF, so no existing line changes a byte;
    # any other file is edited as it is (its own endings untouched, new lines end in \n).
    crlf = bool(existing) and "\n" in existing and existing.count("\r\n") == existing.count("\n")
    if crlf:
        existing = existing.replace("\r\n", "\n")
    if "--file" in o:
        text = existing or ""
        if START in text and END in text:
            head, tail = text.rsplit(END, 1)
            body = head.rstrip("\n")
            new = body + ("\n" if body.endswith(START) else "\n\n") + entry + END + tail
        else:
            new = _append_block(text, START + "\n" + entry + END + "\n")
    elif existing is None:
        header = "# Lessons\n\n"
        if "--paths" in o:
            globs = [g.strip() for g in o["--paths"]]
            header = ("---\npaths:\n" + "".join('  - "%s"\n' % g for g in globs)
                      + "---\n\n# Lessons\n\n")
        new = header + entry
    else:
        new = _append_block(existing, entry)
    if crlf:
        new = new.replace("\n", "\r\n")
    parent = os.path.dirname(full)
    if not os.path.isdir(parent):
        os.makedirs(parent)
    write_atomic(full, new)
    sys.stdout.write(json.dumps({"file": rel}) + "\n")
    return 0


def cmd_early(argv):
    o = _opts(argv, ("--out", "--id", "--reason", "--hint", "--command"))
    if "--out" not in o or "--id" not in o or o.get("--reason") not in ("bad-input", "not-onboarded"):
        raise Bad("early needs --out, --id and --reason bad-input|not-onboarded")
    result = {"schemaVersion": 1, "applied": [], "deferred": [_deferred(o)], "skipped": [],
              "filesWritten": [], "preDirty": []}
    write_atomic(os.path.abspath(o["--out"]), json.dumps(result, indent=2) + "\n")
    return 0


def main(argv):
    commands = {"record": cmd_record, "lesson": cmd_lesson, "early": cmd_early}
    if not argv or argv[0] not in commands:
        sys.stderr.write("maintain-write: usage: record|lesson|early ... (see scripts/maintain-write.sh)\n")
        return 2
    try:
        return commands[argv[0]](argv[1:])
    except (Bad, gitview.DetectError, ValueError, KeyError, IOError, OSError) as e:
        sys.stderr.write("maintain-write: %s\n" % e)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
