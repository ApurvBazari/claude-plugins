"""maintain-guard (spec § 9, D14, D30): snapshot dirty paths before apply, and after it restore or
report every change outside CLAUDE.md, .claude/rules/** and the --allow paths.

  before [--state <file>]        record dirty/untracked paths + content hashes; print state path
  after --state <file> [--allow <path> | --allow <dir>/]... [--result <out>]
                                 print {schemaVersion, changed, preDirty, violations};
                                 exit 0 (no violations), 3 (some), 2 (bad input). With --result,
                                 also write maintain-result.json there: the entries recorded in
                                 the state by maintain-write.sh, each violation as a deferred
                                 guard-violation, filesWritten = changed, preDirty.
  prefix-ok <dir>/               exit 0 if <dir>/ may be exempted, 2 (with the reason) if not
"""
import hashlib
import json
import os
import posixpath
import subprocess
import sys
import tempfile

CLEAN = "clean"


def _git(top, *args):
    # Literal pathspecs: a Next.js route folder such as `app/[id]/` is a glob that would also
    # match `app/d/`, so a restore of one path could reset a user's dirty sibling.
    return subprocess.run(["git", "--literal-pathspecs", "-c", "core.quotepath=off"] + list(args),
                          cwd=top, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout


def _in_head(top, path):
    """True when HEAD has `path`. With the before-snapshot (every dirty or untracked path), a path
    absent from it and present in HEAD is exactly one that was clean and tracked before apply —
    unlike the index at `after` time, which also holds files staged or force-added during apply."""
    try:
        _git(top, "cat-file", "-e", "HEAD:" + path)
        return True
    except subprocess.CalledProcessError:
        return False


def _top():
    try:
        return _git(os.getcwd(), "rev-parse", "--show-toplevel").decode().strip()
    except (subprocess.CalledProcessError, OSError):
        raise SystemExit(_die("not inside a git work tree"))


def _die(msg):
    sys.stderr.write("maintain-guard: %s\n" % msg)
    return 2


def _hash(top, rel):
    full = os.path.join(top, rel)
    if os.path.islink(full):
        return "link:" + os.readlink(full)
    if not os.path.isfile(full):
        return "-"
    h = hashlib.sha256()
    with open(full, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def snapshot(top):
    """{path: hash} for every dirty or untracked path (renames split into delete + add)."""
    out = _git(top, "status", "--porcelain=v1", "-z", "--no-renames", "--untracked-files=all")
    snap = {}
    for rec in out.decode("utf-8", "surrogateescape").split("\0"):
        if len(rec) > 3:
            snap[rec[3:]] = _hash(top, rec[3:])
    return snap


def is_tooling(path):
    return posixpath.basename(path) == "CLAUDE.md" or path.startswith(".claude/rules/")


def prefix_problem(top, prefix):
    """Why a directory prefix may not be exempted (D30), or None when it may."""
    p = prefix.rstrip("/")
    if p.startswith("./"):
        p = p[2:]
    if p in ("", "."):
        return "the repo root cannot be exempted"
    if not p.startswith(".claude/"):
        return "only a folder under .claude/ can be exempted"
    if p == ".claude/rules" or p.startswith(".claude/rules/"):
        return ".claude/rules/ is tooling and cannot be exempted"
    if _git(top, "ls-files", "-z", "--", p + "/").strip(b"\0"):
        return "%s/ holds a tracked file" % p
    return None


def _rel(top, path):
    return os.path.relpath(os.path.abspath(path), top).replace(os.sep, "/")


def cmd_before(top, argv):
    if argv[:1] == ["--state"] and len(argv) == 2:
        state = os.path.abspath(argv[1])
    elif not argv:
        fd, state = tempfile.mkstemp(prefix="onboard-maintain-guard.", suffix=".json")
        os.close(fd)
    else:
        return _die("usage: before [--state <file>]")
    with open(state, "w") as f:
        json.dump({"top": top, "paths": snapshot(top),
                   "entries": {"applied": [], "deferred": [], "skipped": []}}, f)
    sys.stdout.write(state + "\n")
    return 0


def cmd_after(top, argv):
    state, result_path, files, prefixes, i = None, None, set(), [], 0
    while i < len(argv):
        if argv[i] in ("--state", "--allow", "--result") and i + 1 < len(argv):
            if argv[i] == "--state":
                state = argv[i + 1]
            elif argv[i] == "--result":
                result_path = os.path.abspath(argv[i + 1])
                files.add(_rel(top, argv[i + 1]))
            elif argv[i + 1].endswith("/"):
                prefix = _rel(top, argv[i + 1]).rstrip("/") + "/"
                problem = prefix_problem(top, prefix)
                if problem:
                    return _die("refused --allow %s: %s" % (argv[i + 1], problem))
                prefixes.append(prefix)
            else:
                files.add(_rel(top, argv[i + 1]))
            i += 2
        else:
            return _die("usage: after --state <file> [--allow <path>|<dir>/]... [--result <out>]")
    if not state or not os.path.isfile(state):
        return _die("missing or unreadable --state file")
    with open(state) as f:
        before_state = json.load(f)
    if before_state.get("top") != top:
        return _die("state file was recorded for a different repository")
    before, now = before_state["paths"], snapshot(top)
    changed, pre_dirty, violations = [], [], []
    for path in sorted(set(before) | set(now)):
        if before.get(path, CLEAN) == now.get(path, CLEAN):
            continue
        if is_tooling(path):
            changed.append(path)
            if path in before:
                pre_dirty.append(path)
        elif path in files or any(path.startswith(p) for p in prefixes):
            continue
        elif path not in before and _in_head(top, path):
            _git(top, "restore", "--source=HEAD", "--staged", "--worktree", "--", path)
            violations.append({"path": path, "action": "restored"})
        else:
            violations.append({"path": path, "action": "reported"})
    if result_path:
        entries = before_state.get("entries") or {}
        deferred = list(entries.get("deferred", []))
        for n, v in enumerate(violations, 1):
            deferred.append({"id": "G%d" % n, "reason": "guard-violation",
                             "hint": "inspect %s (%s)" % (v["path"], v["action"]), "path": v["path"]})
        result = {"schemaVersion": 1, "applied": entries.get("applied", []), "deferred": deferred,
                  "skipped": entries.get("skipped", []), "filesWritten": changed,
                  "preDirty": pre_dirty}
        with open(result_path + ".tmp-maintain-guard", "w") as f:
            json.dump(result, f, indent=2)
            f.write("\n")
        os.replace(result_path + ".tmp-maintain-guard", result_path)
    os.unlink(state)
    sys.stdout.write(json.dumps({"schemaVersion": 1, "changed": changed, "preDirty": pre_dirty,
                                 "violations": violations}) + "\n")
    return 3 if violations else 0


def cmd_prefix_ok(top, argv):
    if len(argv) != 1:
        return _die("usage: prefix-ok <dir>/")
    problem = prefix_problem(top, _rel(top, argv[0]).rstrip("/") + "/")
    if problem:
        return _die(problem)
    return 0


def main(argv):
    commands = {"before": cmd_before, "after": cmd_after, "prefix-ok": cmd_prefix_ok}
    if not argv or argv[0] not in commands:
        return _die("usage: maintain-guard.sh before|after|prefix-ok ...")
    return commands[argv[0]](_top(), argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
