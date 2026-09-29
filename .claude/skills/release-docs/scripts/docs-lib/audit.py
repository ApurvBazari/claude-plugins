"""Reuse doc-audit's completeness layers (README Skills sections, the root command index, manifest
sync) as inventory-row obligations, instead of duplicating them."""
import subprocess

import repo
from kinds import ob

AUDIT = ".claude/skills/doc-audit/scripts/audit-docs.sh"
ROOT_CODES = ("PLUGIN_NOT_IN_ROOT", "ROOT_COUNT_STALE", "ROOT_NO_CMD_INDEX")
MANIFEST_CODES = ("PLUGIN_JSON_MISSING", "VERSION_MISMATCH", "DESC_MISMATCH")
CODES = ("MISSING_SKILLS_SECTION", "CMD_NOT_IN_README", "PHANTOM_CMD", "MARKER_MISSING") \
    + ROOT_CODES + MANIFEST_CODES
MARKETPLACE = ".claude-plugin/marketplace.json"


def _rows(ctx):
    """audit-docs' TSV rows. It exits 1 when it reports an ERROR finding, so rc 1 is a report only
    when an ERROR row is there; any other failure raises — a crash must never read as clean."""
    p = subprocess.run(["bash", ctx.path(AUDIT), "--root", ctx.root, "--format", "tsv"],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    rows = [line.split("\t") for line in p.stdout.splitlines()]
    if p.returncode == 0 or (p.returncode == 1 and any(r[0] == "ERROR" for r in rows)):
        return rows
    err = (p.stderr.strip().splitlines() or ["(no stderr)"])[0]
    raise repo.RepoError("doc-audit failed (rc %d): %s" % (p.returncode, err))


def check(ctx):
    if not ctx.exists(AUDIT):
        return []
    obs = []
    for parts in _rows(ctx):
        if len(parts) < 5 or parts[3] not in CODES:
            continue
        plugin, code, msg = parts[2], parts[3], parts[4]
        if code in ROOT_CODES:
            rel = "README.md"
        elif code in MANIFEST_CODES:
            rel = MARKETPLACE
        else:
            rel = "%s/README.md" % plugin
        obs.append(ob("inventory-row", plugin or "marketplace", rel, "%s: %s" % (code, msg)))
    return obs
