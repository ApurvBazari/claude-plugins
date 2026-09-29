"""Where the release-docs scripts may write (release-docs spec § 6).

The CI model may call these scripts with any arguments, and a script's own writes are not covered by
Claude Code's `.claude/` protection: `--report .claude/skills/release-docs/scripts/post-checks.sh`
once emptied the very script CI then ran. So every output path (`--out`, `--snapshot`, `--report`,
`--shots`, og-regen's og.png) is checked before anything is written:

- inside any `.git` directory (a `.git` path component in any case, or the repository's git dir or
  common dir, wherever they live) it is refused;
- inside a repository's working tree it must sit under that tree's `.release-docs/` (exact name);
- outside every repository (`$TMPDIR`, `$RUNNER_TEMP`) it is free.

og-regen's destination is the one output that belongs in the tree: `check(..., exact=OG_PNG)`
replaces the `.release-docs/` rule with "exactly the toplevel's site/og.png", counts the repository
the path itself resolves into as well, and refuses a symlink at og.png (og-regen replaces the file
by rename, and `mv` onto a symlink to a directory moves into that directory).

The path is resolved the way the OS resolves it: os.path.realpath follows each symlink before it
applies the `..` after it, so `.release-docs/link/..` is the parent of the link's target, not
`.release-docs` (os.path.abspath would collapse it as text first and check a different file than
the one that gets written). A path that does not exist yet resolves through its nearest existing
ancestor. "Inside" is decided by file identity, not by spelling, so a case variant or a symlinked
route to the tree is still inside it. An existing file output must be a regular file with one
link: a hard link would truncate whatever it shares its content with.
"""
import errno
import os
import stat
import subprocess

import repo

HERE = os.path.dirname(os.path.realpath(__file__))
RUN_DIR = ".release-docs"
OG_PNG = "site/og.png"


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


def _resolve(path, what):
    """The absolute path the OS reaches through `path`, and its components. realpath gives up on a
    symlink loop and collapses whatever follows it as text, so a loop is refused here: its answer
    would describe a path nobody can write."""
    try:
        os.stat(path)
    except OSError as e:
        if e.errno == errno.ELOOP:
            raise repo.RepoError("refusing %s %s: a symlink on its path is a symlink loop"
                                 % (what, path))
    target = os.path.realpath(path)
    return target, [c for c in target.split("/") if c]


def check(path, is_dir=False, roots=(), exact=None):
    """Raise RepoError unless `path` is a safe place for a script to write. `roots` names extra
    directories whose repositories count (docs-detect's --root); the caller's working directory
    and the scripts' own repository always count. `exact` (OG_PNG) is the one path the output may
    take inside a repository, relative to its toplevel, in place of the `.release-docs/` rule."""
    what = "--shots directory" if is_dir else "output file"
    if exact and os.path.islink(path):
        raise repo.RepoError("refusing %s %s: it is a symlink, and it is replaced by rename"
                             % (what, path))
    target, comps = _resolve(path, what)
    if any(c.lower() == ".git" for c in comps):
        raise repo.RepoError("refusing %s %s: it is inside a .git directory" % (what, path))
    # Every existing ancestor of the resolved path (itself included), nearest first, with the
    # components below it.
    chain = []
    for i in range(len(comps), -1, -1):
        where = "/" + "/".join(comps[:i])
        ident = _ident(where)
        if ident is not None:
            chain.append((ident, where, comps[i:]))
    idents = {ident for ident, _where, _rest in chain}
    starts = [os.getcwd(), HERE] + [r for r in roots if r]
    if exact:  # the repository the path lands in, wherever that is ("/" always ends the chain)
        starts.append(next(where for _ident, where, _rest in chain if os.path.isdir(where)))
    seen = set()
    for start in starts:
        found = _repository(start)
        if found is None or found[0] in seen:
            continue
        seen.add(found[0])
        top, gitdirs = found
        if any(_ident(g) in idents for g in gitdirs if _ident(g) is not None):
            raise repo.RepoError("refusing %s %s: it is inside the git directory of %s"
                                 % (what, path, top))
        top_ident = _ident(top)
        for ident, _where, rest in chain:
            if ident != top_ident:
                continue
            if exact:
                ok, rule = rest == exact.split("/"), "exactly its %s" % exact
            else:
                ok = bool(rest) and rest[0] == RUN_DIR and (is_dir or len(rest) >= 2)
                rule = "under %s/" % RUN_DIR
            if not ok:
                raise repo.RepoError("refusing %s %s: inside the repository %s it must be %s"
                                     % (what, path, top, rule))
            break
    if os.path.lexists(target):
        st = os.stat(target)
        if is_dir and not stat.S_ISDIR(st.st_mode):
            raise repo.RepoError("refusing %s %s: it exists and is not a directory" % (what, path))
        if not is_dir and (not stat.S_ISREG(st.st_mode) or st.st_nlink > 1):
            raise repo.RepoError("refusing %s %s: it exists and is not a regular file with a "
                                 "single link" % (what, path))
