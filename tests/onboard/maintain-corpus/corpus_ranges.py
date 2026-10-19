#!/usr/bin/env python3
"""corpus_ranges.py — load maintain-corpus/ranges.json with each range's repo resolved locally.

ranges.json is tracked, so it names no machine and no private repo's contents: a range's `repo` is an
alias, and every repo-specific string (base/head SHAs, and the paths, lines, commands and workspace
package names inside expected items) is a `<alias:N>` placeholder. Both resolve through
repos.local.json, which is gitignored and exists only on a machine that holds the repos:

    {"repos": {"monorepo-a": "~/path/to/that/repo"}, "tokens": {"<monorepo-a:1>": "the real string"}}

(repos.local.example.json shows the shape.) An alias the map does not name resolves to None, and the
callers treat that range as not on this machine: skipped, or a failure under MAINTAIN_CORPUS_REQUIRED=1.

Usage:
  corpus_ranges.py list    one line per range: id, repo, base, head, restoreTooling, alias, separated by
                           the ASCII unit separator (\x1f) so an empty field (an unmapped repo) survives
                           `read`; the repo field is empty when the alias is unmapped
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RANGES = os.path.join(HERE, "ranges.json")
LOCAL = os.path.join(HERE, "repos.local.json")
SEP = "\x1f"


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
    """Every range, tokens filled in every field, `alias` kept, `repo` resolved to an absolute path or None."""
    m = local_map(local)
    out = []
    for r in json.load(open(path, encoding="utf-8"))["ranges"]:
        r = fill(dict(r), m["tokens"])
        r["alias"] = r["repo"]
        where = m["repos"].get(r["alias"])
        r["repo"] = os.path.expanduser(where) if where else None
        out.append(r)
    return out


def main(argv):
    if argv == ["list"]:
        for r in load():
            print(SEP.join([r["id"], r["repo"] or "", r["base"], r["head"],
                            "true" if r["restoreTooling"] else "false", r["alias"]]))
        return 0
    print("usage: corpus_ranges.py list", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
