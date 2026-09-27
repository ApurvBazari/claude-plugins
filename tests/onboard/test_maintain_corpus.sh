#!/usr/bin/env bash
# test_maintain_corpus.sh — maintain-detect over the two corpora (spec § 11, D23). AC16, AC20.
#
# Shapes (always run, no network, no model): every shape in maintain-corpus/shapes.json, with one
# script added, gives exactly one script-added apply item — the fixtures are valid detect inputs
# and none of them pre-mentions the script.
#
# Ranges (local repos): audit-labels.py first checks every label item against plain git evidence
# (sharing no code with detect, so a label drafted from detect's output cannot pass by construction).
# Then each labelled range in maintain-corpus/ranges.json is replayed read-only —
# `git clone --shared` into a temp dir (no write to the source repo, not even a worktree entry),
# head checked out, tooling restored to base when the label says so — and detect's items must equal
# the label. A range whose repo is not on this machine is SKIPPED and counted; set
# MAINTAIN_CORPUS_REQUIRED=1 (the feature's exit gate does) to turn a skip into a failure.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/onboard/maintain-helpers.sh
. "$ROOT/tests/onboard/maintain-helpers.sh"
CORPUS="$ROOT/tests/onboard/maintain-corpus"

# --- shapes ---
while IFS='|' read -r shape package; do
  REPO="$SCRATCH/shape-$shape"
  bash "$CORPUS/build-shape.sh" "$shape" "$REPO" >/dev/null || { fail "shape $shape did not build"; continue; }
  cd "$REPO" || exit 1
  BASE="$(git rev-parse HEAD)"
  python3 "$CORPUS/add-script.py" "$package" price:check "tsx scripts/price-check.ts"
  detect
  expect "shape $shape: one script-added apply item for $package" "script-added:apply $package" \
    "$(q '" ".join(i["kind"] + ":" + i["disposition"] + " " + i.get("file", "") for i in d["items"])')"
done < <(python3 -c 'import json,sys
for name, spec in json.load(open(sys.argv[1]))["shapes"].items(): print(name + "|" + spec["package"])' "$CORPUS/shapes.json")

# --- ranges: first the labels themselves, against plain git evidence (no detect code) ---
if audit_out="$(python3 -B "$CORPUS/audit-labels.py" 2>&1)"; then
  echo "ok: every label item is supported by its range's git evidence"
else
  fail "a label item is not supported by git evidence:"
  printf '%s\n' "$audit_out" | grep UNSUPPORTED
fi

# --- ranges: then detect against the labels ---
ran=0
skipped=0
while IFS='|' read -r id repo base head restore; do
  repo="${repo/#\~/$HOME}"
  if [ ! -d "$repo/.git" ] || ! git -C "$repo" cat-file -e "$head^{commit}" 2>/dev/null; then
    skipped=$((skipped + 1))
    if [ "${MAINTAIN_CORPUS_REQUIRED:-0}" = 1 ]; then fail "range $id: $repo (or $head) not available"; else echo "SKIP: range $id — $repo not on this machine"; fi
    continue
  fi
  status_before="$(git -C "$repo" status --porcelain=v1 -uall | shasum)"
  head_before="$(git -C "$repo" rev-parse HEAD)"
  REPO="$SCRATCH/range-$id"
  if ! { git clone -q --shared --no-checkout "$repo" "$REPO" && git -C "$REPO" checkout -q --detach "$head"; }; then
    fail "range $id: could not check out $head"
    continue
  fi
  cd "$REPO" || exit 1
  if [ "$restore" = true ]; then
    # The code change without the author's own tooling edit: what a matali run hands detect.
    python3 - "$base" <<'PY'
import os, subprocess, sys
base = sys.argv[1]
def ls(ref):
    return set(subprocess.check_output(["git", "ls-tree", "-r", "--name-only", ref]).decode().splitlines())
def tooling(p):
    return os.path.basename(p) in ("CLAUDE.md", "CLAUDE.local.md") or p.startswith(".claude/rules/")
at_base = ls(base)
for p in sorted(ls("HEAD")):
    if tooling(p) and p not in at_base:
        os.remove(p)
restore = sorted(p for p in at_base if tooling(p))
if restore:
    subprocess.check_call(["git", "checkout", base, "--"] + restore)
PY
  fi
  detect "$base"
  ran=$((ran + 1))
  diff_out="$(python3 - "$CORPUS/ranges.json" "$id" "$OUT" <<'PY'
import json, sys
ranges = {r["id"]: r for r in json.load(open(sys.argv[1]))["ranges"]}
want = ranges[sys.argv[2]]["expected"]
got = json.load(open(sys.argv[3]))
if "error" in got:
    print("detect error: %s" % got["error"]); sys.exit()
items = [{k: v for k, v in i.items() if k != "id"} for i in got["items"]]
if items != want["items"]:
    have = [json.dumps(i, sort_keys=True) for i in items]
    need = [json.dumps(i, sort_keys=True) for i in want["items"]]
    for line in need:
        if line not in have: print("  missing:    " + line[:220])
    for line in have:
        if line not in need: print("  unexpected: " + line[:220])
    if sorted(have) == sorted(need): print("  same items, different order")
if got["truncated"] != want["truncated"]:
    print("  truncated %s, label %s" % (got["truncated"], want["truncated"]))
PY
)"
  if [ -z "$diff_out" ]; then echo "ok: range $id matches its label"; else fail "range $id differs from its label:"; printf '%s\n' "$diff_out"; fi
  expect "range $id: source repo status unchanged" "$status_before" "$(git -C "$repo" status --porcelain=v1 -uall | shasum)"
  expect "range $id: source repo HEAD unchanged" "$head_before" "$(git -C "$repo" rev-parse HEAD)"
done < <(python3 -c 'import json,sys
for r in json.load(open(sys.argv[1]))["ranges"]:
    print("|".join([r["id"], r["repo"], r["base"], r["head"], "true" if r["restoreTooling"] else "false"]))' "$CORPUS/ranges.json")

echo
echo "ranges: $ran replayed, $skipped skipped"
if [ "$failures" -eq 0 ]; then echo "test_maintain_corpus: all checks passed"; exit 0; fi
echo "test_maintain_corpus: $failures check(s) failed"; exit 1
