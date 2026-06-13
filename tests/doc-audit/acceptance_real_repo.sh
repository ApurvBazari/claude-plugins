#!/usr/bin/env bash
# shellcheck disable=SC1091  # lib.sh is sourced at runtime; shellcheck can't follow the dynamic path
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
FAILED=0
echo "real repo currently flags the known doc gaps:"
assert_finding "$REPO_ROOT" MISSING_SKILLS_SECTION   # walkthrough + lens
assert_finding "$REPO_ROOT" PLUGIN_NOT_IN_ROOT       # lens absent from root README
assert_finding "$REPO_ROOT" SITE_PAGE_MISSING        # lens has no site page
out_rc=0; bash "$SCRIPT" --root "$REPO_ROOT" >/dev/null 2>&1 || out_rc=$?
if [[ "$out_rc" -ne 0 ]]; then echo "  ok: nonzero exit on errors"; else echo "  FAIL: expected nonzero exit"; FAILED=1; fi
exit "$FAILED"
