#!/usr/bin/env bash
# Unit tests for handoff/scripts/handoff-lib.sh — the single source of truth for
# frontmatter reading, body extraction, ISO parsing, and retention normalization.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib.sh"
# shellcheck source=/dev/null
. "$REPO_ROOT/handoff/scripts/handoff-lib.sh"

tmp="$(mktemp)"
# A frontmatter doc whose BODY contains a `---` horizontal rule and a `key:`-shaped line.
cat > "$tmp" <<'EOF'
---
saved-at: 2026-07-01T10:00:00Z
saved-at-sha: abc123
deferred-at: "2026-07-02T09:00:00Z"
---
Intro paragraph.

---

saved-at: NOT-A-REAL-KEY-IN-BODY
More body text.
EOF

# get_fm_value reads only real frontmatter, strips quotes, ignores body `key:` lines
assert_eq "2026-07-01T10:00:00Z" "$(hf_get_fm_value "$tmp" saved-at)"     "fm: saved-at"
assert_eq "abc123"               "$(hf_get_fm_value "$tmp" saved-at-sha)" "fm: saved-at-sha"
assert_eq "2026-07-02T09:00:00Z" "$(hf_get_fm_value "$tmp" deferred-at)"  "fm: deferred-at (quotes stripped)"
assert_eq ""                     "$(hf_get_fm_value "$tmp" missing-key)"  "fm: absent key → empty"
assert_eq ""                     "$(hf_get_fm_value /no/such/file key)"   "fm: missing file → empty"

# get_body returns text after the closing --- and is NOT polluted by the body `---`
body="$(hf_get_body "$tmp")"
assert_contains "Intro paragraph." "$body" "body: includes first line after fm"
assert_contains "More body text."  "$body" "body: includes text past the body hr"

# iso_to_epoch: valid → >0; garbage/empty → 0
assert_eq "1"  "$([[ "$(hf_iso_to_epoch 2026-07-01T10:00:00Z)" -gt 0 ]] && echo 1 || echo 0)" "iso: valid → >0"
assert_eq "0"  "$(hf_iso_to_epoch not-a-date)" "iso: garbage → 0"
assert_eq "0"  "$(hf_iso_to_epoch "")"         "iso: empty → 0"

# normalize_retention: the H6 contract
assert_eq "unlimited" "$(hf_normalize_retention unlimited)" "ret: unlimited"
assert_eq "unlimited" "$(hf_normalize_retention -1)"        "ret: -1 → unlimited"
assert_eq "unlimited" "$(hf_normalize_retention null)"      "ret: null → unlimited (H6)"
assert_eq "0"         "$(hf_normalize_retention 0)"         "ret: 0 stays 0 (delete-all)"
assert_eq "5"         "$(hf_normalize_retention 5)"         "ret: positive int"
assert_eq "10"        "$(hf_normalize_retention '')"        "ret: empty → default 10"
assert_eq "10"        "$(hf_normalize_retention 'x;rm -rf')" "ret: hostile non-numeric → 10"

rm -f "$tmp"
summary
