#!/usr/bin/env bash
# shellcheck disable=SC2016  # intentional literal markdown in fixtures
# shellcheck disable=SC1091  # lib.sh sourced at runtime
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
FAILED=0
mk() { local t; t="$(mktemp -d)"; make_clean_fixture "$t"; echo "$t"; }

echo "plugin missing from root README:"
T="$(mk)"
printf '# test marketplace\nOne plugin: **alpha**.\n## Commands\n- `/alpha:foo`\n' > "$T/README.md"
assert_finding "$T" PLUGIN_NOT_IN_ROOT
rm -rf "$T"

echo "stale plugin count phrase:"
T="$(mk)"
printf '# test marketplace\nThree plugins: **alpha** and **beta**.\n## Commands\n- `/alpha:foo` `/beta:bar`\n' > "$T/README.md"
assert_finding "$T" ROOT_COUNT_STALE
rm -rf "$T"

echo "no central command index:"
T="$(mk)"
printf '# test marketplace\nTwo plugins: **alpha** and **beta**.\n' > "$T/README.md"
assert_finding "$T" ROOT_NO_CMD_INDEX
rm -rf "$T"

echo "clean fixture stays clean for layer 2 codes:"
T="$(mk)"
assert_no_finding "$T" PLUGIN_NOT_IN_ROOT
assert_no_finding "$T" ROOT_COUNT_STALE
assert_no_finding "$T" ROOT_NO_CMD_INDEX
rm -rf "$T"

exit "$FAILED"
