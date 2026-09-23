# Tooling-Gap Audit

You are writing this repository's tooling-gap report. The lines above this prompt give the AUDIT DATE,
the FINDINGS path, the DRIFT REPORT path, and the REPORT OUTPUT path.

## Inputs
- FINDINGS — the drift items, one per line, produced by deterministic checks. This list is
  authoritative: do not add items, drop items, or merge them.
- DRIFT REPORT — the raw output of `onboard/scripts/audit-tooling.sh`, for context on the
  `structural:` items.
- `.claude/audit-baseline.json` — the expected tooling inventory that the
  `baseline path missing:` items refer to.

## Task
1. For each FINDINGS line, find the evidence in the repository with Read, Glob, or Grep, and work
   out the fix.
2. Write the report to the REPORT OUTPUT path with exactly this structure:
   - Line 1, exactly: `# Tooling Gap Audit — <AUDIT DATE>` (em dash, single spaces).
   - A `## Summary` section of one or two sentences.
   - One `## <area>` section per FINDINGS line, in the same order, containing **Finding** (the line
     verbatim), **Evidence** (path, or file:line), **Suggested fix**, and **Severity**
     (high / medium / low).
3. If FINDINGS is empty, the `## Summary` section says no tooling drift was detected and there are
   no finding sections.

Do not modify any file other than the report. Whether an issue is opened, kept, or closed is decided
from FINDINGS alone, not from your wording.
