# Tooling-Gap Audit — Report

You are formatting the analyzed tooling-gap findings into a dated report.

## Task
Write `docs/tooling-gap-reports/<YYYY-MM-DD>-gap-report.md`: a short summary line, then one section per finding (area · evidence · suggested fix · severity). The report is diffed against the previous one by `.github/scripts/open-gap-audit-pr.sh`; keep formatting stable so unchanged drift produces an identical report. If there are no findings, state "No tooling drift detected."
