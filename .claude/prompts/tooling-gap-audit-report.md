# Tooling-Gap Audit — Report

You are formatting the analyzed tooling-gap findings into a dated report.

## Task
Write `docs/tooling-gap-reports/<YYYY-MM-DD>-gap-report.md` with this exact structure so `.github/scripts/open-gap-audit-pr.sh` can normalize and diff it:

1. First line MUST be exactly `# Tooling Gap Audit — <YYYY-MM-DD>` (em dash, spaces — the script strips this date line before diffing).
2. A `## Summary` section (one or two sentences; the script extracts it verbatim for the PR body).
3. Then one `## ` section per finding (area · evidence · suggested fix · severity).

Keep formatting stable so unchanged drift produces an identical report below the date line. If there are no findings, the `## Summary` section states "No tooling drift detected." and there are no finding sections.
