#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../greenfield/scripts/render-common.sh
source "${SCRIPT_DIR}/../../../greenfield/scripts/render-common.sh"

# PII array: one entry with encryption, one without
PII='[
  {"path":"User.email","encryption":"at-rest"},
  {"path":"User.phone"}
]'

# Case 1: Path with encryption → no warning appended
RESULT1=$(_check_pii_encryption "User.email" "$PII" "[]")
LEN1=$(jq 'length' <<< "$RESULT1")
[[ "$LEN1" == "0" ]] || { echo "FAIL: expected no warning for encrypted PII, got $LEN1"; exit 1; }

# Case 2: Path without encryption → one warning appended with id starting W-PII-
RESULT2=$(_check_pii_encryption "User.phone" "$PII" "[]")
LEN2=$(jq 'length' <<< "$RESULT2")
[[ "$LEN2" == "1" ]] || { echo "FAIL: expected one warning for unencrypted PII, got $LEN2"; exit 1; }

ID2=$(jq -r '.[0].id' <<< "$RESULT2")
[[ "$ID2" == W-PII-* ]] || { echo "FAIL: id should start with W-PII-, got '$ID2'"; exit 1; }

LEVEL2=$(jq -r '.[0].level' <<< "$RESULT2")
[[ "$LEVEL2" == "warn" ]] || { echo "FAIL: level should be warn, got '$LEVEL2'"; exit 1; }

# Case 3: Path not in PII list → unchanged
RESULT3=$(_check_pii_encryption "User.notPii" "$PII" "[]")
LEN3=$(jq 'length' <<< "$RESULT3")
[[ "$LEN3" == "0" ]] || { echo "FAIL: non-PII path should produce no warning, got $LEN3"; exit 1; }

echo "check_pii_encryption: OK"
