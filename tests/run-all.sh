#!/usr/bin/env bash
# Run every plugin/tooling test belt. Excludes tests/release-gate (manual, point-in-time)
# and shared lib.sh helpers. Discovery covers the repo's mixed test naming.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
failures=0; ran=0

while IFS= read -r t; do
  [ -n "$t" ] || continue
  ran=$((ran + 1))
  echo "=== ${t#"$HERE"/} ==="
  if ! bash "$t"; then
    failures=$((failures + 1))
    echo "  ^ FAILED"
  fi
done < <(
  git -C "$HERE/.." ls-files -- 'tests/*.sh' \
    | grep -E '/(test_[^/]+|test-[^/]+|[^/]+-smoke)\.sh$' \
    | grep -v '^tests/release-gate/' \
    | grep -v '/lib\.sh$' \
    | grep -v '/run\.sh$' \
    | grep -v '/run-all\.sh$' \
    | sed "s|^tests/|$HERE/|"
)

echo
echo "Ran $ran belt script(s); $failures failed."
[ "$ran" -gt 0 ] || { echo "No belts discovered — check the discovery filter"; exit 1; }
[ "$failures" -eq 0 ]
