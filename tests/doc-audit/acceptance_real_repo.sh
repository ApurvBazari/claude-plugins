#!/usr/bin/env bash
# shellcheck disable=SC1091  # lib.sh is sourced at runtime; shellcheck can't follow the dynamic path
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
FAILED=0
# The real repo audits clean as of the SP-2 truth-sweep (2026-07-03), which closed the
# prior gaps this test used to pin (MISSING_SKILLS_SECTION for walkthrough+lens,
# PLUGIN_NOT_IN_ROOT + SITE_PAGE_MISSING for lens — all since fixed). Assert clean so this
# test guards against future doc drift instead of pinning stale, already-closed gaps.
echo "real repo audits clean (SP-2 truth-sweep closed the prior doc gaps):"
assert_clean "$REPO_ROOT"
out_rc=0; bash "$SCRIPT" --root "$REPO_ROOT" >/dev/null 2>&1 || out_rc=$?
if [[ "$out_rc" -eq 0 ]]; then echo "  ok: zero exit on clean repo"; else echo "  FAIL: expected zero exit; rc=$out_rc"; FAILED=1; fi
exit "$FAILED"
