#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
MERGE="$REPO_ROOT/handoff/scripts/merge-fm-key.sh"
# shellcheck source=./lib.sh
. "$HERE/lib.sh"

trap cleanup EXIT
setup_fake_project >/dev/null

read_file() { cat "$1" 2>/dev/null; }

# --- Case 1: file doesn't exist → bootstrap ---
target="$FIXTURE_ROOT/.claude/handoff/settings.md"
rm -f "$target"
bash "$MERGE" "$target" archive-retention 10
got="$(read_file "$target")"
expected='---
archive-retention: 10
---'
assert_eq "$expected" "$got" "bootstrap: file did not exist"

# --- Case 2: file exists with frontmatter, key absent → APPEND ---
cat > "$target" <<EOF
---
gitignore-prompt: never
---
EOF
bash "$MERGE" "$target" archive-retention 10
got="$(read_file "$target")"
expected='---
gitignore-prompt: never
archive-retention: 10
---'
assert_eq "$expected" "$got" "append: key absent, frontmatter intact"

# --- Case 3: file exists with frontmatter, key present → REPLACE in place ---
cat > "$target" <<EOF
---
gitignore-prompt: never
archive-retention: 5
---
EOF
bash "$MERGE" "$target" archive-retention 20
got="$(read_file "$target")"
expected='---
gitignore-prompt: never
archive-retention: 20
---'
assert_eq "$expected" "$got" "replace: existing key updated, siblings preserved"

# --- Case 4: replace key that is the only key in frontmatter ---
cat > "$target" <<EOF
---
deferred-at: 2026-01-01T00:00:00Z
---
EOF
bash "$MERGE" "$target" deferred-at 2026-05-20T00:00:00Z
got="$(read_file "$target")"
expected='---
deferred-at: 2026-05-20T00:00:00Z
---'
assert_eq "$expected" "$got" "replace: single-key frontmatter"

# --- Case 5: append into a file with frontmatter AND a body ---
cat > "$target" <<EOF
---
gitignore-prompt: never
---

# Body heading

Body paragraph that should survive untouched.
EOF
bash "$MERGE" "$target" archive-retention 10
got="$(read_file "$target")"
expected='---
gitignore-prompt: never
archive-retention: 10
---

# Body heading

Body paragraph that should survive untouched.'
assert_eq "$expected" "$got" "append: body content preserved verbatim"

# --- Case 6: idempotency — running twice with the same value is a no-op ---
cat > "$target" <<EOF
---
archive-retention: 10
---
EOF
bash "$MERGE" "$target" archive-retention 10
bash "$MERGE" "$target" archive-retention 10
got="$(read_file "$target")"
expected='---
archive-retention: 10
---'
assert_eq "$expected" "$got" "idempotent: same value twice = unchanged"

summary
