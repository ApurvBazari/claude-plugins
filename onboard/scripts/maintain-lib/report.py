"""Assemble maintain-detect.json (spec § 6.1): items in a fixed kind order, ids D1..Dn."""
import json
import os
import tempfile

import manifest
import paths
import recheck
import refs
import research
import structure
from context import meta_version


def _not_onboarded():
    return {"kind": "not-onboarded", "disposition": "defer", "reason": "not-onboarded",
            "command": "/onboard:start"}


def build(ctx):
    report = {"schemaVersion": 1,
              "range": {"baseRef": ctx.base_ref, "base": ctx.base, "head": "worktree"},
              "project": {"onboarded": ctx.meta is not None,
                          "metaVersion": meta_version(ctx.meta)},
              "items": [],
              "truncated": {"recheck-line": 0}}
    if ctx.meta is None:                                            # R10
        items = [_not_onboarded()]
    else:
        ctx.load()
        pc = manifest.package_changes(ctx)
        dep_removed = manifest.dependency_removed(ctx, pc)
        script_removed = manifest.script_removed(ctx, pc)
        broken = paths.path_mention_broken(ctx)
        excluded = set()
        for item in dep_removed + script_removed:
            excluded.add(item["line"])
            excluded.update(item["alsoAt"])
        excluded.update(item["line"] for item in broken)
        rechecks, dropped = recheck.recheck_items(ctx, pc.dep_names, excluded)
        report["truncated"]["recheck-line"] = dropped
        items = (manifest.dependency_added(ctx, pc) + rechecks + manifest.script_added(ctx, pc)
                 + dep_removed + script_removed + broken + manifest.manifest_changed(ctx, pc)
                 + structure.config_changed(ctx) + structure.directory_new(ctx)
                 + refs.rule_globs(ctx) + refs.hook_commands(ctx) + structure.lessons_large(ctx)
                 + structure.language_new(ctx) + structure.signal_mcp(ctx)
                 + structure.signal_builtin_skill(ctx, pc) + research.research_stale(ctx, pc))
    report["items"] = [dict([("id", "D%d" % i)] + list(item.items()))
                       for i, item in enumerate(items, 1)]
    return report


def error(code, message):
    return {"schemaVersion": 1, "error": {"code": code, "message": message}}


def write_atomic(path, obj):
    """Temp file in the target directory + rename: a reader never sees a partial report."""
    fd, tmp = tempfile.mkstemp(prefix=".maintain-detect.", dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(obj, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
