#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/collect-git-context.sh"
fail(){ echo "FAIL: $1"; exit 1; }

# Clean up temp dirs on any exit (incl. early `fail`); init for set -u safety.
tmp=""; tmp3=""
trap 'rm -rf "$tmp" "$tmp3" 2>/dev/null' EXIT

# 1) inside this repo: emits the expected keys
out="$(bash "$SCRIPT" "$HERE")" || fail "non-zero exit inside repo"
for key in '"branch"' '"in_repo"' '"changed_files"' '"recent_log"'; do
  echo "$out" | grep -q "$key" || fail "missing $key"
done
echo "$out" | grep -q '"in_repo": *true' || fail "in_repo should be true"

# 2) outside a repo: exits 0 and reports in_repo false
tmp="$(mktemp -d)"; out2="$(bash "$SCRIPT" "$tmp")" || fail "non-zero exit outside repo"
echo "$out2" | grep -q '"in_repo": *false' || fail "in_repo should be false outside repo"
rm -rf "$tmp"

# 3) tricky filenames + quoted/backslashed commit message: output must be valid JSON
tmp3="$(mktemp -d)"
(
  cd "$tmp3" || exit 1
  git init -q
  git config user.email "t@t.t"; git config user.name "t"
  printf 'x' > 'wa"ck\et.txt'                  # committed file: quote + backslash in name
  git add -A
  git commit -q -m 'commit with "quotes" and a \backslash'
  printf 'y' > 'un"tracked\file.txt'           # uncommitted: exercises changed_files
)
out3="$(bash "$SCRIPT" "$tmp3")" || fail "non-zero exit on tricky repo"
echo "$out3" | python3 -m json.tool >/dev/null 2>&1 || fail "invalid JSON on tricky filenames/message"
rm -rf "$tmp3"

echo "PASS"
