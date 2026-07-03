#!/usr/bin/env bash
# shellcheck disable=SC1091  # lib.sh sourced at runtime
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
FAILED=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
make_clean_fixture "$TMP"
echo "clean fixture audits clean:"
assert_clean "$TMP"
exit "$FAILED"
