#!/usr/bin/env python3
"""corpus_ranges.py — load maintain-corpus/ranges.json with each range's repo resolved locally.

ranges.json is tracked, so it names no machine and no project: a range's `repo` is an alias, and an
expected item may carry a `<token>` where the real repo's own name appears in a path. Both resolve
through repos.local.json, which is gitignored and exists only on a machine that holds the repos:

    {"repos": {"monorepo-a": "~/path/to/that/repo"}, "tokens": {"<android-a-pkg>": "segment"}}

(repos.local.example.json shows the shape.) An alias the map does not name resolves to None, and the
callers treat that range as not on this machine: skipped, or a failure under MAINTAIN_CORPUS_REQUIRED=1.

Usage:
  corpus_ranges.py list               id|repo|base|head|restoreTooling per range (repo empty if unmapped)
  corpus_ranges.py expected <id>      the range's expected object, tokens filled in, as JSON
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RANGES = os.path.join(HERE, "ranges.json")
LOCAL = os.path.join(HERE, "repos.local.json")


def local_map(path=LOCAL):
    if not os.path.isfile(path):
        return {"repos": {}, "tokens": {}}
    data = json.load(open(path, encoding="utf-8"))
    return {"repos": data.get("repos") or {}, "tokens": data.get("tokens") or {}}


def fill(value, tokens):
    if isinstance(value, str):
        for token, real in tokens.items():
            value = value.replace(token, real)
        return value
    if isinstance(value, list):
        return [fill(v, tokens) for v in value]
    if isinstance(value, dict):
        return {k: fill(v, tokens) for k, v in value.items()}
    return value


def load(path=RANGES, local=LOCAL):
    """Every range, with `alias` kept, `repo` resolved to an absolute path or None, and tokens filled."""
    m = local_map(local)
    out = []
    for r in json.load(open(path, encoding="utf-8"))["ranges"]:
        r = dict(r)
        r["alias"] = r["repo"]
        where = m["repos"].get(r["alias"])
        r["repo"] = os.path.expanduser(where) if where else None
        r["expected"] = fill(r["expected"], m["tokens"])
        out.append(r)
    return out


def main(argv):
    if argv[:1] == ["list"]:
        for r in load():
            print("|".join([r["id"], r["repo"] or "", r["base"], r["head"],
                            "true" if r["restoreTooling"] else "false", r["alias"]]))
        return 0
    if len(argv) == 2 and argv[0] == "expected":
        for r in load():
            if r["id"] == argv[1]:
                print(json.dumps(r["expected"]))
                return 0
        print("no range %s" % argv[1], file=sys.stderr)
        return 2
    print("usage: corpus_ranges.py list | expected <id>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
