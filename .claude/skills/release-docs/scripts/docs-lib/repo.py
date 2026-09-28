"""Git and manifest access for docs-detect. The range resolves lazily, so modes that need no
range (--fix-mechanical, --allowed-paths) work without origin/main fetched."""
import json
import os
import subprocess


class RepoError(Exception):
    pass


def _run(root, *args):
    return subprocess.run(["git", "-c", "core.quotepath=off"] + list(args), cwd=root,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


class Context:
    def __init__(self, root, rng):
        start = root or os.getcwd()
        if not os.path.isdir(start):
            raise RepoError("no such directory: %s" % start)
        p = _run(start, "rev-parse", "--show-toplevel")
        if p.returncode != 0:
            raise RepoError("not a git repository: %s" % start)
        self.root = p.stdout.strip()
        if ".." not in rng:
            raise RepoError("--range must look like BASE..HEAD, got %r" % rng)
        self.range = rng
        self._refs = rng.split("..", 1)
        self._resolved = {}
        self._plugins = None

    def _rev(self, ref):
        if ref not in self._resolved:
            p = _run(self.root, "rev-parse", "--verify", "--quiet", ref + "^{commit}")
            if p.returncode != 0:
                raise RepoError("unknown ref: %s (fetch it first, e.g. git fetch origin main)" % ref)
            self._resolved[ref] = p.stdout.strip()
        return self._resolved[ref]

    @property
    def base(self):
        return self._rev(self._refs[0])

    @property
    def head(self):
        return self._rev(self._refs[1] or "HEAD")

    def with_range(self, rng):
        return Context(self.root, rng)

    def path(self, rel):
        return os.path.join(self.root, rel)

    def exists(self, rel):
        return os.path.exists(self.path(rel))

    def read(self, rel):
        with open(self.path(rel), encoding="utf-8") as f:
            return f.read()

    def show(self, ref, rel):
        """A file's content at a commit, or None where it does not exist."""
        p = _run(self.root, "show", "%s:%s" % (ref, rel))
        return p.stdout if p.returncode == 0 else None

    def name_status(self):
        """[(status letter, old path, new path)] for base..head, renames detected."""
        p = _run(self.root, "diff", "--name-status", "-M", "%s..%s" % (self.base, self.head))
        if p.returncode != 0:
            raise RepoError("git diff failed: %s" % p.stderr.strip())
        rows = []
        for line in p.stdout.splitlines():
            parts = line.split("\t")
            st = parts[0][:1]
            rows.append((st, parts[1], parts[2] if st in ("R", "C") else parts[1]))
        return rows

    def changed_files(self):
        return sorted({new for st, _old, new in self.name_status() if st != "D"})

    def plugins(self):
        """[{name, dir, version, description}] from the working tree's marketplace + plugin.json."""
        if self._plugins is None:
            try:
                mp = json.loads(self.read(".claude-plugin/marketplace.json"))
                out = []
                for e in mp["plugins"]:
                    d = os.path.normpath(e["source"])
                    pj = json.loads(self.read(os.path.join(d, ".claude-plugin", "plugin.json")))
                    out.append({"name": e["name"], "dir": d, "version": pj["version"],
                                "description": pj["description"]})
            except (OSError, ValueError, KeyError) as e:
                raise RepoError("cannot read the marketplace manifests: %s" % e)
            self._plugins = out
        return self._plugins

    def base_version(self, plugin_dir):
        """plugin.json's version at the range base, or None for a plugin the base lacks."""
        raw = self.show(self.base, plugin_dir + "/.claude-plugin/plugin.json")
        if raw is None:
            return None
        try:
            return json.loads(raw)["version"]
        except (ValueError, KeyError):
            return None
