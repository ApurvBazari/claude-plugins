#!/usr/bin/env bash
# test_maintain_tables_parity.sh — maintain-detect keeps its own copies of the language, vendor,
# config and MCP-signal tables (spec § 15: the shipped detectors are not refactored). This belt
# fails when a copy drifts from its source: the LANGUAGES rows and the vendor prune list are
# compared as text with detect-lsp-signals.sh, the config basenames through the hook's own `case`
# patterns, and the MCP signals behaviourally against detect-mcp-signals.sh on the same trees.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/onboard/maintain-helpers.sh
. "$ROOT/tests/onboard/maintain-helpers.sh"

S="$ROOT/onboard/scripts"
LIB="$S/maintain-lib"
py_tables() { (cd "$LIB" && python3 -B -c "import tables; $1"); }

# --- LANGUAGES: same rows, same order, same extensions ---
from_script="$(grep -E '^  "[a-z-]+\|[a-z-]+\|' "$S/detect-lsp-signals.sh" | tr -d '" ')"
from_python="$(py_tables 'print("\n".join("%s|%s|%s" % (l, p, "".join(e)) for l, p, e in tables.LANGUAGES))')"
expect "LANGUAGES rows match detect-lsp-signals.sh" "$from_script" "$from_python"
[ -n "$from_script" ] || fail "no LANGUAGES rows extracted — the extraction pattern no longer matches the script"

# --- vendor prune list ---
from_script="$(sed -n '/-type d \\(/,/-prune/p' "$S/detect-lsp-signals.sh" | grep -oE -- '-name [^ ]+' | awk '{print $2}' | sort)"
from_python="$(py_tables 'print("\n".join(sorted(tables.VENDOR_DIRS)))')"
expect "VENDOR_DIRS match detect-lsp-signals.sh's prune list" "$from_script" "$from_python"

# --- config basenames: the hook's own case patterns decide, minus pyproject.toml (a manifest here) ---
patterns="$(grep -E '^\s*tsconfig\*\.json\|' "$S/detect-config-changes.sh" | head -1 | sed 's/^[[:space:]]*//; s/)[[:space:]]*$//')"
[ -n "$patterns" ] || fail "could not extract detect-config-changes.sh's case patterns"
for name in tsconfig.json tsconfig.build.json .eslintrc .eslintrc.cjs eslint.config.mjs prettier.config.js \
            .prettierrc .prettierrc.json biome.json ruff.toml .ruff.toml package.json vite.config.ts; do
  # shellcheck disable=SC2254
  hook="$(eval "case \"\$name\" in $patterns) echo yes ;; *) echo no ;; esac")"
  mine="$(py_tables "print('yes' if any(p.match('$name') for p in tables.CONFIG_PATTERNS) else 'no')")"
  expect "config basename $name" "$hook" "$mine"
done

# --- MCP signals: both detectors agree on the same tree (context7 is always-on, never an item) ---
mcp_start() {  # a repo whose base is an empty commit, so every signal present now is "new"
  new_repo "mcp-$1"
  git commit -q --allow-empty -m empty
  # shellcheck disable=SC2034  # BASE is read by detect() in maintain-helpers.sh
  BASE="$(git rev-parse HEAD)"
}
mcp_check() {
  local script mine
  script="$(bash "$S/detect-mcp-signals.sh" "$REPO" | python3 -c 'import json,sys; print(" ".join(sorted(s["server"] for s in json.load(sys.stdin) if s["server"] != "context7")))')"
  detect
  mine="$(q '" ".join(sorted(i["name"] for i in d["items"] if i["kind"] == "signal-mcp"))')"
  expect "MCP parity ($1)" "$script" "$mine"
}

mcp_start files
put .github/workflows/ci.yml 'on: push'
put vercel.json '{}'
put prisma/schema.prisma 'datasource db {}'
put supabase/config.toml 'x'
put package.json '{"name":"x","dependencies":{"react":"^19"}}'
mcp_check "signal files + react"

mcp_start deps
put package.json '{"name":"x","dependencies":{"@vercel/analytics":"^1","@prisma/client":"^6","@supabase/supabase-js":"^2","next":"^15"}}'
mcp_check "dependency signals"

mcp_start none
put package.json '{"name":"x","dependencies":{"@remix-run/react":"^2","lodash":"^4"}}'
mcp_check "no signal (the copied @remix-run/ pattern never matches, in both)"

echo
if [ "$failures" -eq 0 ]; then echo "test_maintain_tables_parity: all checks passed"; exit 0; fi
echo "test_maintain_tables_parity: $failures check(s) failed"; exit 1
