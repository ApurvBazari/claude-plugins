#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
PRUNE="$REPO_ROOT/handoff/scripts/prune-archive.sh"
# shellcheck disable=SC1091
. "$HERE/lib.sh"

trap cleanup EXIT

# Helper: create N archive files with strictly increasing mtimes.
seed_archive() {
  local count="$1"
  for i in $(seq 1 "$count"); do
    local f
    f="$FIXTURE_ROOT/.claude/handoff/archive/consumed-$(printf '%05d' "$i").md"
    : > "$f"
    # Force monotonically increasing mtimes — touch with -t YYYYMMDDhhmm.ss
    touch -t "$(date -v+"${i}"M '+%Y%m%d%H%M.%S' 2>/dev/null \
                || date -d "+${i} minutes" '+%Y%m%d%H%M.%S')" "$f"
  done
}

count_archive() {
  find "$FIXTURE_ROOT/.claude/handoff/archive" -name '*.md' 2>/dev/null | wc -l | tr -d ' '
}

# --- Case 1: default cap (no settings file) keeps newest 10 of 15 ---
setup_fake_project >/dev/null
seed_archive 15
bash "$PRUNE" "$FIXTURE_ROOT"
assert_eq "10" "$(count_archive)" "default cap 10 prunes 15 → 10"
# Newest file (the 15th) must survive.
assert_file_exists "$FIXTURE_ROOT/.claude/handoff/archive/consumed-00015.md"
# Oldest must be gone.
assert_file_absent "$FIXTURE_ROOT/.claude/handoff/archive/consumed-00001.md"
cleanup

# --- Case 2: cap = 5 keeps newest 5 of 12 ---
setup_fake_project >/dev/null
seed_archive 12
mkdir -p "$FIXTURE_ROOT/.claude/handoff"
cat > "$FIXTURE_ROOT/.claude/handoff/settings.md" <<EOF
---
archive-retention: 5
---
EOF
bash "$PRUNE" "$FIXTURE_ROOT"
assert_eq "5" "$(count_archive)" "cap 5 prunes 12 → 5"
cleanup

# --- Case 3: cap = 0 removes everything ---
setup_fake_project >/dev/null
seed_archive 4
cat > "$FIXTURE_ROOT/.claude/handoff/settings.md" <<EOF
---
archive-retention: 0
---
EOF
bash "$PRUNE" "$FIXTURE_ROOT"
assert_eq "0" "$(count_archive)" "cap 0 removes everything"
cleanup

# --- Case 4: cap = unlimited keeps everything ---
setup_fake_project >/dev/null
seed_archive 20
cat > "$FIXTURE_ROOT/.claude/handoff/settings.md" <<EOF
---
archive-retention: unlimited
---
EOF
bash "$PRUNE" "$FIXTURE_ROOT"
assert_eq "20" "$(count_archive)" "cap 'unlimited' keeps all"
cleanup

# --- Case 5: no archive dir at all is a no-op (no crash) ---
setup_fake_project >/dev/null
rm -rf "$FIXTURE_ROOT/.claude/handoff/archive"
bash "$PRUNE" "$FIXTURE_ROOT"
rc=$?
assert_eq "0" "$rc" "missing archive/ dir → exit 0 silently"
cleanup

# --- Case 6: cap = null also skips pruning (spec synonym for unlimited) ---
setup_fake_project >/dev/null
seed_archive 18
cat > "$FIXTURE_ROOT/.claude/handoff/settings.md" <<EOF
---
archive-retention: null
---
EOF
bash "$PRUNE" "$FIXTURE_ROOT"
assert_eq "18" "$(count_archive)" "cap 'null' keeps all (spec synonym)"
cleanup

# --- Case 7: cap = -1 also skips pruning ---
setup_fake_project >/dev/null
seed_archive 14
cat > "$FIXTURE_ROOT/.claude/handoff/settings.md" <<EOF
---
archive-retention: -1
---
EOF
bash "$PRUNE" "$FIXTURE_ROOT"
assert_eq "14" "$(count_archive)" "cap '-1' keeps all (spec synonym)"
cleanup

summary
