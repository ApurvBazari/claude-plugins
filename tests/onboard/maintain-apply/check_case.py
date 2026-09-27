#!/usr/bin/env python3
"""check_case.py — verify one maintain-apply harness case after its headless session(s) ran.

  check_case.py shape <shapes.json> <shape> <work> <maintain-detect.sh>
  check_case.py again <shapes.json> <shape> <work> <snapshot-dir>
  check_case.py lessons <expected-dir> <work> [<snapshot-dir>]
  check_case.py simple <work> <reason>

Prints one ok:/FAIL: line per check and exits 1 on any failure. Every file comparison is against
the base commit (HEAD of the scratch repo) or a byte snapshot, never against model output.
"""
import json
import os
import re
import subprocess
import sys

RUN = ".claude/maintain-run"
failures = []


def check(what, cond, detail=""):
    if cond:
        print("ok: " + what)
    else:
        failures.append(what)
        print("FAIL: %s%s" % (what, (" — " + detail) if detail else ""))


def sh(work, *args):
    return subprocess.run(list(args), cwd=work, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          check=False).stdout.decode()


def head_text(work, path):
    return sh(work, "git", "show", "HEAD:" + path)


def now_text(work, path):
    with open(os.path.join(work, path)) as f:
        return f.read()


def result(work):
    path = os.path.join(work, RUN, "maintain-result.json")
    if not os.path.isfile(path):
        check("result file written", False, path)
        return None
    with open(path) as f:
        res = json.load(f)
    schema = os.path.join(os.path.dirname(__file__), "..", "..", "..", "onboard", "schemas",
                          "maintain-result.json")
    try:
        import jsonschema
        jsonschema.validate(res, json.load(open(schema)))
        check("result validates against maintain-result.json", True)
    except ImportError:
        print("skip: result schema check (jsonschema not installed)")
    except Exception as e:                      # jsonschema.ValidationError or a bad schema path
        check("result validates against maintain-result.json", False, str(e)[:300])
    return res


def changed_tracked(work):
    """Tracked files that differ from HEAD, outside the run folder."""
    out = sh(work, "git", "status", "--porcelain=v1", "--untracked-files=all")
    return sorted(line[3:] for line in out.splitlines() if not line[3:].startswith(RUN))


def edit_ok(before, after, mode, line_re, after_re):
    b, a = before.split("\n"), after.split("\n")
    rx = re.compile(line_re)
    if mode == "replace":
        if len(a) != len(b):
            return False, "line count changed"
        diff = [i for i in range(len(b)) if a[i] != b[i]]
        if len(diff) != 1:
            return False, "%d lines differ" % len(diff)
        return (rx.search(a[diff[0]]) is not None), "changed line: %r" % a[diff[0]]
    if len(a) != len(b) + 1:
        return False, "expected exactly one added line, got %+d" % (len(a) - len(b))
    for k in range(len(a)):
        if a[:k] + a[k + 1:] == b:
            if not rx.search(a[k]):
                return False, "added line %r does not match %s" % (a[k], line_re)
            if after_re and not (k > 0 and re.search(after_re, a[k - 1])):
                return False, "added after %r, expected after /%s/" % (a[k - 1] if k else None, after_re)
            return True, ""
    return False, "the other lines changed"


def check_shape(shapes_json, shape, work, detect):
    spec = json.load(open(shapes_json))["shapes"][shape]
    res = result(work)
    if res is None:
        return
    claude_files = sorted(p for p in sh(work, "git", "ls-files").splitlines()
                          if os.path.basename(p) == "CLAUDE.md")
    if spec["outcome"] == "deferred":
        check("deferred %s" % spec["reason"],
              [(d["id"], d["reason"]) for d in res["deferred"]] == [("D1", spec["reason"])],
              json.dumps(res["deferred"]))
        check("nothing applied or written", res["applied"] == [] and res["filesWritten"] == [],
              json.dumps(res))
        for f in claude_files:
            check("%s byte-identical to base" % f, now_text(work, f) == head_text(work, f))
        check("only the package.json change is in the tree", changed_tracked(work) == [spec["package"]],
              str(changed_tracked(work)))
        return
    f = spec["file"]
    ok, detail = edit_ok(head_text(work, f), now_text(work, f), spec["outcome"], spec["line"],
                         spec.get("after"))
    check("one %s line in %s's own style" % (spec["outcome"], f), ok, detail)
    check("applied D1 in %s" % f, [(a["id"], a["file"]) for a in res["applied"]] == [("D1", f)],
          json.dumps(res["applied"]))
    check("filesWritten lists only %s" % f, res["filesWritten"] == [f], str(res["filesWritten"]))
    check("nothing else changed", changed_tracked(work) == sorted([f, spec["package"]]),
          str(changed_tracked(work)))
    again = os.path.join(work, RUN, "detect-again.json")
    subprocess.run(["bash", detect, "--base", "HEAD", "--out", again], cwd=work, check=False)
    items = json.load(open(again)).get("items", [])
    check("AC11: detect -> apply -> detect has no apply items",
          not [i for i in items if i["disposition"] == "apply"], json.dumps(items))


def snapshot_equal(work, snap):
    for dirpath, _, files in os.walk(snap):
        for name in files:
            rel = os.path.relpath(os.path.join(dirpath, name), snap)
            if now_text(work, rel) != open(os.path.join(dirpath, name)).read():
                return False, rel
    return True, ""


def check_again(shapes_json, shape, work, snap):
    res = result(work)
    if res is None:
        return
    check("AC12: second run applies nothing", res["applied"] == [], json.dumps(res["applied"]))
    check("AC12: the item comes back skipped already-present",
          [(s["id"], s["reason"]) for s in res["skipped"]] == [("D1", "already-present")],
          json.dumps(res["skipped"]))
    check("AC12: second run writes no file", res["filesWritten"] == [], str(res["filesWritten"]))
    ok, rel = snapshot_equal(work, snap)
    check("AC12: tooling byte-identical to after the first run", ok, rel)


LESSON_BLOCK = ("\n<!-- onboard:lessons:start -->\n<!-- lesson:L-file -->\n"
                "- Keep the root CLAUDE.md under 200 lines.\n"
                "  _evidence: owner note (matali run 20260927-0001)_\n"
                "<!-- onboard:lessons:end -->\n")


def check_lessons(expected, work, snap=None):
    res = result(work)
    if res is None:
        return
    status = {}
    for key in ("applied", "deferred", "skipped"):
        for e in res[key]:
            status[e["id"]] = (key, e.get("reason"))
    if snap is None:
        want = {"L-new": ("applied", None), "L-path": ("applied", None), "L-file": ("applied", None),
                "L-dup": ("skipped", "already-present"), "L-near": ("deferred", "possible-duplicate"),
                "L-out": ("deferred", "target-outside-tooling")}
        check("AC13: each lesson's outcome", status == want, json.dumps(status))
        near = [d for d in res["deferred"] if d["id"] == "L-near"]
        check("AC13: the near-duplicate names the existing line",
              bool(near) and near[0].get("existing") == "CLAUDE.md:24", json.dumps(near))
        for name in ("lessons.md", "lessons-lib.md"):
            got = now_text(work, ".claude/rules/" + name)
            check("AC13: .claude/rules/%s byte-exact" % name,
                  got == open(os.path.join(expected, name)).read(), repr(got[:400]))
        check("AC13: file target gets the marker section",
              now_text(work, "CLAUDE.md") == head_text(work, "CLAUDE.md") + LESSON_BLOCK)
        check("AC13: filesWritten", sorted(res["filesWritten"]) ==
              [".claude/rules/lessons-lib.md", ".claude/rules/lessons.md", "CLAUDE.md"],
              str(res["filesWritten"]))
        text = "".join(now_text(work, p) for p in (".claude/rules/lessons.md",
                                                    ".claude/rules/lessons-lib.md", "CLAUDE.md"))
        check("D20/AC13: no machine-local pointer written", "events.jsonl" not in text and "/tmp" not in text)
    else:
        want = {"L-new": ("skipped", "already-present"), "L-path": ("skipped", "already-present"),
                "L-file": ("skipped", "already-present"), "L-dup": ("skipped", "already-present"),
                "L-near": ("deferred", "possible-duplicate"),
                "L-out": ("deferred", "target-outside-tooling")}
        check("AC12: second run — applied come back skipped, deferred stay deferred", status == want,
              json.dumps(status))
        check("AC12: second run writes no file", res["filesWritten"] == [], str(res["filesWritten"]))
        ok, rel = snapshot_equal(work, snap)
        check("AC12: tooling byte-identical to after the first run", ok, rel)


def check_simple(work, reason):
    res = result(work)
    if res is None:
        return
    check("one deferred %s" % reason, [d["reason"] for d in res["deferred"]] == [reason],
          json.dumps(res["deferred"]))
    check("nothing applied, skipped or written",
          res["applied"] == [] and res["skipped"] == [] and res["filesWritten"] == [], json.dumps(res))
    check("CLAUDE.md untouched", now_text(work, "CLAUDE.md") == head_text(work, "CLAUDE.md"))


def main(argv):
    mode = argv[0]
    if mode == "shape":
        check_shape(*argv[1:5])
    elif mode == "again":
        check_again(*argv[1:5])
    elif mode == "lessons":
        check_lessons(argv[1], argv[2], argv[3] if len(argv) > 3 else None)
    elif mode == "simple":
        check_simple(argv[1], argv[2])
    else:
        print("usage: see module docstring", file=sys.stderr)
        return 2
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
