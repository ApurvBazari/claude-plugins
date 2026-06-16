#!/usr/bin/env bash
# shellcheck disable=SC2034  # FAILED is set by the assert helpers and read by the sourcing test_*.sh files
# Shared helpers for doc-audit tests. Source this from each test_*.sh.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/.claude/skills/doc-audit/scripts/audit-docs.sh"

# make_skill DIR NAME [extra frontmatter lines...]
make_skill() {
  local d="$1" nm="$2"; shift 2
  mkdir -p "$d/skills/$nm"
  {
    echo "---"
    echo "name: $nm"
    echo "description: does $nm things"
    local line; for line in "$@"; do echo "$line"; done
    echo "---"
    echo "# $nm"
  } > "$d/skills/$nm/SKILL.md"
}

# make_clean_fixture ROOT  — a fully-consistent 2-plugin marketplace (audits clean)
make_clean_fixture() {
  local r="$1"
  mkdir -p "$r/.claude-plugin" "$r/alpha/.claude-plugin" "$r/beta/.claude-plugin" \
           "$r/site/alpha" "$r/site/beta"
  cat > "$r/.claude-plugin/marketplace.json" <<'JSON'
{ "name":"test","owner":{"name":"t"},"plugins":[
  {"name":"alpha","source":"./alpha","version":"1.0.0","description":"Alpha plugin"},
  {"name":"beta","source":"./beta","version":"1.0.0","description":"Beta plugin"}
]}
JSON
  cat > "$r/alpha/.claude-plugin/plugin.json" <<'JSON'
{"name":"alpha","version":"1.0.0","description":"Alpha plugin","author":{"name":"t"},"license":"MIT","keywords":["a"]}
JSON
  cat > "$r/beta/.claude-plugin/plugin.json" <<'JSON'
{"name":"beta","version":"1.0.0","description":"Beta plugin","author":{"name":"t"},"license":"MIT","keywords":["b"]}
JSON
  make_skill "$r/alpha" foo
  make_skill "$r/alpha" setup "disable-model-invocation: true"
  make_skill "$r/alpha" helper "user-invocable: false"
  make_skill "$r/beta" bar
  cat > "$r/alpha/README.md" <<'MD'
# alpha
## Skills
### `/alpha:foo`
Does foo.
### `/alpha:setup` *(destructive — user-invoked only)*
Sets up.
MD
  cat > "$r/beta/README.md" <<'MD'
# beta
## Skills
### `/beta:bar`
Does bar.
MD
  cat > "$r/README.md" <<'MD'
# test marketplace
Two plugins: **alpha** and **beta**.
## Commands
- `/alpha:foo`, `/alpha:setup`
- `/beta:bar`
MD
  echo "<html>alpha</html>" > "$r/site/alpha/index.html"
  echo "<html>beta</html>" > "$r/site/beta/index.html"
}

# audit_tsv ROOT  — print findings as TSV (one per line)
audit_tsv() { bash "$SCRIPT" --root "$1" --format tsv 2>/dev/null; }

# assert_finding ROOT CODE
assert_finding() {
  local out; out="$(audit_tsv "$1")"
  if grep -q $'\t'"$2"$'\t' <<<"$out"; then
    echo "  ok: $2 present"
  else
    echo "  FAIL: expected finding $2"; FAILED=1
  fi
}

# assert_no_finding ROOT CODE
assert_no_finding() {
  local out; out="$(audit_tsv "$1")"
  if grep -q $'\t'"$2"$'\t' <<<"$out"; then
    echo "  FAIL: unexpected finding $2"; FAILED=1
  else
    echo "  ok: $2 absent"
  fi
}

# assert_clean ROOT  — no findings, exit 0
assert_clean() {
  local out rc
  out="$(audit_tsv "$1")"; rc=$?
  if [[ -z "$out" && $rc -eq 0 ]]; then
    echo "  ok: clean"
  else
    echo "  FAIL: expected clean; rc=$rc out=[$out]"; FAILED=1
  fi
}
