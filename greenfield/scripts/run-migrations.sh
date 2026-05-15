#!/usr/bin/env bash
# run-migrations.sh — R6 generic migration runner
#
# Reads migration step modules from greenfield/skills/pickup/migrations/ and
# applies them sequentially from --from to --to. Supports --dry-run with JSON
# diff output. Each step reads JSON from stdin, writes migrated JSON to stdout,
# exits non-zero on failure (preserves original state).
#
# Usage:
#   run-migrations.sh --from alpha.6 --to alpha.7 --state-file .claude/greenfield-state.json
#   run-migrations.sh --from alpha.6 --to alpha.7 --state-file <path> --dry-run

set -euo pipefail

FROM=""
TO=""
STATE_FILE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)       FROM="$2"; shift 2 ;;
    --to)         TO="$2"; shift 2 ;;
    --state-file) STATE_FILE="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    *)            echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${FROM:?--from is required}"
: "${TO:?--to is required}"
: "${STATE_FILE:?--state-file is required}"
[[ -f "$STATE_FILE" ]] || { echo "run-migrations: state file not found: $STATE_FILE" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve the pickup migrations directory relative to the script
MIG_DIR="$(cd "${SCRIPT_DIR}/../skills/pickup/migrations" && pwd)" || {
  echo "run-migrations: cannot resolve migrations directory" >&2; exit 3;
}

# Build the ordered chain from FROM to TO
declare -a CHAIN
case "$FROM:$TO" in
  alpha.3:alpha.7) CHAIN=("alpha-3-to-4" "alpha-4-to-5" "alpha-5-to-6" "alpha-6-to-7") ;;
  alpha.4:alpha.7) CHAIN=("alpha-4-to-5" "alpha-5-to-6" "alpha-6-to-7") ;;
  alpha.5:alpha.7) CHAIN=("alpha-5-to-6" "alpha-6-to-7") ;;
  alpha.6:alpha.7) CHAIN=("alpha-6-to-7") ;;
  alpha.3:alpha.6) CHAIN=("alpha-3-to-4" "alpha-4-to-5" "alpha-5-to-6") ;;
  alpha.4:alpha.6) CHAIN=("alpha-4-to-5" "alpha-5-to-6") ;;
  alpha.5:alpha.6) CHAIN=("alpha-5-to-6") ;;
  alpha.3:alpha.5) CHAIN=("alpha-3-to-4" "alpha-4-to-5") ;;
  alpha.4:alpha.5) CHAIN=("alpha-4-to-5") ;;
  alpha.3:alpha.4) CHAIN=("alpha-3-to-4") ;;
  *)               echo "run-migrations: no chain from $FROM to $TO" >&2; exit 4 ;;
esac

CURRENT=$(cat "$STATE_FILE")
ORIGINAL="$CURRENT"

for step in "${CHAIN[@]}"; do
  STEP_SCRIPT="${MIG_DIR}/${step}.sh"
  [[ -x "$STEP_SCRIPT" ]] || { echo "run-migrations: missing step: $STEP_SCRIPT" >&2; exit 5; }
  NEXT=$(echo "$CURRENT" | "$STEP_SCRIPT") || {
    echo "run-migrations: step '$step' failed; state unchanged" >&2
    exit 6
  }
  echo "$NEXT" | jq empty 2>/dev/null || {
    echo "run-migrations: step '$step' emitted invalid JSON; state unchanged" >&2
    exit 7
  }
  CURRENT="$NEXT"
done

if [[ "$DRY_RUN" == "true" ]]; then
  # Emit a JSON diff (paths that changed). Best effort — uses jq to compare.
  echo "$ORIGINAL" > /tmp/.migration-before.$$
  echo "$CURRENT"  > /tmp/.migration-after.$$
  echo "{"
  echo "  \"from\": \"$FROM\","
  echo "  \"to\":   \"$TO\","
  echo "  \"steps\": [$(printf '"%s",' "${CHAIN[@]}" | sed 's/,$//')]"
  echo ","
  echo "  \"diff\": $(diff <(echo "$ORIGINAL" | jq -S .) <(echo "$CURRENT" | jq -S .) | jq -Rs . 2>/dev/null || echo '""')"
  echo "}"
  rm -f /tmp/.migration-before.$$ /tmp/.migration-after.$$
  exit 0
fi

# Atomic write
TMP="${STATE_FILE}.tmp.$$"
echo "$CURRENT" > "$TMP" && mv "$TMP" "$STATE_FILE"
echo "run-migrations: applied chain [${CHAIN[*]}] to $STATE_FILE"
