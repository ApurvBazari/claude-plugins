#!/usr/bin/env bash
# System-map engine belt. The shipped engine file parses, stays inside its size limits, carries
# nothing the page contract forbids, and its pure layout passes the node harness.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
E="$ROOT/walkthrough/skills/create/references/system-map-engine.js"
H="$ROOT/tests/walkthrough/sysmap/check.js"
fail(){ echo "FAIL: $1"; exit 1; }
ok(){ echo "ok: $1"; }

[ -s "$E" ] || fail "missing $E"
[ -s "$H" ] || fail "missing $H"

# --- sentinels: the first and last line, each exactly once. The write stage checks for these two
# lines to know the whole file reached the page, so nothing may come before or after them. ---
[ "$(head -n 1 "$E")" = '/* walkthrough system-map engine v1 */' ] || fail "the first line must be the engine sentinel"
[ "$(tail -n 1 "$E")" = '/* end walkthrough system-map engine */' ] || fail "the last line must be the end sentinel"
[ "$(grep -cF '/* walkthrough system-map engine v1 */' "$E")" -eq 1 ] || fail "the start sentinel must appear exactly once"
[ "$(grep -cF '/* end walkthrough system-map engine */' "$E")" -eq 1 ] || fail "the end sentinel must appear exactly once"
if [ -n "$(tail -c 1 "$E" | tr -d '\n')" ]; then fail "the file must end with a newline"; fi
ok "sentinels on the first and last line"

# --- limits: 28 KB, no line over 200 characters, ASCII only. The engine is copied into every page
# that has a map, and where no shell can read it the model types it out by hand. ---
bytes="$(wc -c < "$E" | tr -d ' ')"
[ "$bytes" -le 28672 ] || fail "the engine is $bytes bytes; the cap is 28672"
long="$(awk 'length($0) > 200 { n++ } END { print n + 0 }' "$E")"
[ "$long" -eq 0 ] || fail "$long line(s) are longer than 200 characters"
if LC_ALL=C grep -q '[^[:print:][:space:]]' "$E"; then fail "the engine must be ASCII only"; fi
ok "limits: $bytes of 28672 bytes, no line over 200 characters, ASCII only"

# --- nothing the page contract forbids ---
if grep -qi '</script' "$E"; then fail "the engine must never contain </script: it would close its own block"; fi
if grep -q '<!--' "$E"; then fail "the engine must not contain an HTML comment opener"; fi
if grep -qE '#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?([^0-9a-zA-Z]|$)' "$E"; then fail "the engine must hold no hex colour: colours are design-system tokens in the CSS"; fi
if grep -qiE 'JetBrains|Instrument Serif|DM Sans|monospace|sans-serif' "$E"; then fail "the engine must hold no font name: it measures text with the page's own font"; fi
if grep -q 'innerHTML' "$E"; then fail "the engine must not build markup from strings: author text goes in by textContent"; fi
if grep -qE '(^|[^A-Za-z0-9_.])eval\(|document\.write' "$E"; then fail "the engine must not use eval or document.write"; fi
ok "no </script, no hex colour, no font name, no innerHTML"

# --- it parses, and the pure layout passes the harness ---
if ! command -v node >/dev/null 2>&1; then
  [ -z "${CI:-}" ] || fail "node is required in CI"
  echo "SKIP: node is not installed, so the engine was not parsed and its layout was not run"
  exit 0
fi
# Node reads the nearest package.json above a file before it runs it, and fails on an invalid one.
# The engine is checked as a copy beside a package.json of the belt's own, and the harness sits
# beside tests/walkthrough/sysmap/package.json, so a stray one above the repository cannot fail
# this belt (the docs bot's job had one: drift queue PR144-1).
SHIELD="$ROOT/tests/walkthrough/sysmap/package.json"
grep -qE '"type": *"commonjs"' "$SHIELD" 2>/dev/null \
  || fail "tests/walkthrough/sysmap/package.json must exist and set \"type\": \"commonjs\": it keeps node from reading a package.json above the repository"
T="$(mktemp -d "${TMPDIR:-/tmp}/sysmap-engine.XXXXXX")"
trap 'rm -rf "$T"' EXIT
printf '{"private": true, "type": "commonjs"}\n' > "$T/package.json"
cp "$E" "$T/system-map-engine.js"
node --check "$T/system-map-engine.js" || fail "the engine does not parse"
node "$H" "$T/system-map-engine.js" || fail "the layout harness failed"
echo "PASS: system-map engine"
