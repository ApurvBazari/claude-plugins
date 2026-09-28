"""Everything detect reads, gathered once per run."""
import json
import os

import gitview
import mentions
import paths
import tooling


class Context(object):
    """Step 1 (range) and step 2 (R10 metadata) on construction; the rest on load()."""

    def __init__(self, top, base_ref):
        self.top = top
        self.base_ref = base_ref
        self.base = gitview.resolve_commit(top, base_ref)
        self.meta = _load_meta(top)

    def load(self):
        top = self.top
        self.changes = gitview.changed_set(top, self.base)
        self.changed_paths = set()
        for c in self.changes:
            self.changed_paths.add(c.path)
            if c.old:
                self.changed_paths.add(c.old)
        self.base_files = gitview.base_files(top, self.base)
        self.now_files = gitview.now_files(top)
        self.base_dirs = gitview.parent_dirs(self.base_files)
        self.now_dirs = gitview.parent_dirs(self.now_files)
        self.tooling_files = tooling.tooling_files(top, self.now_files)
        self.tlines = tooling.load(top, self.tooling_files)
        self.packages = mentions.load_packages(top, self.now_files)
        self.resolver = paths.Resolver(top, self.base_files, self.now_files, self.changes)
        return self


def _load_meta(top):
    """None when .claude/onboard-meta.json is absent (R10); {} when present but unreadable."""
    path = os.path.join(top, ".claude", "onboard-meta.json")
    if not os.path.isfile(path):
        return None
    try:
        with open(path) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (ValueError, IOError, OSError):
        return {}


def meta_version(meta):
    for key in ("pluginVersion", "version"):
        value = (meta or {}).get(key)
        if isinstance(value, str):
            return value
    return None
