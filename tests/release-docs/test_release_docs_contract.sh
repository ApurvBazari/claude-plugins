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

# Playbook duties with an owner (final review I1, I5, rehearsal #15). A duty with no owning step is
# never performed: the card-description narrative check fell between Step 2 (runs the fixer) and
# Step 3 (model obligations only), and the page it means was never named.
python3 - "$S" <<'PY' && echo "ok: playbook duties have owning steps (I1 card narrative, I5 plugin references, #15 sources)" || fail "playbook duties"
import re, sys
skill = open(sys.argv[1] + "/SKILL.md").read()
obl = open(sys.argv[1] + "/references/obligations.md").read()
def section(title):
    m = re.search(r"^## %s.*?(?=^## |\Z)" % re.escape(title), skill, re.S | re.M)
    return m.group(0) if m else ""
bad = []
card = re.search(r"^\| `card-description` \|.*$", obl, re.M)
if not card or "site/<plugin>/index.html" not in card.group(0):
    bad.append("obligations.md card-description row does not name site/<plugin>/index.html")
step2 = section("Step 2")
if "card-description" not in step2 or "site/<plugin>/index.html" not in step2:
    bad.append("SKILL.md Step 2 does not own the card-description narrative check")
step3 = section("Step 3")
if not all(g in step3 for g in ("<plugin>/references/**", "<plugin>/skills/*/references/**")) \
        or "never its instructions" not in step3:
    bad.append("SKILL.md Step 3 lacks the plugin-references rule (both globs, instructions untouched)")
rule = [l for l in section("Key Rules").splitlines() if l.startswith("- **Sources, not memory.**")]
verifier = section("Step 5")
for src in ("CHANGELOG", "README", "scripts/", "skills/", "agents/"):
    if not rule or src not in rule[0]:
        bad.append("Key Rules' sources omit %s, which Step 5.2 gives the verifier" % src)
    if src not in verifier:
        bad.append("Step 5.2's verifier source paths omit %s" % src)
for b in bad:
    print(b)
sys.exit(1 if bad else 0)
PY

# The live[] playbook (SDD ruling R30 f). The places that tell a run which docs-surfaces.json keys it
# may change agree with the fence. The stale-mention rule carries both halves of the judgement: a
# plugin source must still have the name, and a legacy or migrated-from mention is not a live use.
python3 - "$S" "$ROOT" <<'PY' && echo "ok: the playbook names live[] and its two rules; the keys it lists are the fence's" || fail "live[] playbook"
import json, sys
sys.path.insert(0, sys.argv[1] + "/scripts/docs-lib")
import fence
skill = open(sys.argv[1] + "/SKILL.md").read()
obl = open(sys.argv[1] + "/references/obligations.md").read()
bad = []
if fence.MUTABLE != ("og", "retired", "live"):
    bad.append("fence.MUTABLE is %r" % (fence.MUTABLE,))
for name, text in (("SKILL.md", skill), ("obligations.md", obl)):
    if "`og` and `retired`" in text:
        bad.append("%s still says only og and retired may change" % name)
    if "`og`, `retired` and `live`" not in text:
        bad.append("%s does not list og, retired and live as the keys a run may change" % name)
row = [l for l in obl.splitlines() if l.startswith("| `stale-mention` |")]
bullet = [l for l in skill.splitlines() if l.startswith("- **A `stale-mention` of a live name")]
step = [l for l in skill.splitlines() if l.startswith("- List the range candidates with")]
for name, lines, needs in (
        ("obligations.md's stale-mention row", row, ("`live[]`", "plugin source", "migrated-from")),
        ("SKILL.md's false-positive bullet", bullet, ("`live[]`", "plugin source", "migrated-from")),
        ("SKILL.md's candidates step", step, ("`live[]`", "plugin source"))):
    for need in needs:
        if not lines or need not in lines[0]:
            bad.append("%s does not say %s" % (name, need))
verify = [l for l in skill.splitlines() if l.startswith("1. Re-detect with")]
if not verify or "of a live name (Step 3)" in verify[0] or "no plugin source has" not in verify[0]:
    bad.append("SKILL.md's Step 5.1 still calls every stale-mention of a live name the owner's by rule")
if not isinstance(json.load(open(sys.argv[2] + "/.github/docs-surfaces.json")).get("live"), list):
    bad.append(".github/docs-surfaces.json has no live list")
for b in bad:
    print(b)
sys.exit(1 if bad else 0)
PY

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
