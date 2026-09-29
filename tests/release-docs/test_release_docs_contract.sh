#!/usr/bin/env bash
# test_release_docs_contract.sh — the skill, its references, the agent and the data files agree
# (release-docs spec § 8): obligation kinds match across code / references / skill; every file the
# skill cites exists; the agent is read-only Opus; docs-surfaces.json and the ledger load; every site
# page has an og entry. docs-surfaces.json lives at .github/ (spec § 13 A1), not under the skill.
# SC2015: each `check && echo ok || fail` reporter is intended — echo cannot fail, so fail runs
# exactly when the check does.
# shellcheck disable=SC2015
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
S="$ROOT/.claude/skills/release-docs"

python3 - "$S" <<'PY' && echo "ok: kinds parity (kinds.py = RESOLVER = obligations.md)" || fail "kinds parity"
import re, sys
sys.path.insert(0, sys.argv[1] + "/scripts/docs-lib")
import kinds
doc = open(sys.argv[1] + "/references/obligations.md").read()
table = re.findall(r"^\| `([a-z-]+)` \|", doc, re.M)
ok = list(kinds.KINDS) == table and set(kinds.RESOLVER) == set(kinds.KINDS)
if not ok:
    print("kinds.py:", kinds.KINDS, "\nobligations.md:", table)
sys.exit(0 if ok else 1)
PY

cites_before=$failures
for f in references/obligations.md references/page-style.md scripts/docs-detect.sh scripts/post-checks.sh \
         scripts/render-check.sh scripts/og-regen.sh; do
  grep -qF "$f" "$S/SKILL.md" 2>/dev/null || fail "SKILL.md does not cite $f"
  [ -e "$S/$f" ] || fail "SKILL.md cites a missing file: $f"
done
# The model-written data files sit outside .claude/ (A1): the skill must name them at their real paths.
for f in .github/docs-surfaces.json .github/docs-ledger.json; do
  grep -qF "$f" "$S/SKILL.md" 2>/dev/null || fail "SKILL.md does not cite $f"
  [ -e "$ROOT/$f" ] || fail "SKILL.md cites a missing file: $f"
done
[ "$failures" -eq "$cites_before" ] && echo "ok: SKILL.md cites its files and they exist"

head -n 5 "$S/SKILL.md" 2>/dev/null | grep -qx 'disable-model-invocation: true' \
  && echo "ok: /release-docs is user/CI-invoked only" || fail "SKILL.md must set disable-model-invocation: true"

A="$ROOT/.claude/agents/docs-verifier.md"
grep -qx 'tools: Read, Grep, Glob' "$A" 2>/dev/null && grep -qx 'model: opus' "$A" \
  && echo "ok: docs-verifier is read-only Opus" || fail "docs-verifier frontmatter"
for sec in '## Tools' '## Instructions' '## Output Format'; do
  grep -qx "$sec" "$A" 2>/dev/null || fail "docs-verifier lacks $sec"
done

python3 - "$ROOT" <<'PY' && echo "ok: docs-surfaces.json + ledger load; every site page has an og entry" || fail "data files"
import glob, json, os, sys
root = sys.argv[1]
s = json.load(open(root + "/.github/docs-surfaces.json"))
l = json.load(open(root + "/.github/docs-ledger.json"))
assert s["schemaVersion"] == 1 and l["schemaVersion"] == 1
pages = ["site/index.html"] + sorted(os.path.relpath(p, root) for p in glob.glob(root + "/site/*/index.html"))
missing = [p for p in pages if p not in s["og"]]
assert not missing, missing
for i in l["intentional"]:
    assert all(str(i.get(k) or "").strip() for k in ("file", "token", "context", "reason")), i
PY

exit "$failures"
