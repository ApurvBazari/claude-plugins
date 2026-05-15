#!/usr/bin/env bash
# alpha-3-to-4.sh — R6 extracted migration: alpha.3 (or unversioned) -> alpha.4
#
# Protocol: reads JSON from stdin, writes migrated JSON to stdout.
# Idempotent: re-running produces the same output.
# Exits non-zero on failure.

set -euo pipefail
command -v jq >/dev/null || { echo "alpha-3-to-4: jq required" >&2; exit 2; }

INPUT=$(cat)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Pre-R3 schemas predate the schemaVersion field. Bump to alpha.4 baseline.
# The R3 schema introduced auth/privacy/security/runtimeOperations phases.
# This migration only stamps the version; it does NOT retroactively populate
# R3 phases (those are user-walked, not auto-inferred).
echo "$INPUT" | jq --arg ts "$NOW" '
  .schemaVersion = "alpha.4"
  | .meta = (.meta // {})
  | .meta.migrations = (.meta.migrations // []) + [{at: $ts, from: "alpha.3", to: "alpha.4"}]
'
