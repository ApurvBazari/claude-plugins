#!/usr/bin/env bash
# shellcheck disable=SC1091  # lib.sh sourced at runtime
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
FAILED=0
mk() { local t; t="$(mktemp -d)"; make_clean_fixture "$t"; echo "$t"; }

echo "version mismatch:"
T="$(mk)"
cat > "$T/alpha/.claude-plugin/plugin.json" <<'JSON'
{"name":"alpha","version":"2.0.0","description":"Alpha plugin","author":{"name":"t"},"license":"MIT","keywords":["a"]}
JSON
assert_finding "$T" VERSION_MISMATCH
rm -rf "$T"

echo "description mismatch:"
T="$(mk)"
cat > "$T/alpha/.claude-plugin/plugin.json" <<'JSON'
{"name":"alpha","version":"1.0.0","description":"A totally different blurb","author":{"name":"t"},"license":"MIT","keywords":["a"]}
JSON
assert_finding "$T" DESC_MISMATCH
rm -rf "$T"

echo "missing plugin.json:"
T="$(mk)"
rm -f "$T/alpha/.claude-plugin/plugin.json"
assert_finding "$T" PLUGIN_JSON_MISSING
rm -rf "$T"

echo "clean stays clean for layer 3 codes:"
T="$(mk)"
assert_no_finding "$T" VERSION_MISMATCH
assert_no_finding "$T" DESC_MISMATCH
assert_no_finding "$T" PLUGIN_JSON_MISSING
rm -rf "$T"

exit "$FAILED"
