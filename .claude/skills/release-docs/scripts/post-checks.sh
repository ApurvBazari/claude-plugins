#!/usr/bin/env bash
# post-checks.sh — the deterministic checks after a /release-docs apply (release-docs spec § 6–7).
#
# Usage:
#   post-checks.sh --snapshot FILE                                                # BEFORE the apply
#   post-checks.sh --before FILE [--expect-clean] [--report FILE.md] [--shots DIR]  # after it
#   --snapshot records HEAD and every path dirty before the run, with a digest of its content
#   (JSON). It is taken once: an existing FILE is never overwritten (exit 2). --before takes that
#   file; a plain `git status` text snapshot is refused (exit 2). Keep it where the run can't write.
#   Output paths (--snapshot, --report, --shots) inside the repository must be under .release-docs/
#   and never inside .git; outside it ($TMPDIR, $RUNNER_TEMP) they are free. A refused one exits 2
#   before anything is written.
#   --expect-clean is for CI, which starts from a fresh checkout: the snapshot must list no dirty
#   path and name the current HEAD. Otherwise the run is reported, still fenced, and exits 2 — a
#   snapshot re-taken after the apply would pass the run's files off as the owner's.
# In order:
#   1. the write fence (docs-detect.sh --fence). It puts back every .gitignore the run changed
#      first, then restores from HEAD (tracked) or removes (new) each path the run changed outside
#      the doc surfaces, and any symlink, FIFO, device, directory or type change anywhere. The
#      allowlist comes from HEAD's docs-surfaces.json and marketplace, and the run may change only
#      og, retired and live in that file. A path dirty before the run is never restored or removed: the
#      run touching one outside the surfaces fails, and is left for the owner. The fence's last
#      line must be `FENCE-COMPLETE ok|fail|untrusted`; without it the fence did not complete;
#   2. no "waived" disposition added to the ledger (waivers are owner-only);
#   3. docs-detect --gate;
#   4. render-check on the changed landing and plugin pages (never og-card.html or frozen paths),
#      with HEAD's copy of each as the baseline: an overflow at 500px fails only when it is new or
#      grew (page-style rule 11); one that didn't grow is a note in the report;
#   5. tests/run-all.sh and the .github/scripts guards. A failure names each failing belt with its
#      FAIL lines, and each failing guard with its last lines of output.
# RELEASE_DOCS_SKIP=gate,render,belts skips steps 3–5 (belts only; CI never sets it). Each skipped
# step prints a `- SKIPPED:` line, so an exit 0 with one is never read as a full pass.
# Exit: 0 all passed; 1 any failed; 2 do not trust or commit this tree — bad input, a fence that
# did not complete, or an --expect-clean snapshot that is not clean.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

usage() {
  echo "post-checks: $*" >&2
  echo "usage: post-checks.sh --snapshot FILE | --before FILE [--expect-clean] [--report FILE.md] [--shots DIR]" >&2
  exit 2
}
snapshot=""
before=""
expect_clean=""
report="/dev/null"
shots=""
while [ $# -gt 0 ]; do
  case "$1" in
    --snapshot|--before|--report|--shots) [ $# -ge 2 ] && [ -n "$2" ] || usage "$1 needs a value" ;;
  esac
  case "$1" in
    --snapshot) snapshot="$2"; shift 2 ;;
    --before) before="$2"; shift 2 ;;
    --expect-clean) expect_clean=1; shift ;;
    --report) report="$2"; shift 2 ;;
    --shots) shots="$2"; shift 2 ;;
    *) usage "unknown argument $1" ;;
  esac
done
if [ -n "$snapshot" ]; then
  [ -z "$before" ] && [ -z "$expect_clean" ] && [ "$report" = /dev/null ] && [ -z "$shots" ] \
    || usage "--snapshot runs alone, before the apply"
  exec bash "$HERE/docs-detect.sh" --snapshot "$snapshot"
fi
[ -n "$before" ] && [ -f "$before" ] || usage "--before SNAPSHOT is required"
# Output paths are checked before anything is written: inside the repository only under
# .release-docs/, never inside .git (docs-lib/outputs.py). The CI model can call this script with
# any --report or --shots, and a script's writes are not covered by Claude Code's .claude/ guard.
out_ok() { # <flag> <path> — exit 2, before any write, when docs-detect refuses the path
  local msg
  msg="$(bash "$HERE/docs-detect.sh" "$1" "$2" 2>&1 >/dev/null)" || usage "${msg%%$'\n'*}"
}
[ "$report" = /dev/null ] || out_ok --check-output "$report"
[ -z "$shots" ] || out_ok --check-output-dir "$shots"
[ "$report" = /dev/null ] || { : > "$report"; } 2>/dev/null || usage "cannot write the report $report"

skip() { case ",${RELEASE_DOCS_SKIP:-}," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
say() { printf '%s\n' "$*"; [ "$report" = /dev/null ] || printf '%s\n' "$*" >> "$report"; }
indent() { printf '%s\n' "$1" | sed 's/^/    /'; }
fails=0
untrusted=0

# 1. write fence. Only a run that printed FENCE-COMPLETE as its last line completed: exit 0 with
# `ok`, or exit 1 with `fail`/`untrusted`. Anything else — a crash, a missing marker, exit 2 — means
# the fence did not complete, so nothing it reports can be trusted, and neither can the tree.
TMPW="$(mktemp -d "${TMPDIR:-/tmp}/post-checks.XXXXXX")"
trap 'rm -rf "$TMPW"' EXIT
errf="$TMPW/fence.err"
frc=0
fence_out="$(bash "$HERE/docs-detect.sh" --fence --before "$before" ${expect_clean:+--expect-clean} 2>"$errf")" \
  || frc=$?
fence_err="$(cat "$errf")"
marker="$(printf '%s\n' "$fence_out" | tail -n 1)"
body="$(printf '%s\n' "$fence_out" | sed '$d')"
case "$frc:$marker" in
  "0:FENCE-COMPLETE ok") ;;
  "1:FENCE-COMPLETE fail") fails=1 ;;
  "1:FENCE-COMPLETE untrusted") fails=1; untrusted=1 ;;
  *)
    say "- FAIL: the write fence did not run to completion (exit $frc, no FENCE-COMPLETE line): do not trust or commit this tree"
    [ -z "$fence_out" ] || say "$(indent "$fence_out")"
    [ -z "$fence_err" ] || say "$(indent "$fence_err")"
    exit 2
    ;;
esac
say "$body"
[ -z "$fence_err" ] || say "$(indent "$fence_err")"

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
if skip gate; then
  say "- SKIPPED: docs-detect gate (RELEASE_DOCS_SKIP): this report is not a full pass"
else
  if gate_out="$(bash "$HERE/docs-detect.sh" --gate 2>&1)"; then
    say "- ok: docs-detect gate (0 open)"
  else
    say "- FAIL: docs-detect gate"
    say "$(indent "$gate_out")"
    fails=1
  fi
fi

# 4. render — the changed landing and plugin pages, as HEAD's config names them (docs-detect.sh
# --render-pages): never og-card.html (a 1200px card, not a page), never a frozen path. HEAD's copy
# of each page (git cat-file: no filters, no attributes) goes to a baseline dir for --baseline.
if skip render; then
  say "- SKIPPED: render-check (RELEASE_DOCS_SKIP): this report is not a full pass"
else
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
  else
    base="$TMPW/head"
    for p in "${pages[@]}"; do
      mkdir -p "$base/$(dirname "$p")"
      git cat-file blob "HEAD:$p" > "$base/$p" 2>/dev/null || rm -f "$base/$p"
    done
    if render_out="$(bash "$HERE/render-check.sh" ${shots:+--shots "$shots"} --baseline "$base" "${pages[@]}" 2>&1)"; then
      say "- ok: render-check (${#pages[@]} page(s))"
      notes="$(printf '%s\n' "$render_out" | grep -F 'note: ' || true)"
      [ -z "$notes" ] || say "$(indent "$notes")"
    else
      say "- FAIL: render-check"
      say "$(indent "$render_out")"
      fails=1
    fi
  fi
fi

# 5. belts + guards. A failure says which belt or guard, and what it printed, so the model can tell
# whether it is inside the doc surfaces without re-running the suite (rehearsal #14).
belt_failures() { # <run-all output> — each failed belt (run-all names it under tests/), then its FAIL lines
  awk '
    /^=== .* ===$/ { name = substr($0, 5, length($0) - 8); nb = 0; next }
    /^  \^ FAILED$/ {
      print "tests/" name
      if (nb == 0) print "  (it printed no FAIL line; run it for its output)"
      for (i = 1; i <= nb; i++) print "  " buf[i]
      nb = 0; next
    }
    /FAIL/ { if (nb < 20) buf[++nb] = $0 }
  ' "$1"
}
if skip belts; then
  say "- SKIPPED: tests/run-all.sh and the .github/scripts guards (RELEASE_DOCS_SKIP): this report is not a full pass"
else
  if bash tests/run-all.sh > "$TMPW/belts.out" 2>&1; then
    say "- ok: tests/run-all.sh"
  else
    summary="$(grep -E '^(Ran [0-9]+ belt script|No belts discovered)' "$TMPW/belts.out" | tail -n 1 || true)"
    say "- FAIL: tests/run-all.sh${summary:+ ($summary)}"
    failed="$(belt_failures "$TMPW/belts.out")"
    [ -z "$failed" ] || say "$(indent "$failed")"
    fails=1
  fi
  guard_fails=0
  for g in validate-manifests check-structure check-references check-action-pinning check-version-sync \
           check-state-gitignore check-notify-delegation check-phase-numbering check-phase-tracking \
           check-skill-refs check-ref-paths; do
    if ! gout="$(bash ".github/scripts/$g.sh" 2>&1)"; then
      say "- FAIL: guard $g"
      [ -z "$gout" ] || say "$(indent "$(printf '%s\n' "$gout" | tail -n 10)")"
      guard_fails=1
      fails=1
    fi
  done
  [ "$guard_fails" -ne 0 ] || say "- ok: every .github/scripts guard"
fi

if [ "$untrusted" -ne 0 ]; then
  say "- FAIL: --expect-clean: the snapshot is not trusted, so neither is this tree (exit 2)"
  exit 2
fi
exit "$fails"
