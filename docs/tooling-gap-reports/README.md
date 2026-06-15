# Tooling-Gap Reports

Dated audit reports (`YYYY-MM-DD-gap-report.md`) produced by the `tooling-gap-audit` GitHub Actions workflow. Each report records drift found by `onboard/scripts/audit-tooling.sh` against `.claude/audit-baseline.json`. `.github/scripts/open-gap-audit-pr.sh` diffs the latest report against the previous one and opens a PR when the drift state changes. Committed so the drift history is visible across releases.
