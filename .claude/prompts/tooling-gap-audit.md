# Tooling-Gap Audit

You are auditing this repository's Claude tooling for drift. The lines above this prompt give the
AUDIT DATE, the DRIFT REPORT path, and the REPORT OUTPUT path.

## Inputs
- DRIFT REPORT — the output of `onboard/scripts/audit-tooling.sh`: structural checks on CLAUDE.md
  command references, rule path targets, hook scripts, uncovered directories, and undocumented
  dependencies.
- `.claude/audit-baseline.json` — the expected tooling inventory. Every path it lists must exist;
  a listed path that no longer exists is drift.

## Task
1. Read both inputs. Confirm each drift item against the repository with Read, Glob, or Grep before
   reporting it. Drop anything you cannot confirm.
2. Write the report to the REPORT OUTPUT path with exactly this structure:
   - Line 1, exactly: `# Tooling Gap Audit — <AUDIT DATE>` (em dash, single spaces).
   - A `## Summary` section of one or two sentences.
   - One `## <area>` section per finding, containing **Evidence** (path, or file:line),
     **Suggested fix**, and **Severity** (high / medium / low).
3. If nothing drifted, the `## Summary` section reads exactly `No tooling drift detected.` and
   there are no finding sections.

Keep wording and ordering stable — sort findings by area, then by path — so an unchanged
repository produces an identical report below line 1. Do not modify any file other than the report.
