#!/usr/bin/env bash
# Usage: source "$ROOT/tests/onboard/maintain-helpers.sh"   (after defining ROOT and fail())
#
# Shared scaffolding for the tests/onboard/test_maintain_*.sh belts: scratch git repos, a detect
# runner, and JSON queries over the report. Sourced, never executed — the name deliberately does
# not match tests/run-all.sh's discovery pattern.

# DETECT, GUARD, RC, OUT and BASE are read by the belts that source this file.
# shellcheck disable=SC2034
DETECT="$ROOT/onboard/scripts/maintain-detect.sh"
# shellcheck disable=SC2034
GUARD="$ROOT/onboard/scripts/maintain-guard.sh"
DETECT_SCHEMA="$ROOT/onboard/schemas/maintain-detect.json"

# Scratch repos must not inherit the developer's git config (signing, hooks, templates).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=belt GIT_AUTHOR_EMAIL=belt@example.invalid
export GIT_COMMITTER_NAME=belt GIT_COMMITTER_EMAIL=belt@example.invalid

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/maintain-belt.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

# new_repo <name> [--no-meta] — a fresh scratch repo, onboarded unless --no-meta; cd into it.
new_repo() {
  REPO="$SCRATCH/$1"
  mkdir -p "$REPO" && cd "$REPO" || exit 1
  git init -q .
  if [ "${2:-}" != "--no-meta" ]; then
    mkdir -p .claude
    printf '{"pluginVersion":"3.2.0"}\n' > .claude/onboard-meta.json
  fi
}

# put <path> <content...> — write a file (parents created), content joined by newlines.
put() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" > "$path"
}

commit_base() {
  git add -A && git commit -qm base && BASE="$(git rev-parse HEAD)"
}

# detect [ref] — run detect against ref (default $BASE); OUT is the report path, RC the exit code.
detect() {
  mkdir -p "$REPO/.claude/run"
  OUT="$REPO/.claude/run/detect.json"
  rm -f "$OUT"
  # shellcheck disable=SC2034
  RC=0
  # shellcheck disable=SC2034
  bash "$DETECT" --base "${1:-$BASE}" --out "$OUT" 2>"$REPO/.claude/run/stderr" || RC=$?
}

# q <python expression over d> — evaluate against the report and print the result.
q() {
  python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print($1)" "$OUT"
}

# kinds — the report's items as "kind:disposition" words, in order.
kinds() {
  q '" ".join(i["kind"] + ":" + i["disposition"] for i in d.get("items", []))'
}

# item <kind> <python expr over i> [n] — the expression for the n-th item (default 0) of that kind;
# prints nothing when there is no such item. The expression is belt-authored source text (like q's),
# never data read from a report, so evaluating it is the point, not a risk.
item() {
  python3 - "$OUT" "$1" "$2" "${3:-0}" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
hits = [i for i in d.get("items", []) if i["kind"] == sys.argv[2]]
n = int(sys.argv[4])
if len(hits) > n:
    i = hits[n]
    print(eval(sys.argv[3]))
PY
}

# expect <what> <expected> <actual>
expect() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else fail "$1 — expected [$2], got [$3]"; fi
}

# schema_ok <what> — the report validates against maintain-detect.json (skipped without jsonschema).
schema_ok() {
  local msg
  msg="$(python3 - "$DETECT_SCHEMA" "$OUT" <<'PY'
import json, sys
try:
    import jsonschema
except ImportError:
    print("skip"); sys.exit(0)
try:
    jsonschema.validate(json.load(open(sys.argv[2])), json.load(open(sys.argv[1])))
    print("valid")
except jsonschema.ValidationError as e:
    print("invalid: %s at %s" % (e.message, list(e.path)))
PY
)"
  case "$msg" in
    valid) echo "ok: $1 validates against maintain-detect.json" ;;
    skip) echo "skip: $1 schema check (jsonschema not installed)" ;;
    *) fail "$1 — $msg" ;;
  esac
}
