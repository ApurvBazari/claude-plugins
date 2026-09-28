#!/usr/bin/env bash
# run.sh — the local behavioural harness for onboard:maintain, the model-driven apply half.
#
# Not a CI belt: tests/run-all.sh skips it by name. Each case starts a real headless Claude Code
# session (`claude -p`) in a throwaway repo, so it costs tokens and needs a logged-in `claude`.
# It stands in for `claude plugin eval` (owner decision 2026-09-27): eval refuses Bash-granting
# runs on a machine whose Docker credential store holds symlinks, and apply needs Bash.
#
# Usage: bash tests/onboard/maintain-apply/run.sh [--model <m>] [--runs <n>] [case ...]
#   Cases: every shape in maintain-corpus/shapes.json, then lessons, bad-input, not-onboarded.
#   Default: all cases, --model sonnet, --runs 1. Exit 0 only if every run of every case passed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
CORPUS="$ROOT/tests/onboard/maintain-corpus"
DETECT="$ROOT/onboard/scripts/maintain-detect.sh"
RUN_DIR=".claude/maintain-run"
MODEL=sonnet
RUNS=1
CASES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    -*) echo "usage: run.sh [--model <m>] [--runs <n>] [case ...]" >&2; exit 2 ;;
    *) CASES+=("$1"); shift ;;
  esac
done
command -v claude >/dev/null 2>&1 || { echo "run.sh: the claude CLI is not on PATH" >&2; exit 2; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=harness GIT_AUTHOR_EMAIL=harness@example.invalid
export GIT_COMMITTER_NAME=harness GIT_COMMITTER_EMAIL=harness@example.invalid

WORKROOT="$(mktemp -d "${TMPDIR:-/tmp}/maintain-apply.XXXXXX")"
echo "work dirs and session logs: $WORKROOT (kept for inspection)"

if [ ${#CASES[@]} -eq 0 ]; then
  while IFS= read -r c; do CASES+=("$c"); done < <(
    python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["shapes"]))' "$CORPUS/shapes.json")
  CASES+=(lessons bad-input not-onboarded)
fi

spec() {  # spec <shape> <key> — one field of the shape's entry in shapes.json ("" if absent)
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["shapes"][sys.argv[2]].get(sys.argv[3], ""))' \
    "$CORPUS/shapes.json" "$1" "$2"
}

apply() {  # apply <work> <log> [with-lessons] — one headless session that invokes onboard:maintain
  local work="$1" log="$2" args="detect=$RUN_DIR/detect.json out=$RUN_DIR/maintain-result.json"
  if [ -n "${3:-}" ]; then args="$args lessons=$RUN_DIR/lessons.json"; fi
  rm -f "$work/$RUN_DIR/maintain-result.json"
  (cd "$work" && claude -p "Use the Skill tool to invoke onboard:maintain with these arguments: $args. Follow the skill exactly, then reply with the result path." \
      --plugin-dir "$ROOT/onboard" --setting-sources project --strict-mcp-config \
      --allowedTools Skill Read Glob Grep Edit Write "Bash(bash:*)" \
      --append-system-prompt "This is an automated, non-interactive test of the onboard:maintain skill. No human is present: run the skill now and never ask a question." \
      --model "$MODEL" --max-turns 80 --no-session-persistence --output-format json) > "$log" 2>&1
  python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
den = d.get("permission_denials") or []
print("   session: %s turns, $%.2f, %d permission denial(s)" % (d.get("num_turns"), d.get("total_cost_usd") or 0, len(den)))
for x in den: print("   denied:", json.dumps(x)[:200])' "$log" 2>/dev/null || echo "   session log unreadable: $log"
}

prepare() {  # prepare <shape> <work> — build the shape; detect from HEAD into the run folder
  bash "$CORPUS/build-shape.sh" "$1" "$2" >/dev/null
  mkdir -p "$2/$RUN_DIR"
}

detect_into() {
  (cd "$1" && bash "$DETECT" --base HEAD --out "$RUN_DIR/detect.json")
}

snapshot() {  # snapshot <work> <dest> — copy every CLAUDE.md and .claude/rules file for AC12
  (cd "$1" && git ls-files --cached --others --exclude-standard | grep -E '(^|/)CLAUDE\.md$|^\.claude/rules/' |
    while IFS= read -r f; do mkdir -p "$2/$(dirname "$f")"; cp "$f" "$2/$f"; done)
}

run_case() {  # run_case <case> <work> — 0 when every check passed
  local c="$1" w="$2"
  case "$c" in
    lessons)
      prepare template "$w"
      cp "$HERE/lessons/lessons.json" "$w/$RUN_DIR/lessons.json"
      detect_into "$w" || return 1
      apply "$w" "$w.log" with-lessons
      python3 "$HERE/check_case.py" lessons "$HERE/lessons" "$w" || return 1
      snapshot "$w" "$w.snap"
      apply "$w" "$w.2.log" with-lessons
      python3 "$HERE/check_case.py" lessons "$HERE/lessons" "$w" "$w.snap"
      ;;
    bad-input)
      prepare template "$w"
      echo '{"schemaVersion": 2}' > "$w/$RUN_DIR/detect.json"
      apply "$w" "$w.log"
      python3 "$HERE/check_case.py" simple "$w" bad-input
      ;;
    not-onboarded)
      prepare template "$w"
      git -C "$w" rm -q .claude/onboard-meta.json && git -C "$w" commit -qm "not onboarded"
      detect_into "$w" || return 1
      apply "$w" "$w.log"
      python3 "$HERE/check_case.py" simple "$w" not-onboarded
      ;;
    *)
      [ -d "$CORPUS/shapes/$c" ] || { echo "   unknown case: $c"; return 1; }
      prepare "$c" "$w"
      python3 "$CORPUS/add-script.py" "$w/$(spec "$c" package)" price:check "tsx scripts/price-check.ts"
      detect_into "$w" || return 1
      apply "$w" "$w.log"
      python3 "$HERE/check_case.py" shape "$CORPUS/shapes.json" "$c" "$w" "$DETECT" || return 1
      if [ "$c" = template ]; then                         # AC12 for a script fact
        snapshot "$w" "$w.snap"
        apply "$w" "$w.2.log"
        python3 "$HERE/check_case.py" again "$CORPUS/shapes.json" "$c" "$w" "$w.snap"
      fi
      ;;
  esac
}

passed=0
failed=0
for c in "${CASES[@]}"; do
  for r in $(seq 1 "$RUNS"); do
    echo "=== $c (run $r/$RUNS, $MODEL)"
    if run_case "$c" "$WORKROOT/$c.$r"; then passed=$((passed + 1)); else failed=$((failed + 1)); echo "   ^ FAILED"; fi
  done
done
echo
echo "maintain-apply: $passed passed, $failed failed ($MODEL, $RUNS run(s) per case)"
[ "$failed" -eq 0 ]
