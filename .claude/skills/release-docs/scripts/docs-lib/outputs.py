"""Where the release-docs scripts may write (release-docs spec § 6).

The CI model may call these scripts with any arguments, and a script's own writes are not covered by
Claude Code's `.claude/` protection: `--report .claude/skills/release-docs/scripts/post-checks.sh`
once emptied the very script CI then ran. So every output path (`--out`, `--snapshot`, `--report`,
`--shots`) is checked before anything is written:

- inside any `.git` directory (a `.git` path component in any case, or the repository's git dir or
  common dir, wherever they live) it is refused;
- inside a repository's working tree it must sit under that tree's `.release-docs/` (exact name);
- outside every repository (`$TMPDIR`, `$RUNNER_TEMP`) it is free.

The path is resolved first (symlinks followed; for a path that does not exist yet, its nearest
existing ancestor), and "inside" is decided by file identity, not by spelling, so a case variant or
a symlinked route to the tree is still inside it. An existing file output must be a regular file
with one link: a hard link would truncate whatever it shares its content with.
"""
import os
import stat
import subprocess

import repo

HERE = os.path.dirname(os.path.abspath(__file__))
RUN_DIR = ".release-docs"


def _ident(path):
    try:
        st = os.stat(path)
    except OSError:
        return None
    return (st.st_dev, st.st_ino)


def _repository(start):
    """(toplevel, [git dir, git common dir]) for the repository holding start, or None."""
    if not start or not os.path.isdir(start):
        return None
    p = subprocess.run(["git", "-C", start, "rev-parse", "--show-toplevel", "--git-dir",
                        "--git-common-dir"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                       text=True)
    lines = p.stdout.splitlines() if p.returncode == 0 else []
    if len(lines) < 3:
        return None
    return lines[0], [g if os.path.isabs(g) else os.path.join(start, g) for g in lines[1:3]]


def check(path, is_dir=False, roots=()):
    """Raise RepoError unless `path` is a safe place for a script to write. `roots` names extra
    directories whose repositories count (docs-detect's --root); the caller's working directory
    and the scripts' own repository always count."""
    what = "--shots directory" if is_dir else "output file"
    target = os.path.realpath(os.path.abspath(path))
    comps = [c for c in target.split("/") if c]
    if any(c.lower() == ".git" for c in comps):
        raise repo.RepoError("refusing %s %s: it is inside a .git directory" % (what, path))
    # Every existing ancestor of the resolved path (itself included), with the components below it.
    chain = []
    for i in range(len(comps), -1, -1):
        ident = _ident("/" + "/".join(comps[:i]))
        if ident is not None:
            chain.append((ident, comps[i:]))
    idents = {ident for ident, _rest in chain}
    seen = set()
    for start in [os.getcwd(), HERE] + [r for r in roots if r]:
        found = _repository(start)
        if found is None or found[0] in seen:
            continue
        seen.add(found[0])
        top, gitdirs = found
        if any(_ident(g) in idents for g in gitdirs if _ident(g) is not None):
            raise repo.RepoError("refusing %s %s: it is inside the git directory of %s"
                                 % (what, path, top))
        top_ident = _ident(top)
        for ident, rest in chain:
            if ident == top_ident:
                if not rest or rest[0] != RUN_DIR or (not is_dir and len(rest) < 2):
                    raise repo.RepoError("refusing %s %s: inside the repository %s it must be "
                                         "under %s/" % (what, path, top, RUN_DIR))
                break
    if os.path.lexists(target):
        st = os.stat(target)
        if is_dir and not stat.S_ISDIR(st.st_mode):
            raise repo.RepoError("refusing %s %s: it exists and is not a directory" % (what, path))
        if not is_dir and (not stat.S_ISREG(st.st_mode) or st.st_nlink > 1):
            raise repo.RepoError("refusing %s %s: it exists and is not a regular file with a "
                                 "single link" % (what, path))
