#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")" || exit 1
rc=0
for t in test_*.sh; do
  echo "== $t =="
  bash "$t" || rc=1
done
if [[ $rc -eq 0 ]]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
