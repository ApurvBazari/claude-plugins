#!/usr/bin/env bash
# replay-3.2.0.sh — acceptance AC-R (release-docs spec § 8). Run today's detector over the tree the
# 3.2.0 release shipped (8648454, i.e. the docs just before #127) with the release's range
# (a6ef6ee..8648454), and require that it flags what #127 fixed. Manual: it needs full history, so
# it is not a run-all belt (CI checks out shallow, and the name deliberately misses its discovery).
#
# The docs are 3.2.0-era; the tooling is today's: the release-docs skill, .github/docs-surfaces.json
# (with retired[]) and doc-audit are copied in, and the ledger is today's intentional[] with no
# entries. The detached worktree lives under $TMPDIR and is removed on every exit path.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE=a6ef6ee
TIP=8648454
git -C "$ROOT" cat-file -e "$TIP^{commit}" 2>/dev/null || { echo "replay: $TIP is not in this clone's history"; exit 2; }
git -C "$ROOT" cat-file -e "$BASE^{commit}" 2>/dev/null || { echo "replay: $BASE is not in this clone's history"; exit 2; }

W="$(mktemp -d "${TMPDIR:-/tmp}/replay.XXXXXX")" || { echo "replay: mktemp failed"; exit 2; }
WREAL="$(cd "$W" && pwd -P)" || { rmdir "$W" 2>/dev/null; echo "replay: resolving \$W failed"; exit 2; }
W="$WREAL"
cleanup() {
  # Only ever our own mktemp'd directory: an empty or foreign $W would aim the removals at /tree or "".
  [ -n "${W:-}" ] || return 0
  case "${W##*/}" in replay.??????) ;; *) return 0 ;; esac
  git -C "$ROOT" worktree remove --force "$W/tree" >/dev/null 2>&1 || true
  rm -rf "$W"
  # A worktree add that died half-way leaves its registration behind; drop only ours.
  if git -C "$ROOT" worktree list --porcelain | grep -Fxq "worktree $W/tree"; then
    git -C "$ROOT" worktree prune >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

git -C "$ROOT" worktree add -q --detach "$W/tree" "$TIP" || { echo "replay: worktree add failed"; exit 1; }

# The docs are 3.2.0-era; the tooling (detector, surfaces with retired[], doc-audit) is today's.
rm -rf "$W/tree/.claude/skills/release-docs" "$W/tree/.claude/skills/doc-audit"
mkdir -p "$W/tree/.claude/skills" "$W/tree/.github" || { echo "replay: mkdir failed"; exit 1; }
cp -R "$ROOT/.claude/skills/release-docs" "$ROOT/.claude/skills/doc-audit" "$W/tree/.claude/skills/" \
  || { echo "replay: copying the skills failed"; exit 1; }
cp "$ROOT/.github/docs-surfaces.json" "$W/tree/.github/docs-surfaces.json" \
  || { echo "replay: copying docs-surfaces.json failed"; exit 1; }
python3 - "$ROOT/.github/docs-ledger.json" "$W/tree/.github/docs-ledger.json" <<'PY' || { echo "replay: writing the ledger failed"; exit 1; }
import json, sys
led = json.load(open(sys.argv[1]))
json.dump({"schemaVersion": 1, "entries": {}, "intentional": led["intentional"]}, open(sys.argv[2], "w"))
PY

bash "$W/tree/.claude/skills/release-docs/scripts/docs-detect.sh" --root "$W/tree" \
  --range "$BASE..$TIP" --out "$W/obligations.json" || { echo "replay: detect failed"; exit 1; }

python3 - "$W/obligations.json" <<'PY'
import collections, json, sys
obs = json.load(open(sys.argv[1]))["obligations"]
def m(kind, plugin=None, file=None, where=None):
    """A predicate over one obligation."""
    return lambda o: (o["kind"] == kind and (plugin is None or o["plugin"] == plugin)
                      and (file is None or o["file"] == file) and (where is None or where(o)))
PAGE = "site/onboard/index.html"
checks = [
    ("changelog-entry onboard 3.2.0 = 6", 6,
     m("changelog-entry", "onboard", where=lambda o: o.get("version") == "3.2.0")),
    ("badge-version onboard = 3 (nav, footer, landing)", 3, m("badge-version", "onboard")),
    ("inventory-count onboard skills 10 -> 11", 1,
     m("inventory-count", "onboard", PAGE, lambda o: o.get("expected") == 11 and o.get("found") == 10)),
    ("inventory-row onboard page lacks maintain", 1,
     m("inventory-row", "onboard", PAGE, lambda o: o.get("item") == "maintain")),
    ("prerequisite-new python3 on the onboard page", 1,
     m("prerequisite-new", "onboard", PAGE, lambda o: o.get("item") == "python3")),
    ("stale-mention greenfield-drift.json twice on the onboard page", 2,
     m("stale-mention", "onboard", PAGE, lambda o: "greenfield-drift.json" in o.get("token", ""))),
    ("card-description notify", 1, m("card-description", "notify")),
]
bad = 0
for label, want, pred in checks:
    got = sum(1 for o in obs if pred(o))
    if got == want:
        print("ok:   " + label)
    else:
        bad += 1
        print("FAIL: %s (got %d)" % (label, got))
# Extras: every obligation no asserted check claims (the README's python3 bullet among them).
extra = [o for o in obs if not any(pred(o) for _l, _w, pred in checks)]
print("\nextras (review; not failures): %d" % len(extra))
for o in extra:
    print("  %s %s — %s" % (o["kind"], o["file"], o["detail"]))
print("\nall kinds:", dict(collections.Counter(o["kind"] for o in obs)))
sys.exit(1 if bad else 0)
PY
