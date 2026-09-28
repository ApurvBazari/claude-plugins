"""Reuse doc-audit's completeness layers (README Skills sections, the root command index) as
inventory-row obligations, instead of duplicating them."""
import subprocess

from kinds import ob

AUDIT = ".claude/skills/doc-audit/scripts/audit-docs.sh"
CODES = ("MISSING_SKILLS_SECTION", "CMD_NOT_IN_README", "PHANTOM_CMD", "MARKER_MISSING",
         "PLUGIN_NOT_IN_ROOT", "ROOT_COUNT_STALE", "ROOT_NO_CMD_INDEX")
ROOT_CODES = ("PLUGIN_NOT_IN_ROOT", "ROOT_COUNT_STALE", "ROOT_NO_CMD_INDEX")


def check(ctx):
    if not ctx.exists(AUDIT):
        return []
    out = subprocess.run(["bash", ctx.path(AUDIT), "--root", ctx.root, "--format", "tsv"],
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True).stdout
    obs = []
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) < 5 or parts[3] not in CODES:
            continue
        plugin, code, msg = parts[2], parts[3], parts[4]
        rel = "README.md" if code in ROOT_CODES else "%s/README.md" % plugin
        obs.append(ob("inventory-row", plugin or "marketplace", rel, "%s: %s" % (code, msg)))
    return obs
