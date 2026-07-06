#!/usr/bin/env bash
# Derived version assertion (SP-1 precedent): plugin.json == marketplace == CHANGELOG top.
# Keeps the 2.0.2 bump self-consistent with no hard-coded pin to re-touch on the next bump.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$ROOT/tests/lib/assert-versions.sh" notify
