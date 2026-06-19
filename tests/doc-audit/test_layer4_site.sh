#!/usr/bin/env bash
# shellcheck disable=SC1091  # lib.sh sourced at runtime
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
FAILED=0

echo "missing site page:"
T="$(mktemp -d)"; make_clean_fixture "$T"
rm -rf "$T/site/beta"
assert_finding "$T" SITE_PAGE_MISSING
rm -rf "$T"

echo "stale site page (README committed after site):"
T="$(mktemp -d)"; make_clean_fixture "$T"
(
  cd "$T" || exit 1
  git init -q
  git config user.email t@t; git config user.name t
  # Pin commit dates explicitly: git %ct has 1-second granularity, so three
  # back-to-back commits can share a timestamp and make rt > st false (flaky).
  # Fixed dates (site oldest, README newest) make the staleness compare deterministic.
  git add site
  GIT_AUTHOR_DATE="@1577836800" GIT_COMMITTER_DATE="@1577836800" git commit -q -m "site"
  git add -A
  GIT_AUTHOR_DATE="@1609459200" GIT_COMMITTER_DATE="@1609459200" git commit -q -m "rest"
  # touch + recommit alpha README so its last-commit time is newest
  printf '\nMore docs.\n' >> alpha/README.md
  git add alpha/README.md
  GIT_AUTHOR_DATE="@1640995200" GIT_COMMITTER_DATE="@1640995200" git commit -q -m "update alpha readme"
)
assert_finding "$T" SITE_PAGE_STALE
rm -rf "$T"

echo "clean (non-git) fixture has no false site staleness:"
T="$(mktemp -d)"; make_clean_fixture "$T"
assert_no_finding "$T" SITE_PAGE_MISSING
assert_no_finding "$T" SITE_PAGE_STALE
rm -rf "$T"

exit "$FAILED"
