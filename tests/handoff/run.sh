#!/usr/bin/env bash
# Run every test_*.sh in this directory. Non-zero exit if any fails.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
failures=0
for test in "$HERE"/test_*.sh; do
  [[ -f "$test" ]] || continue
  echo "=== $(basename "$test") ==="
  if ! bash "$test"; then
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "ABORT: $failures test file(s) failed."
  exit 1
fi
echo
echo "All handoff tests passed."
