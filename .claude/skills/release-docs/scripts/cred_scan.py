"""cred_scan.py — refuse a credential-shaped string a release-docs run is about to make public.

  cred_scan.py [--staged LISTING] [--skip PATH] [PATH ...]

  --staged LISTING   a `git diff --cached --raw -z --no-renames --no-abbrev` listing, read from
                     inside the repository. Each entry's new blob is compared with its old one, so
                     only a string the change added is refused: a mention the file already had
                     never is, and a binary file is read like any other.
  PATH               a file, or a directory walked in full. Scanned whole: it has no earlier copy.
  --skip PATH        one path a walk leaves out: a patch file, whose added lines --staged already
                     reads as blobs, and whose other lines are the earlier copy's.

Exit 0 when nothing is refused, 1 when something is, and 2 on anything the scan cannot read (no
input, a missing path, a symlink, a malformed listing, an unreadable blob): a scan that did not
happen is never a pass. A refusal names the file, the kind of credential and the lines. The string
itself is never printed.

release-docs.yml runs this, from the copy made before the model or the patch touched the checkout,
ahead of every upload, summary and push: the model's job could read what it was never meant to, and
a token in a doc, a report or the PR body is public once published. It is a tripwire for a token
written out as it is, not a defence against one that was encoded first.
"""
import collections
import json
import os
import re
import stat
import subprocess
import sys

# A prefix alone is a mention, and docs do name them; a prefix with this much after it is a token.
# After a GitHub prefix that is either of two shapes:
# - 20 letters or digits in a row. A classic token has 36 and a fine-grained one opens with 22, so
#   one cut short or wrapped is still refused, and no snake_case identifier gets there.
# - 36 characters of the wider set GitHub's guidance gives for installation tokens. Since 2026 they
#   are ghs_<app id>_<JWT>, about 520 characters, the Actions GITHUB_TOKEN included: an underscore
#   after a few digits, then dots and hyphens, so the first shape alone would pass them.
# After sk-ant-, 40 characters (a real one has about 100). Each minimum is above anything prose, a
# placeholder or an identifier produces. Nothing is required on the left: a token glued to an
# escape (%3D, \u003d) is still a token.
GH_TAIL = rb"(?:[A-Za-z0-9]{20,}|[A-Za-z0-9._-]{36,})"
CRED = re.compile(
    rb"(sk-ant-)[A-Za-z0-9_-]{40,}"
    rb"|(gh[pousr]_)" + GH_TAIL
    + rb"|(github_pat_)" + GH_TAIL)


def bad(msg):
    print("cred-scan: %s" % msg)
    sys.exit(2)


def creds(data):
    """{(prefix, token): [line, ...]} for each credential-shaped string in data."""
    found = collections.defaultdict(list)
    for m in CRED.finditer(data):
        prefix = next(g for g in m.groups() if g)
        found[(prefix, m.group(0))].append(data.count(b"\n", 0, m.start()) + 1)
    return found


def blob(sha):
    if not sha.strip("0"):
        return b""
    # The blob as a commit would carry it: a replace ref would show another object's content.
    p = subprocess.run(["git", "cat-file", "blob", sha], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                       env=dict(os.environ, GIT_NO_REPLACE_OBJECTS="1"))
    if p.returncode != 0:
        bad("could not read the blob %s" % sha)
    return p.stdout


def staged(listing):
    """[(path, new blob, {(prefix, token): lines} the change added)] for a --raw -z listing."""
    try:
        with open(listing, "rb") as fh:
            raw = fh.read().split(b"\0")
    except OSError as e:
        bad("could not read the listing %s (%s)" % (json.dumps(listing), type(e).__name__))
    if raw.pop() != b"" or len(raw) % 2:
        bad("the listing %s does not end on a whole entry" % json.dumps(listing))
    out = []
    for i in range(0, len(raw), 2):
        meta, path = raw[i].decode("ascii", "replace").split(), raw[i + 1].decode("utf-8", "replace")
        if len(meta) != 5 or not meta[0].startswith(":") or not all(re.fullmatch(r"[0-9a-f]{40,64}", s) for s in meta[2:4]):
            bad("unreadable listing entry %s" % json.dumps(raw[i].decode("ascii", "replace")))
        new = blob(meta[3])
        was, now = creds(blob(meta[2])), creds(new)
        out.append((path, new, {k: lines for k, lines in now.items() if len(lines) > len(was.get(k, ()))}))
    return out


def plain_files(path, skip):
    """Every file at or under path, but skip. A symlink, or anything else that is not a regular file
    or a directory, is bad input: an upload would follow it to content this scan never read."""
    if skip is not None and os.path.normpath(path) == os.path.normpath(skip):
        return []
    try:
        mode = os.lstat(path).st_mode
    except OSError as e:
        bad("could not read %s (%s)" % (json.dumps(path), type(e).__name__))
    if stat.S_ISREG(mode):
        return [path]
    if not stat.S_ISDIR(mode):
        bad("%s is not a regular file or a directory" % json.dumps(path))
    out = []
    for name in sorted(os.listdir(path)):
        out += plain_files(os.path.join(path, name), skip)
    return out


def whole(path):
    try:
        with open(path, "rb") as fh:
            data = fh.read()
    except OSError as e:
        bad("could not read %s (%s)" % (json.dumps(path), type(e).__name__))
    return path, data, creds(data)


def main(argv):
    listing, skip, paths, i = None, None, [], 0
    while i < len(argv):
        if argv[i] == "--staged" and i + 1 < len(argv):
            listing, i = argv[i + 1], i + 2
        elif argv[i] == "--skip" and i + 1 < len(argv):
            skip, i = argv[i + 1], i + 2
        elif argv[i].startswith("-"):
            bad("unknown or incomplete option %s" % json.dumps(argv[i]))
        else:
            paths.append(argv[i])
            i += 1
    if listing is None and not paths:
        bad("nothing to scan")
    changed = staged(listing) if listing is not None else []
    others = [whole(f) for p in paths for f in plain_files(p, skip)]
    refused = 0
    for path, data, found in changed + others:
        by_prefix = collections.defaultdict(set)
        for (prefix, _token), lines in found.items():
            by_prefix[prefix].update(lines)
        refused += bool(by_prefix)
        for prefix in sorted(by_prefix):
            lines = sorted(by_prefix[prefix])
            where = "(binary)" if b"\0" in data else "line%s %s" % ("s" if len(lines) > 1 else "", ", ".join(map(str, lines)))
            print("::error::refused, a credential-shaped string (%s...) in %s, %s"
                  % (prefix.decode(), json.dumps(path), where))
    print("%d changed and %d other files scanned, %d refused" % (len(changed), len(others), refused))
    return 1 if refused else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
