"""research-stale: diff signals mapped to research dimensions per
update/references/re-research.md § Detection, intersected with the stored depth's roster."""
import posixpath
import re

from tables import (DATA_MODEL_PATH_RE, DEPTH_ROSTER, FRAMEWORKS, SECURITY_PATH_RE,
                    SOURCE_EXTS, TEST_PATH_RE)

_MAJOR = re.compile(r"(\d+)")


def _major(version):
    m = _MAJOR.search(version)
    return int(m.group(1)) if m else None


def research_stale(ctx, pc):
    research = ctx.meta.get("research") if isinstance(ctx.meta, dict) else None
    depth = research.get("depth") if isinstance(research, dict) else None
    roster = DEPTH_ROSTER.get(depth) if isinstance(depth, str) else None
    if not roster:
        return []
    dims = set()
    if pc.dep_added or pc.dep_removed:
        dims |= {"dependencies", "security"}
    new_top = sorted(set(f.split("/", 1)[0] for f in ctx.now_files
                         if "/" in f and posixpath.splitext(f)[1].lower() in SOURCE_EXTS
                         and f.split("/", 1)[0] not in ctx.base_dirs))
    if new_top:
        dims |= {"architecture", "conventions"}
    if any(re.match(r"^(tsconfig.*\.json|\.eslintrc.*|eslint\.config.*)$", posixpath.basename(c.path))
           for c in ctx.changes):
        dims.add("conventions")
    base_tests = sum(1 for f in ctx.base_files if TEST_PATH_RE.search(f))
    now_tests = sum(1 for f in ctx.now_files if TEST_PATH_RE.search(f))
    if now_tests != base_tests and abs(now_tests - base_tests) > 0.2 * max(base_tests, 1):
        dims.add("testing")
    added = [c.path for c in ctx.changes if c.status in ("A", "R")]
    if any(SECURITY_PATH_RE.search(p) for p in added):
        dims.add("security")
    if any(DATA_MODEL_PATH_RE.search(p) for p in added):
        dims.add("data-model")
    major_bump = False
    for _, name, base_v, now_v in pc.version_changes:
        a, b = _major(base_v), _major(now_v)
        if name in FRAMEWORKS and a is not None and b is not None and a != b:
            major_bump = True
    if major_bump:
        dims |= {"architecture", "dependencies", "conventions"}
    dims &= roster
    if not dims:
        return []
    escalated = len(dims) >= 3 or major_bump or len(new_top) >= 2
    return [{"kind": "research-stale", "dimensions": sorted(dims), "escalatedToFull": escalated,
             "disposition": "defer", "reason": "needs-research", "command": "/onboard:update"}]
