#!/usr/bin/env bash
# shellcheck disable=SC2016  # intentional literal markdown in fixtures
# shellcheck disable=SC1091  # lib.sh sourced at runtime
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
FAILED=0
mk() { local t; t="$(mktemp -d)"; make_clean_fixture "$t"; echo "$t"; }

echo "no ## Skills but all commands documented in prose → relaxed (no MISSING_SKILLS_SECTION):"
T="$(mk)"
printf '# alpha\nUse /alpha:foo and /alpha:setup *(destructive — user-invoked only)*.\n' > "$T/alpha/README.md"
assert_no_finding "$T" MISSING_SKILLS_SECTION
rm -rf "$T"

echo "no ## Skills AND an undocumented command → MISSING_SKILLS_SECTION (WARN):"
T="$(mk)"
printf '# alpha\nUse /alpha:foo here. (setup intentionally undocumented)\n' > "$T/alpha/README.md"
assert_finding "$T" MISSING_SKILLS_SECTION
rm -rf "$T"

echo "command absent from README:"
T="$(mk)"
printf '# alpha\n## Skills\n### `/alpha:setup` *(destructive — user-invoked only)*\n' > "$T/alpha/README.md"
assert_finding "$T" CMD_NOT_IN_README
rm -rf "$T"

echo "destructive command lacks marker:"
T="$(mk)"
printf '# alpha\n## Skills\n### `/alpha:foo`\n### `/alpha:setup`\n' > "$T/alpha/README.md"
assert_finding "$T" MARKER_MISSING
rm -rf "$T"

echo "destructive command with marker in BULLET form → no MARKER_MISSING (header-agnostic):"
T="$(mk)"
printf '# alpha\n## Skills\n- `/alpha:foo`\n- `/alpha:setup` *(destructive — user-invoked only)*\n' > "$T/alpha/README.md"
assert_no_finding "$T" MARKER_MISSING
rm -rf "$T"

echo "phantom documented command:"
T="$(mk)"
printf '# alpha\n## Skills\n### `/alpha:foo`\n### `/alpha:setup` *(destructive — user-invoked only)*\n### `/alpha:ghost`\n' > "$T/alpha/README.md"
assert_finding "$T" PHANTOM_CMD
rm -rf "$T"

echo "clean fixture stays clean for layer 1 codes:"
T="$(mk)"
assert_no_finding "$T" MISSING_SKILLS_SECTION
assert_no_finding "$T" CMD_NOT_IN_README
assert_no_finding "$T" MARKER_MISSING
assert_no_finding "$T" PHANTOM_CMD
rm -rf "$T"

exit "$FAILED"
