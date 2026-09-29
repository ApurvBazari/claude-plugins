#!/usr/bin/env bash
# docs-detect.sh — what the docs must change for a release, for /release-docs (release-docs spec § 5).
#
# Usage:
#   docs-detect.sh [--root DIR] [--range BASE..HEAD] --out FILE      # report; exit 0
#   docs-detect.sh [--root DIR] [--range BASE..HEAD] --gate          # exit 0 clean, 1 open obligations
#   docs-detect.sh [--root DIR] --fix-mechanical                      # rewrite badges + landing cards
#   docs-detect.sh [--root DIR] --candidates BASE..HEAD               # stale-mention candidates (JSON)
#   docs-detect.sh [--root DIR] --allowed-paths                       # write-fence allowlist
#   docs-detect.sh [--root DIR] [--range BASE..HEAD] --pr-body --before FILE [--verifier FILE]
#   docs-detect.sh [--root DIR] --snapshot FILE                       # pre-apply snapshot (JSON)
#   docs-detect.sh [--root DIR] --fence --before FILE                 # write fence; exit 0 ok, 1 fenced
#   docs-detect.sh [--root DIR] --render-pages                        # changed pages to render-check
#   (--snapshot, --fence and --render-pages are post-checks.sh's; the allowlist comes from HEAD.)
#
# Default range: origin/main..HEAD. Exit 2 on bad input. No model, no network; the logic lives in
# docs-lib/ (python3, standard library only).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for cmd in git python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "docs-detect: required command not found: $cmd" >&2; exit 2; }
done

exec python3 -B "$HERE/docs-lib" "$@"
