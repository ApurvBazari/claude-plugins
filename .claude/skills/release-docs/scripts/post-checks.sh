#!/usr/bin/env bash
# post-checks.sh — the deterministic checks after a /release-docs apply (release-docs spec § 6–7).
#
# Usage:
#   post-checks.sh --snapshot FILE                                 # BEFORE the apply
#   post-checks.sh --before FILE [--report FILE.md] [--shots DIR]  # after it
#   --snapshot records HEAD and every path dirty before the run, with a digest of its content
#   (JSON). --before takes that file; a plain `git status` text snapshot is refused (exit 2).
#   Keep the snapshot outside the checkout, where the run cannot rewrite it.
# In order:
#   1. the write fence (docs-detect.sh --fence) — each path the run changed outside the doc
#      surfaces is restored from HEAD (tracked) or removed (new). The allowlist comes from HEAD's
#      docs-surfaces.json and marketplace, and the run may change only og and retired in that file.
#      A path dirty before the run is never restored or removed: the run touching one outside the
#      surfaces fails, and is left for the owner;
#   2. no "waived" disposition added to the ledger (waivers are owner-only);
#   3. docs-detect --gate;
#   4. render-check on the changed landing and plugin pages (never og-card.html or frozen paths);
#   5. tests/run-all.sh and the .github/scripts guards.
# RELEASE_DOCS_SKIP=gate,render,belts skips steps 3–5 (belts only; CI never sets it).
# Exit: 0 all passed, 1 any failed, 2 bad input — the fence did not run on a bad snapshot, so a
# caller must never commit the tree after an exit 2.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

usage() {
  echo "post-checks: $*" >&2
  echo "usage: post-checks.sh --snapshot FILE | --before FILE [--report FILE.md] [--shots DIR]" >&2
  exit 2
}
snapshot=""
before=""
report="/dev/null"
shots=""
while [ $# -gt 0 ]; do
  case "$1" in
    --snapshot|--before|--report|--shots) [ $# -ge 2 ] && [ -n "$2" ] || usage "$1 needs a value" ;;
  esac
  case "$1" in
    --snapshot) snapshot="$2"; shift 2 ;;
    --before) before="$2"; shift 2 ;;
    --report) report="$2"; shift 2 ;;
    --shots) shots="$2"; shift 2 ;;
    *) usage "unknown argument $1" ;;
  esac
done
if [ -n "$snapshot" ]; then
  [ -z "$before" ] && [ "$report" = /dev/null ] && [ -z "$shots" ] \
    || usage "--snapshot runs alone, before the apply"
  exec bash "$HERE/docs-detect.sh" --snapshot "$snapshot"
fi
[ -n "$before" ] && [ -f "$before" ] || usage "--before SNAPSHOT is required"
[ "$report" = /dev/null ] || { : > "$report"; } 2>/dev/null || usage "cannot write the report $report"

skip() { case ",${RELEASE_DOCS_SKIP:-}," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
say() { printf '%s\n' "$*"; [ "$report" = /dev/null ] || printf '%s\n' "$*" >> "$report"; }
indent() { printf '%s\n' "$1" | sed 's/^/    /'; }
fails=0

# 1. write fence. Exit 1 = something fenced or failed (reported line by line); anything above 1
# means it could not run at all (bad snapshot, git failing), so nothing was restored or removed.
frc=0
fence_out="$(bash "$HERE/docs-detect.sh" --fence --before "$before" 2>&1)" || frc=$?
if [ "$frc" -gt 1 ]; then
  say "- FAIL: the write fence could not run, so nothing was restored or removed (exit $frc)"
  say "$(indent "$fence_out")"
  exit 2
fi
say "$fence_out"
[ "$frc" -eq 0 ] || fails=1

# 2. no waiver added. Both ledger versions are parsed, not line-diffed: a re-dumped or reformatted
# ledger shows the owner's existing waivers as "+" lines without adding any. Fails on a waived id
# HEAD lacks as waived, on a changed existing waiver, and on a ledger that cannot be read.
waiver_changes() { # <ledger path> — prints one line per problem; exit 1 when there is any
  python3 - "$1" <<'PY'
import json, os, subprocess, sys

rel = sys.argv[1]


def waivers(raw, where):
    """{id: declaration} for the waived entries, or a string saying why they cannot be read."""
    try:
        d = json.loads(raw)
    except ValueError as e:
        return "%s is not valid JSON: %s" % (where, e)
    ents = d.get("entries") if isinstance(d, dict) else None
    if not isinstance(ents, dict):
        return "%s has no entries object, so its waivers cannot be checked" % where
    return {k: v for k, v in ents.items() if isinstance(v, dict) and v.get("disposition") == "waived"}


p = subprocess.run(["git", "show", "HEAD:" + rel], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
was = waivers(p.stdout.decode("utf-8", "replace"), "HEAD:" + rel) if p.returncode == 0 else {}
if isinstance(was, str):
    was = {}  # an unreadable committed ledger vouches for nothing: every waiver counts as new
if not os.path.exists(rel):
    sys.exit(0)
with open(rel, encoding="utf-8", errors="replace") as f:
    now = waivers(f.read(), rel)
if isinstance(now, str):
    print(now)
    sys.exit(1)
bad = ["%s (added)" % k for k in sorted(now) if k not in was]
bad += ["%s (changed)" % k for k in sorted(now) if k in was and now[k] != was[k]]
for b in bad:
    print(b)
sys.exit(1 if bad else 0)
PY
}
if waiver_out="$(waiver_changes .github/docs-ledger.json 2>&1)"; then
  say "- ok: no waiver added"
else
  say "- FAIL: the run added or changed a \"waived\" disposition — waivers are owner-only"
  say "$(indent "$waiver_out")"
  fails=1
fi

# 3. gate
if ! skip gate; then
  if gate_out="$(bash "$HERE/docs-detect.sh" --gate 2>&1)"; then
    say "- ok: docs-detect gate (0 open)"
  else
    say "- FAIL: docs-detect gate"
    say "$(indent "$gate_out")"
    fails=1
  fi
fi

# 4. render — the changed landing and plugin pages, as HEAD's config names them (docs-detect.sh
# --render-pages): never og-card.html (a 1200px card, not a page), never a frozen path.
if ! skip render; then
  prc=0
  page_list="$(bash "$HERE/docs-detect.sh" --render-pages 2>&1)" || prc=$?
  pages=()
  if [ "$prc" -eq 0 ]; then
    while IFS= read -r p; do
      [ -z "$p" ] || pages+=("$p")
    done <<EOF
$page_list
EOF
  fi
  if [ "$prc" -ne 0 ]; then
    say "- FAIL: render-check could not select the changed pages"
    say "$(indent "$page_list")"
    fails=1
  elif [ ${#pages[@]} -eq 0 ]; then
    say "- ok: render-check (no site page changed)"
  elif render_out="$(bash "$HERE/render-check.sh" ${shots:+--shots "$shots"} "${pages[@]}" 2>&1)"; then
    say "- ok: render-check (${#pages[@]} page(s))"
  else
    say "- FAIL: render-check"
    say "$(indent "$render_out")"
    fails=1
  fi
fi

# 5. belts + guards
if ! skip belts; then
  if bash tests/run-all.sh >/dev/null 2>&1; then say "- ok: tests/run-all.sh"; else say "- FAIL: tests/run-all.sh"; fails=1; fi
  guard_fails=0
  for g in validate-manifests check-structure check-references check-action-pinning check-version-sync \
           check-state-gitignore check-notify-delegation check-phase-numbering check-phase-tracking \
           check-skill-refs check-ref-paths; do
    bash ".github/scripts/$g.sh" >/dev/null 2>&1 || { say "- FAIL: guard $g"; guard_fails=1; fails=1; }
  done
  [ "$guard_fails" -ne 0 ] || say "- ok: every .github/scripts guard"
fi

exit "$fails"
