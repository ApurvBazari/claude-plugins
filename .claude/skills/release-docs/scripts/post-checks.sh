#!/usr/bin/env bash
# post-checks.sh — the deterministic checks after a /release-docs apply (release-docs spec § 6–7).
#
# Usage: post-checks.sh --before SNAPSHOT [--report FILE.md] [--shots DIR]
#   SNAPSHOT is `git status --porcelain --untracked-files=all`, taken before the apply.
# In order:
#   1. the write fence — each path the run changed that is outside the doc surfaces is restored
#      from HEAD (tracked) or removed (new); paths already dirty before the run are left alone;
#   2. no "waived" disposition added to the ledger (waivers are owner-only);
#   3. docs-detect --gate;
#   4. render-check on every changed site page;
#   5. tests/run-all.sh and the .github/scripts guards.
# RELEASE_DOCS_SKIP=gate,render,belts skips steps 3–5 (belts only; CI never sets it).
# Exit: 0 all passed, 1 any failed, 2 bad input.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

usage() { echo "post-checks: $*" >&2; echo "usage: post-checks.sh --before SNAPSHOT [--report FILE.md] [--shots DIR]" >&2; exit 2; }
before=""
report="/dev/null"
shots=""
while [ $# -gt 0 ]; do
  case "$1" in
    --before|--report|--shots) [ $# -ge 2 ] && [ -n "$2" ] || usage "$1 needs a value" ;;
  esac
  case "$1" in
    --before) before="$2"; shift 2 ;;
    --report) report="$2"; shift 2 ;;
    --shots) shots="$2"; shift 2 ;;
    *) usage "unknown argument $1" ;;
  esac
done
[ -n "$before" ] && [ -f "$before" ] || usage "--before SNAPSHOT is required"
[ "$report" = /dev/null ] || { : > "$report"; } 2>/dev/null || usage "cannot write the report $report"

skip() { case ",${RELEASE_DOCS_SKIP:-}," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
say() { printf '%s\n' "$*"; [ "$report" = /dev/null ] || printf '%s\n' "$*" >> "$report"; }
fails=0

# 1. write fence
allowed="$(bash "$HERE/docs-detect.sh" --allowed-paths)"
fenced=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  grep -qxF -- "$line" "$before" && continue
  path="${line:3}"
  case "$path" in *" -> "*) path="${path##* -> }" ;; esac
  path="${path#\"}"
  path="${path%\"}"
  printf '%s\n' "$allowed" | grep -qxF -- "$path" && continue
  fenced=$((fenced + 1))
  if git cat-file -e "HEAD:$path" 2>/dev/null; then
    git checkout -q HEAD -- "$path"
    say "- FENCE: restored $path (outside the doc surfaces)"
  else
    rm -f -- "$path"
    say "- FENCE: removed new file $path (outside the doc surfaces)"
  fi
done <<EOF
$(git status --porcelain --untracked-files=all)
EOF
if [ "$fenced" -eq 0 ]; then say "- ok: write fence"; else fails=1; fi

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
bad =["%s (added)" % k for k in sorted(now) if k not in was]
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
  say "$(printf '%s\n' "$waiver_out" | sed 's/^/    /')"
  fails=1
fi

# 3. gate
if ! skip gate; then
  if gate_out="$(bash "$HERE/docs-detect.sh" --gate 2>&1)"; then
    say "- ok: docs-detect gate (0 open)"
  else
    say "- FAIL: docs-detect gate"
    say "$(printf '%s\n' "$gate_out" | sed 's/^/    /')"
    fails=1
  fi
fi

# 4. render
if ! skip render; then
  pages=()
  while IFS= read -r p; do
    [ -n "$p" ] && [ -f "$p" ] && pages+=("$p")
  done <<EOF
$(git status --porcelain --untracked-files=all | cut -c4- | grep -E '^site/.*\.html$' | grep -v '^site/walkthrough/examples/' || true)
EOF
  if [ ${#pages[@]} -eq 0 ]; then
    say "- ok: render-check (no site page changed)"
  elif render_out="$(bash "$HERE/render-check.sh" ${shots:+--shots "$shots"} "${pages[@]}" 2>&1)"; then
    say "- ok: render-check (${#pages[@]} page(s))"
  else
    say "- FAIL: render-check"
    say "$(printf '%s\n' "$render_out" | sed 's/^/    /')"
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
