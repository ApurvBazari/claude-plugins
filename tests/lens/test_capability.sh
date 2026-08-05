#!/usr/bin/env bash
# shellcheck disable=SC2016 # every single-quoted literal here is a grepped markdown/JSON span, not shell expansion
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail(){ echo "FAIL: $1"; exit 1; }

# House idiom (tests/lens/test_engine_api.sh): every extracted region is asserted non-empty AND
# bounded. An extractor whose terminator stops matching does not go empty — it swallows the rest of
# the file, so every pin scoped to it silently becomes a whole-file grep. A ceiling catches that.
bounded(){ # bounded <region-name> <max-lines> <region-text>
  [ -n "$3" ] || fail "$1 is empty"
  local n
  n="$(printf '%s\n' "$3" | wc -l | tr -d '[:space:]')"
  [ "$n" -le "$2" ] || fail "$1 grew to $n lines (ceiling $2) — its extractor lost its terminator"
}

# flatten(), one_line() and section() are shared by every belt that sources them; they live in
# tests/lib so a fix to any of them reaches every belt at once, instead of the inconsistent per-belt
# copies they replace — section() in particular had drifted into two arities across those copies.
# shellcheck source=tests/lib/belt-helpers.sh
. "$ROOT/tests/lib/belt-helpers.sh"

SKILL="$ROOT/lens/skills/capability/SKILL.md"
API="$ROOT/lens/skills/engine/references/engine-api.md"
[ -s "$SKILL" ] || fail "missing or empty $SKILL — a caller has no surface to ask lens what it supports"
[ -s "$API" ] || fail "missing or empty $API"

# === 1. FRONTMATTER: a programmatic-API skill is hidden from the / menu but stays model-invokable ===
# The repo's per-skill policy (root CLAUDE.md § Skill Frontmatter Categories): user-invocable:false,
# and NO disable-model-invocation — that flag hides a skill from ALL model/subagent invocation, so an
# orchestrator's COMPAT stage could never dispatch it. Pinned exactly the way render-review's twin
# pins are (tests/lens/test_render_review.sh, checks 2b and 7): two INDEPENDENT negatives, one scoped
# to the frontmatter block and one over the whole file, so a partial revert still fails one of them.
FRONTMATTER="$(awk '/^---$/{n++; next} n==1{print}' "$SKILL")"
bounded "capability/SKILL.md frontmatter" 10 "$FRONTMATTER"
printf '%s\n' "$FRONTMATTER" | grep -qxF 'name: capability' \
  || fail "capability/SKILL.md frontmatter must carry 'name: capability' — the slash entry is derived from it"
printf '%s\n' "$FRONTMATTER" | grep -qxF 'user-invocable: false' \
  || fail "capability/SKILL.md frontmatter must carry 'user-invocable: false' — this is a programmatic API, not a / menu entry"
if printf '%s\n' "$FRONTMATTER" | grep -q 'disable-model-invocation'; then
  fail "capability/SKILL.md frontmatter must NOT carry disable-model-invocation — it would hide the skill from the orchestrator subagent that dispatches it"
fi

# === 1b. The same negative, independently, over the whole file (a partial revert fails here) ===
if grep -q 'disable-model-invocation' "$SKILL"; then
  fail "capability must stay model-invocable — 'disable-model-invocation' must appear nowhere in the file"
fi

# === 2. H1: the descriptive form, asserted as a HARD failure ===
# .github/scripts/check-structure.sh only WARNs on a slash-prefixed H1, so nothing has ever failed on
# it. The convention (.claude/rules/skills-authoring.md § SKILL.md Sections) is a rule, not a taste.
H1="$(grep -m1 '^# ' "$SKILL" || true)"
[ -n "$H1" ] || fail "capability/SKILL.md must carry an H1 title"
case "$H1" in
  '# /'*) fail "capability/SKILL.md H1 must NOT begin with '/' — the slash form is derived from the name frontmatter; found: $H1" ;;
esac
printf '%s\n' "$H1" | grep -qF ' — ' \
  || fail "capability/SKILL.md H1 must be the descriptive '# <Name> — <Short Description>' form; found: $H1"

# === 3. VERSION FROM MANIFEST (floor) — three independent pins ===
# 3a. NO SEMVER LITERAL, anywhere. A version written into prose is a version that goes stale on the
# next bump and reports a lens the caller is not talking to.
SEMVER="$(grep -nE '[0-9]+\.[0-9]+\.[0-9]+' "$SKILL" || true)"
[ -z "$SEMVER" ] \
  || fail "capability/SKILL.md carries a semver literal — the version is READ from the manifest at call time, never written here; found: $SEMVER"

# 3b. The manifest citation is the plugin-root form, DOUBLE-QUOTED, and it is the line that reads
# `.version`. The quoting is load-bearing twice over: unquoted, an unset or space-bearing
# ${CLAUDE_PLUGIN_ROOT} word-splits into a command-not-found (exit 127) instead of a read failure;
# and the ${…} prefix is exactly what makes check-ref-paths.sh treat the token as a leading-slash
# runtime path and exempt it. A bare `.claude-plugin/plugin.json` resolves from neither the citing
# directory nor the repo root while its basename exists under lens/ — that guard reports it BROKEN.
MANIFEST_REF='"${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"'
grep -qF -- "$MANIFEST_REF" "$SKILL" \
  || fail "capability/SKILL.md must cite the manifest as $MANIFEST_REF — double-quoted, plugin-root form"
# Line-scoped on the COMMAND, and the selector's singularity is asserted. The manifest reference occurs
# on three lines (the Step 1 instruction, the jq command, and the envelope's extra.path), two of which
# carry `.version` — so a citation-wide selector ORed them and the pin survived the command losing its
# read entirely. The jq invocation is the line that has to do the reading, and it is unique.
JQLINE="$(grep -F -- 'jq -e -r ' "$SKILL" || true)"
one_line "$JQLINE" "capability/SKILL.md manifest read command"
printf '%s\n' "$JQLINE" | grep -qF -- "$MANIFEST_REF" \
  || fail "the manifest read command must cite the manifest in the double-quoted \${CLAUDE_PLUGIN_ROOT} form"
printf '%s\n' "$JQLINE" | grep -qF '.version' \
  || fail "the manifest read command must be the line that reads '.version' — a citation with no read instructs nothing"
BARE_REF="$(grep -n 'claude-plugin/plugin\.json' "$SKILL" | grep -vF -- "$MANIFEST_REF" || true)"
[ -z "$BARE_REF" ] \
  || fail "every manifest citation must use the double-quoted \${CLAUDE_PLUGIN_ROOT} form — a bare .claude-plugin/plugin.json is reported BROKEN by check-ref-paths.sh; found: $BARE_REF"
grep -qiE 'verbatim' "$SKILL" \
  || fail "capability/SKILL.md must state that the manifest's .version is returned VERBATIM — not reformatted, not summarized"

# 3c. THE PARSE TRUST BOUNDARY. Reading a file that might not be there is the one place a fabricated
# value could enter the report, so the unreadable case is a documented failure with its own sentence.
# Selected on the sentence that owns the policy, not on the token: `unparseable` also appears in two exit
# rows and in the single-line rule, and a bare-token selector ORs four lines — soft enough that the
# failure pin below could not be reddened by any single edit, including one that turned the policy
# sentence itself into a fallback.
UNPARSEABLE="$(grep -iF 'missing or unparseable' "$SKILL" || true)"
[ -n "$UNPARSEABLE" ] \
  || fail "capability/SKILL.md must say what happens when the manifest is missing or unparseable"
one_line "$UNPARSEABLE" "missing-or-unparseable manifest policy"
printf '%s\n' "$UNPARSEABLE" | grep -qiE 'fail' \
  || fail "a missing or unparseable manifest must be a documented FAILURE — anything softer invites a fabricated version"
grep -qF 'never fabricated, guessed, or hardcoded' "$SKILL" \
  || fail "capability/SKILL.md must state that the version is never fabricated, guessed, or hardcoded"

# 3c-ii. THE FAILURE MUST TRAVEL THE BRANCH KEY. 3c pins that the read FAILS; this pins how the failure
# comes back. Declared as prose "not one of the two returns", the ~8 distinct manifest failures came
# back with no `error` key at all — so a caller running the documented `if (r.error)` test landed in the
# SUCCESS arm holding an undefined `version`, which is precisely the fabricated-version outcome 3c
# exists to prevent, reached by a different road. Scoped to the paragraph that decides the routing and
# FLATTENED, because that claim wraps: the file names the code again in Key Rules and in its own fenced
# envelope, so a whole-file grep would stay green with the routing gone from the one sentence that
# governs it, and a line-scoped grep could only ever see half a wrapped sentence.
NEVERFAB="$(awk '/^\*\*Never fabricate\.\*\*/{n=1} n{print} n && /^$/{exit}' "$SKILL")"
bounded "capability/SKILL.md 'Never fabricate' paragraph" 12 "$NEVERFAB"
NEVERFAB_FLAT="$(flatten "$NEVERFAB")"
printf '%s\n' "$NEVERFAB_FLAT" | grep -qF 'E_MANIFEST_UNREADABLE' \
  || fail "the unreadable-manifest policy must return the E_MANIFEST_UNREADABLE envelope — reported as prose it carries no 'error' key, so the documented branch lands the caller in the success arm with version undefined"
printf '%s\n' "$NEVERFAB_FLAT" | grep -qF '../engine/references/engine-api.md' \
  || fail "the unreadable-manifest policy must cite the registry's one declared home for the code it returns"
# NEGATIVE — the retired routing, banned by its own pin. "not one of the two returns" is what put an
# install failure outside the branch key, and a revert has to fail however the author wraps it.
if printf '%s\n' "$(flatten "$(cat "$SKILL")")" | grep -qF 'not one of the two returns'; then
  fail "capability/SKILL.md must not place the manifest failure outside its two returns — an install failure with no 'error' key is unbranchable"
fi

# 3d. THE READ MUST BE ABLE TO FAIL. 3c pins the POLICY; this pins the COMMAND that carries it out —
# and the two came apart. `jq -r '.version'` exits 0 on the two most likely broken manifests: a file
# with no `.version` key (or `"version": null`) prints the literal `null`, and an empty, whitespace-only
# or truncated file prints nothing at all, because jq reads zero documents as zero output rather than as
# an error. Reported "verbatim" per Step 1, the first is a fabricated version and the second is an empty
# one, and the documented failure path above is unreachable for both. `-e` is what separates them:
# exit 1 for absent/null, exit 4 for no-document. A policy whose command cannot reach it is not a policy.
grep -qF -- "jq -e -r " "$SKILL" \
  || fail "capability/SKILL.md's manifest read must use 'jq -e' — without it an absent .version exits 0 printing the literal null, and the documented failure is unreachable"
if grep -qE "jq +-r +'\\.version'" "$SKILL"; then
  fail "capability/SKILL.md must not carry the bare 'jq -r' form — it exits 0 on both an absent .version and an empty manifest"
fi

# 3d-ii. THE READ MUST BE ABLE TO SEE A TYPE, AND ONLY jq CAN. `-e` closes absent/null/empty-file; it
# does NOT close a wrong-typed .version, and no rule written downstream of the command can. `-r` prints
# a JSON string WITHOUT its quotes, which erases the evidence that it was one: `{"version":143}` and
# `{"version":"143"}` both exit 0 and emit byte-identical stdout, and so do `true` and `"true"`. A doc
# that tells the reader to notice a "non-string" in the output is describing a signal that does not
# exist, so an unquoted version — an ordinary manifest typo — reaches a caller's compatibility gate
# reported as real. The type has to be asserted INSIDE jq, where it still exists, and collapsed to null
# so `-e` can turn it into the documented exit-1 failure.
grep -qF -- "jq -e -r 'if (.version|type) == \"string\"" "$SKILL" \
  || fail "capability/SKILL.md's manifest read must assert .version's JSON TYPE inside jq — -r strips the type before any post-hoc inspection of the output could see it"
grep -qF -- 'else null end' "$SKILL" \
  || fail "the manifest read must collapse every non-conforming .version to null — that is what -e turns into the documented exit-1 failure"

# 3d-iii. THE EMPTINESS TEST MOVES INSIDE THE FILTER TOO, AND SO DOES THE TRIM. `(.version|length) > 0`
# rejected `""` and nothing else: a WHITESPACE-PADDED version is a string and is not empty, so it
# cleared the filter, cleared the one-line rule, and came back at exit 0 on exactly one non-empty line
# — an exit and line signature byte-identical to the healthy case, landing it on the "report it
# verbatim" row. A caller's equality or semver check then missed with no `error` key to branch on.
# The skill's own argument for why the TYPE test lives inside jq applies unchanged one step further:
# no inspection of `-r`'s output can distinguish the padded value from the intended one, because the
# padding IS the output. `test("\\S")` asks for content while the value is still JSON; the two `sub`
# calls make the reported string the trimmed one.
grep -qF -- '(.version|test("\\S"))' "$SKILL" \
  || fail "the manifest read must test for non-whitespace CONTENT inside jq — a length test clears a whitespace-padded version, which then reports at exit 0 on one non-empty line exactly like a healthy one"
grep -qF -- 'sub("^\\s+";"")' "$SKILL" \
  || fail "the manifest read must strip leading whitespace inside the filter — a caller gating on the version cannot trim a value it cannot tell is padded"
grep -qF -- 'sub("\\s+$";"")' "$SKILL" \
  || fail "the manifest read must strip trailing whitespace inside the filter — the padded case is symmetric"
if grep -qF -- '(.version|length) > 0' "$SKILL"; then
  fail "capability/SKILL.md must not carry the bare length test — it accepts a whitespace-only-padded version and reports it verbatim with no error channel"
fi
# THE TRIM IS DECLARED, not silent. "Report it verbatim" and "trim it" are contradictory instructions
# unless the doc says which bytes "verbatim" refers to; left unsaid, a maintainer reading the prose
# would take the trim back out as a bug.
grep -qF 'the only normalization performed' "$SKILL" \
  || fail "capability/SKILL.md must declare the trim explicitly — 'verbatim' otherwise forbids it, and an undeclared normalization is one a maintainer removes"
# Flattened: the claim wraps, and a line-scoped grep could only ever see half of it.
printf '%s\n' "$(flatten "$(cat "$SKILL")")" | grep -qF "\"verbatim\" means the filter's output byte for byte, not the manifest's raw bytes" \
  || fail "capability/SKILL.md must say what 'verbatim' refers to once the filter normalizes — the filter's output, not the manifest's raw bytes"
if grep -qE "jq +-e +-r +'\\.version'" "$SKILL"; then
  fail "capability/SKILL.md must not carry the bare 'jq -e -r .version' form — -e catches absent/null/empty-file, but a number, a bool or a float exits 0 with output byte-identical to the quoted string"
fi
# The retired FALSE claim, banned by its own pin: it named a signal (-r output that "comes back as a
# non-string") the command cannot produce, which is how the hole survived a belt that pinned the policy.
if grep -qF 'comes back as a non-string' "$SKILL"; then
  fail "capability/SKILL.md must not claim a wrong-typed .version is visible in -r's output — it is byte-identical to the quoted form; the check belongs inside jq"
fi
# COMPLETENESS, stated and pinned: jq settles the TYPE of each emitted value, the line rule settles HOW
# MANY were emitted (a multi-document manifest still exits 0 with two candidate versions). Neither is
# sufficient alone, which is why the doc has to say the pair is what makes the read exhaustive.
grep -qiE 'the two checks are exhaustive' "$SKILL" \
  || fail "capability/SKILL.md must state why the type filter and the single-line rule are exhaustive TOGETHER — either one alone leaves a manifest shape that reports a wrong version at exit 0"

# The exit status has to be READ, not just produced: the command is prose here, so a reader who is never
# told to branch on $? will report whatever landed on stdout. Each documented exit gets its own pin, so
# a table that loses one class of corruption fails naming that class.
grep -qiE 'check the exit status before' "$SKILL" \
  || fail "capability/SKILL.md must instruct the reader to check the exit status before reporting anything"
EXITROWS="$(grep -E '^\| `?(0|1|4)`?' "$SKILL" || true)"
[ -n "$EXITROWS" ] || fail "capability/SKILL.md must declare what each jq exit status means for the report"
# One row per status, each selector asserted to resolve to exactly ONE row before anything is pinned
# to it. A status selector that matched two rows would OR them, so a gutted row could keep every pin
# below green off its neighbour.
exit_row(){ # exit_row <row-selector> <label>
  local matched
  matched="$(printf '%s\n' "$EXITROWS" | grep -F -- "$1" || true)"
  one_line "$matched" "capability/SKILL.md $2"
  printf '%s\n' "$matched"
}
ROW0="$(exit_row '| `0`' 'exit-0 row')"
ROW1="$(exit_row '| `1` ' 'exit-1 row')"
ROW4="$(exit_row '| `4` ' 'exit-4 row')"
printf '%s\n' "$ROW1" | grep -qiF 'failure' \
  || fail "exit 1 (.version absent, null or false) must be documented as a FAILURE — this is the fabricated-'null' case"
printf '%s\n' "$ROW4" | grep -qiF 'failure' \
  || fail "exit 4 (no JSON document at all — empty, whitespace-only, truncated) must be documented as a FAILURE"
printf '%s\n' "$ROW4" | grep -qiE 'empty|whitespace' \
  || fail "the exit-4 row must name the corruption it catches — an empty or whitespace-only manifest is the likeliest broken install"
printf '%s\n' "$ROW0" | grep -qF 'non-empty line' \
  || fail "the exit-0 row must require one non-empty line of output — exit 0 alone is satisfied by an empty manifest"
# The exit-1 row must OWN the wrong-typed case now that the filter routes it there. Without this the
# table documents a failure class the command produces and the reader is never told to expect, which is
# the same policy/command split 3d-ii closes one level up.
printf '%s\n' "$ROW1" | grep -qiE 'not a string|wrong-typed' \
  || fail "the exit-1 row must name the wrong-typed .version case — the filter collapses a number/bool/float/object/array to null, and this table is where a reader learns exit 1 now covers it"
# ...and the CONTENTLESS case, which the filter now routes there too. A reader whose table still calls
# exit 1 "missing or wrong-typed" has no row telling them a whitespace-only version lands there, and
# would look for it on the exit-0 line where it used to arrive.
printf '%s\n' "$ROW1" | grep -qiF 'whitespace-only' \
  || fail "the exit-1 row must name the whitespace-only .version case — the content test routes it there, and this table is the only place a reader learns so"
printf '%s\n' "$ROW0" | grep -qiE 'non-whitespace|already trimmed' \
  || fail "the exit-0 row must state what actually cleared the filter — a string with non-whitespace content, reported already trimmed — or it still reads as the row a padded version lands on"
# A zero exit is necessary, not sufficient: a wrong-typed or multi-document .version also exits 0, and
# reported verbatim it lands non-string or multi-line inside a declared single-string field.
grep -qiE 'necessary and not sufficient' "$SKILL" \
  || fail "capability/SKILL.md must state that exit 0 alone is not a successful read"
grep -qF 'single non-empty string line' "$SKILL" \
  || fail "capability/SKILL.md must require the read to yield a single non-empty string line before it is reported"

# === 3f. THE MANIFEST READ, EXECUTED ===
# Everything above greps the prose. Prose pins are how the padded-version hole survived: the filter,
# the exit table and the one-line rule were each asserted to SAY the right thing, and no belt ever RAN
# the read against a manifest, so a rule that cleared every string check and still reported a wrong
# version was invisible. Non-vacuity and sufficiency are different properties.
#
# The command is EXTRACTED FROM THE SKILL, never re-typed here: a copy in this belt would be a second
# source of truth and would keep passing after the skill's own filter regressed. The classification is
# Step 1's table implemented once — exit status first, then the one-non-empty-line rule — and each
# synthetic manifest asserts the outcome that table declares for it.
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not installed — the manifest read is not executed (brew install jq)"
else
  JQ_PROGRAM="$(python3 - "$SKILL" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = re.findall(r"```bash\n(.*?)\n```", text, re.S)
cmds = [ln for b in blocks for ln in b.splitlines() if ln.strip().startswith("jq ")]
assert len(cmds) == 1, f"capability/SKILL.md must carry exactly one fenced jq read command, found {len(cmds)}"
m = re.match(r"^jq -e -r '(.*)' \"\$\{CLAUDE_PLUGIN_ROOT\}/\.claude-plugin/plugin\.json\"$", cmds[0].strip())
assert m, f"the jq read command is not in the declared `jq -e -r '<filter>' \"<manifest>\"` form: {cmds[0]!r}"
print(m.group(1))
PY
  )" || fail "could not extract the manifest read command from capability/SKILL.md — the belt must run the skill's own filter, not a copy"
  [ -n "$JQ_PROGRAM" ] || fail "the extracted jq filter is empty"

  MTMP="$(mktemp -d)"
  # shellcheck disable=SC2064 # expand MTMP now — the trap must survive whatever $MTMP becomes later
  trap "rm -rf '$MTMP'" EXIT

  # read_manifest <path> -> prints "<outcome>\t<value>"; outcome is `report` or `fail`.
  # Step 1's rule, implemented once: a zero exit is necessary and not sufficient — the output must
  # also be exactly one non-empty line, so a multi-document manifest fails despite exiting 0.
  read_manifest(){
    local out rc lines
    out="$(jq -e -r "$JQ_PROGRAM" "$1" 2>/dev/null)"; rc=$?
    if [ "$rc" -ne 0 ]; then printf 'fail\t\n'; return; fi
    lines="$(printf '%s\n' "$out" | grep -c . || true)"
    if [ "$lines" -ne 1 ]; then printf 'fail\t\n'; return; fi
    printf 'report\t%s\n' "$out"
  }
  expect_fail_read(){ # expect_fail_read <label> <path>
    local got
    got="$(read_manifest "$2")"
    case "$got" in
      fail*) : ;;
      *) fail "MANIFEST: $1 must be an install-integrity FAILURE, but the read reported '${got#*	}'" ;;
    esac
  }
  expect_report(){ # expect_report <label> <path> <exact-value>
    local got
    got="$(read_manifest "$2")"
    [ "$got" = "report	$3" ] \
      || fail "MANIFEST: $1 must report exactly '$3', got '$got'"
  }

  # --- the eight ways the read is documented to fail ---
  expect_fail_read "an absent manifest path" "$MTMP/does-not-exist.json"
  mkdir -p "$MTMP/adir.json"
  expect_fail_read "a directory where the manifest should be" "$MTMP/adir.json"
  printf '{"version":"9.9.9"}\n' > "$MTMP/noperm.json"; chmod 000 "$MTMP/noperm.json"
  if jq -e -r "$JQ_PROGRAM" "$MTMP/noperm.json" >/dev/null 2>&1; then
    echo "  SKIP: an unreadable file is still readable here (running as root?) — that case is not executed"
  else
    expect_fail_read "a manifest with no read permission" "$MTMP/noperm.json"
  fi
  printf '{"version": "9.9.9"\n' > "$MTMP/malformed.json"
  expect_fail_read "malformed JSON" "$MTMP/malformed.json"
  : > "$MTMP/empty.json"
  expect_fail_read "an empty manifest" "$MTMP/empty.json"
  printf '   \n\t\n' > "$MTMP/blank.json"
  expect_fail_read "a whitespace-only manifest" "$MTMP/blank.json"
  printf '{"name":"lens"}\n' > "$MTMP/nokey.json"
  expect_fail_read "a manifest with no .version key" "$MTMP/nokey.json"
  printf '{"version": null}\n' > "$MTMP/nullver.json"
  expect_fail_read "a null .version" "$MTMP/nullver.json"
  # The wrong-typed family — the case -r makes invisible after the fact, one per JSON type.
  printf '{"version": 143}\n' > "$MTMP/number.json"
  expect_fail_read "a numeric .version" "$MTMP/number.json"
  printf '{"version": true}\n' > "$MTMP/bool.json"
  expect_fail_read "a boolean .version" "$MTMP/bool.json"
  printf '{"version": {"major": 1}}\n' > "$MTMP/object.json"
  expect_fail_read "an object .version" "$MTMP/object.json"
  printf '{"version": ["9.9.9"]}\n' > "$MTMP/array.json"
  expect_fail_read "an array .version" "$MTMP/array.json"
  printf '{"version": ""}\n' > "$MTMP/emptystr.json"
  expect_fail_read "an empty-string .version" "$MTMP/emptystr.json"
  printf '{"version": "   "}\n' > "$MTMP/wsonly.json"
  expect_fail_read "a whitespace-only .version" "$MTMP/wsonly.json"
  printf '{"version":"9.9.9"}\n{"version":"8.8.8"}\n' > "$MTMP/multidoc.json"
  expect_fail_read "a manifest holding two concatenated JSON documents" "$MTMP/multidoc.json"
  printf '{"version": "9.9\\n.9"}\n' > "$MTMP/newline.json"
  expect_fail_read "a .version carrying an inner newline" "$MTMP/newline.json"

  # --- THE CASE THE PROSE PINS COULD NOT SEE ---
  # Under the retired length test this reported ' 9.9.9 ' at exit 0 on one non-empty line — the same
  # signature as the healthy read — so it landed on the "report it verbatim" row and a caller's
  # comparison missed with no error channel to explain why. Asserted on the exact reported bytes: an
  # outcome check alone would pass on a filter that reported the padding untouched.
  printf '{"version": " 9.9.9 "}\n' > "$MTMP/padded.json"
  expect_report "a whitespace-padded .version" "$MTMP/padded.json" "9.9.9"
  printf '{"version": "\\t9.9.9\\n"}\n' > "$MTMP/padded-tab.json"
  expect_report "a tab/newline-padded .version" "$MTMP/padded-tab.json" "9.9.9"

  # --- AND THE POSITIVE, without which every assertion above is satisfied by a filter that rejects
  # everything. The real shipped manifest is read here too, so the belt proves the filter works on the
  # very file the skill points at, not only on synthetic ones.
  printf '{"version": "9.9.9", "name": "zzz"}\n' > "$MTMP/valid.json"
  expect_report "a healthy manifest" "$MTMP/valid.json" "9.9.9"
  REAL_MANIFEST="$ROOT/lens/.claude-plugin/plugin.json"
  [ -s "$REAL_MANIFEST" ] || fail "missing $REAL_MANIFEST"
  REAL_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$REAL_MANIFEST")"
  expect_report "the shipped lens manifest" "$REAL_MANIFEST" "$REAL_VERSION"
fi

# 3e. `require`'s OWN VALIDATION. The declared user-input trust boundary covers require[] alongside the
# engine's 1.5.0 keys — "validated strictly; a violation returns a named E_* envelope". Untyped, a bare
# string `require` iterates to its CHARACTERS, which either reports a false green or names single
# letters as missing capabilities; either way the caller's real bug (a stringified arg) never surfaces.
# Selected at the DECLARATION site, which is the gate: the input bullet is the only place the type is
# stated normatively (and bolded as the declaration), while Step 2 and Key Rules refer back to it. A bare
# `array of strings` spans all three, and the code pin below would then pass on a gate rewritten to route
# a shape bug to the capability-miss path, because a restatement downstream still named the code.
REQSHAPE="$(grep -F 'present must be an **array of strings**' "$SKILL" || true)"
[ -n "$REQSHAPE" ] \
  || fail "capability/SKILL.md must declare require's type — an untyped require lets a bare string iterate to characters"
one_line "$REQSHAPE" "require type declaration"
printf '%s\n' "$REQSHAPE" | grep -qF 'E_INVALID_INPUT' \
  || fail "a require that is not an array of strings must return the named E_INVALID_INPUT envelope, not a capability miss"
grep -qF 'Never iterate a bare string' "$SKILL" \
  || fail "capability/SKILL.md must forbid iterating a bare require — its characters are not tokens"
grep -qF 'Check the shape first' "$SKILL" \
  || fail "capability/SKILL.md must validate require's shape BEFORE matching — a shape bug reported as a missing capability sends the caller after the wrong fix"
# The code is registered where the taxonomy lives, not invented locally.
grep -qF '../engine/references/engine-api.md' "$SKILL" \
  || fail "capability/SKILL.md must cite engine-api.md for the error code it returns — the registry is declared once"

# === 4/6/7/8. THE TWO RETURNS, PARSED — exact sets in both directions ===
# The advertised sets ARE the contract a caller gates on, so they are parsed out of the declared JSON
# rather than substring-matched: a subset check lets a token be deleted, a superset check lets one be
# invented, and both are how a COMPAT gate starts lying. Every fenced json block is parsed on the way
# past (the tests/lens/test_engine_api.sh:46-57 parser idiom), so a return declared in unparseable
# JSON fails here rather than at the caller.
#
# D4 (capabilities[] carries finderEffort, supports carries effortChannel — NOT the intent record's
# finderThinking/thinkingChannel) needs no separate negative here: the two set-equality assertions
# below already forbid any other token or key, and the tree-wide string ban on both thinking-era
# spellings lives at tests/lens/test_injected_finders.sh:140.
python3 - "$SKILL" <<'PY' || fail "capability/SKILL.md does not declare its two returns with the exact advertised sets"
import json, re, sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

blocks = re.findall(r"```json\n(.*?)\n```", text, re.S)
assert blocks, "capability/SKILL.md must declare its returns as fenced json blocks"
parsed = []
for i, block in enumerate(blocks, 1):
    try:
        parsed.append(json.loads(block))
    except json.JSONDecodeError as exc:
        raise AssertionError(f"fenced json block #{i} does not parse: {exc}")

reports = [b for b in parsed if isinstance(b, dict) and "capabilities" in b]
assert len(reports) == 1, \
    f"exactly one fenced json block must declare the capability report; found {len(reports)}"
report = reports[0]

# SUCCESS RETURN — key set both directions. A caller pattern-matches this shape.
assert set(report) == {"name", "version", "capabilities", "supports"}, \
    f"the success return must be exactly name/version/capabilities/supports, got {sorted(report)}"
assert report["name"] == "lens", f"the success return's 'name' must be \"lens\", got {report['name']!r}"
assert isinstance(report["version"], str) and report["version"].strip(), \
    "the success return must show a 'version' slot, filled from the manifest at call time"

EXPECTED_CAPS = [
    "injectedIntent", "injectedFinders", "adherenceReturn", "emptyScope", "renderReview",
    "modelPolicy", "verifyVotes", "finderModel", "finderEffort", "degradedReasons", "namedErrors",
]
caps = report["capabilities"]
assert isinstance(caps, list), f"capabilities must be an array, got {type(caps).__name__}"
assert len(caps) == len(set(caps)), f"capabilities[] repeats a token: {caps}"
assert len(caps) == 11, f"capabilities[] must carry exactly 11 tokens, found {len(caps)}: {caps}"
assert set(caps) == set(EXPECTED_CAPS), (
    "capabilities[] must be EXACTLY the advertised 11; "
    f"invented={sorted(set(caps) - set(EXPECTED_CAPS))} missing={sorted(set(EXPECTED_CAPS) - set(caps))}"
)

supports = report["supports"]
assert set(supports) == {"inputKeys", "resolutionRules", "effortChannel"}, \
    f"supports must be exactly inputKeys/resolutionRules/effortChannel, got {sorted(supports)}"

EXPECTED_KEYS = ["target", "scope", "taskIds", "injectedIntent", "injectedFinders",
                 "finders", "modelPolicy", "verifyVotes"]
keys = supports["inputKeys"]
assert isinstance(keys, list), f"supports.inputKeys must be an array, got {type(keys).__name__}"
assert len(keys) == len(set(keys)), f"supports.inputKeys[] repeats a key: {keys}"
assert len(keys) == 8, f"supports.inputKeys[] must carry exactly 8 keys, found {len(keys)}: {keys}"
assert set(keys) == set(EXPECTED_KEYS), (
    "supports.inputKeys[] must be EXACTLY the 8 accepted keys; "
    f"invented={sorted(set(keys) - set(EXPECTED_KEYS))} missing={sorted(set(EXPECTED_KEYS) - set(keys))}"
)

RULES = {
    "verify": "huginn-quorum-v1",
    "intent": "injected-wins",
    "dedup": "file-line-title",
    "model": "lens-model-precedence-v1",
    "emptyScope": "flag-not-empty-findings",
}
got_rules = supports["resolutionRules"]
assert got_rules == RULES, (
    "supports.resolutionRules must carry exactly the five named rules with their exact strings; "
    f"expected={RULES} got={got_rules}"
)

# EVERY VALUE IS A RULE NAME, NEVER A RESTATEMENT OF THE RULE. `model` used to carry the arrow string
# `deny→record→byAgent→byRole→default→frontmatter` — a SIX-position restatement of a seven-position
# chain, dropping the harness default — so the advertised set was a lossy second declaration of the one
# thing engine-api.md § Model resolution exists to declare once, and correcting the doc would have
# turned this very assertion red. A name cannot go lossy; an arrow string can, and did. Pinned
# structurally rather than by re-listing the values, so a future rule declared as a restatement fails
# here even though this belt has never heard of it.
for slot, value in got_rules.items():
    assert "→" not in value, (
        f"supports.resolutionRules.{slot} carries an arrow-chain restatement ({value!r}) — every value "
        "must be a rule NAME whose meaning is declared at its governing site; a restatement forks it"
    )
    assert re.fullmatch(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)+", value), (
        f"supports.resolutionRules.{slot} must be a hyphenated lowercase rule NAME, got {value!r}"
    )
assert supports["effortChannel"] == "prompt-directive", (
    "supports.effortChannel must be exactly \"prompt-directive\" — effort is a prompt-level directive, "
    f"never a model-resolution input; got {supports['effortChannel']!r}"
)

# FAILURE RETURNS — the declared envelopes, keyed by CODE rather than by position. The count is a
# floor, not an equality: a second envelope block is how a new failure gets declared, and an equality
# here would fail the addition instead of judging it. What keeps that floor from being a free pass is
# the exact CODE SET below plus a per-code `extra` assertion — an undeclared code fails, a dropped one
# fails, and an envelope whose `extra` carries the wrong facts fails naming its own code.
errors = [b for b in parsed if isinstance(b, dict) and "error" in b]
assert len(errors) >= 1, "at least one fenced json block must declare an error envelope; found none"

EXPECTED_EXTRA = {
    "E_UNSUPPORTED_CAPABILITY": {"missing", "have"},
    "E_MANIFEST_UNREADABLE": {"path", "exit"},
}
by_code = {}
for block in errors:
    err = block["error"]
    assert set(block) == {"error"}, \
        f"a failure return's top level must be exactly 'error', got {sorted(block)}"
    assert set(err) == {"code", "message", "extra"}, \
        f"a failure envelope must be exactly code/message/extra, got {sorted(err)}"
    assert isinstance(err["message"], str) and err["message"].strip(), \
        f"{err['code']}'s envelope must show what 'message' holds, not an empty placeholder"
    assert err["code"] not in by_code, f"{err['code']} is declared by two fenced blocks"
    by_code[err["code"]] = err

assert set(by_code) == set(EXPECTED_EXTRA), (
    "capability/SKILL.md must declare an envelope per failure it can return; "
    f"undeclared={sorted(set(by_code) - set(EXPECTED_EXTRA))} "
    f"missing={sorted(set(EXPECTED_EXTRA) - set(by_code))}"
)
for code, keys in EXPECTED_EXTRA.items():
    got = set(by_code[code]["extra"])
    assert got == keys, f"{code}'s extra must be exactly {sorted(keys)}, got {sorted(got)}"

# The capability miss carries both halves non-empty: a caller needs what it asked for AND what exists.
for half in ("missing", "have"):
    val = by_code["E_UNSUPPORTED_CAPABILITY"]["extra"][half]
    assert isinstance(val, list) and val, \
        f"extra.{half} must be a non-empty array — a caller needs both what it asked for and what exists"
# The install failure names a concrete file and a concrete status, not a placeholder either.
assert str(by_code["E_MANIFEST_UNREADABLE"]["extra"]["path"]).strip(), \
    "E_MANIFEST_UNREADABLE's extra.path must show the manifest path that could not be read"
assert isinstance(by_code["E_MANIFEST_UNREADABLE"]["extra"]["exit"], int), \
    "E_MANIFEST_UNREADABLE's extra.exit must be the numeric exit status that classified the failure"

# DISTINGUISHABLE. One branch key, present in the failure returns and absent from the report.
assert "error" not in report, "the success return must not carry an 'error' key — the two returns must be tellable apart"
for block in errors:
    assert "capabilities" not in block, \
        "a failure return must not carry 'capabilities' — the two returns must be tellable apart"
PY

# === 5. DERIVED CROSS-CHECK: the advertised input keys come from the engine's own inputs table ===
# Hand-listing them is how a declaration drifts: a future engine input never gets advertised, or an
# advertised key keeps being promised after its input row is gone. The engine-api.md inputs table is
# the source of truth; `scope` is its one key with no row of its own (it is `target`'s recorded
# historical alias), so the derivation is the row set ∪ {scope} — and the alias record is itself
# asserted, so that union term can never become a free pass.
python3 - "$API" "$SKILL" <<'PY' || fail "supports.inputKeys[] is out of parity with engine-api.md's inputs table"
import json, re, sys

api = open(sys.argv[1], encoding="utf-8").read()
skill = open(sys.argv[2], encoding="utf-8").read()

def section(text, title):
    body, inside = [], False
    for line in text.splitlines():
        if line.startswith("## "):
            if inside:
                break
            inside = line.strip() == title
            continue
        if inside:
            body.append(line)
    return body

INPUTS = section(api, "## lens:engine — inputs")
assert INPUTS, "engine-api.md § lens:engine — inputs is missing — the derivation has no source"

declared = []
for line in INPUTS:
    if not line.startswith("|"):
        continue
    cell = line.strip().strip("|").split("|")[0].strip()
    if not cell or set(cell) <= set("-: ") or cell == "Input":
        continue
    m = re.fullmatch(r"`([A-Za-z]+)`", cell)
    assert m, f"an inputs-table row does not declare a `key` in its first cell: {cell!r}"
    declared.append(m.group(1))
assert declared, "no input rows were derived from the inputs table — the extractor is broken"

flat = " ".join(" ".join(INPUTS).split())
assert "alias" in flat and "`scope`" in flat, (
    "the derivation adds `scope` because the inputs section records it as `target`'s historical alias; "
    "with that record gone, the union term is a free pass and `scope` needs a row of its own"
)
derived = set(declared) | {"scope"}

blocks = re.findall(r"```json\n(.*?)\n```", skill, re.S)
reports = [json.loads(b) for b in blocks]
reports = [b for b in reports if isinstance(b, dict) and "capabilities" in b]
assert len(reports) == 1, "capability/SKILL.md must declare exactly one capability report"
advertised = set(reports[0]["supports"]["inputKeys"])

assert advertised == derived, (
    "supports.inputKeys[] must be the engine's inputs-table key set ∪ {scope}; "
    f"never-advertised={sorted(derived - advertised)} "
    f"advertised-with-no-input-row={sorted(advertised - derived)}"
)
PY

# === 7b. THE TWO RETURNS IN PROSE — each edge gets its own pin ===
# `require` absent is not a degenerate error case, it is the pure-report call: a caller that just
# wants to know what lens is must never have to catch an envelope to find out.
# Selected at the declaration of the pure-report contract rather than on every line that mentions an
# absent `require` — the phrase also appears in the report's own heading and in Key Rules, and the
# never-errors pin below is only meaningful against the bullet that declares the semantics.
NOREQ="$(grep -F '⇒ a pure report' "$SKILL" || true)"
[ -n "$NOREQ" ] || fail 'capability/SKILL.md must state what a call with `require` absent returns'
one_line "$NOREQ" "require-absent pure-report declaration"
printf '%s\n' "$NOREQ" | grep -qiE 'never .*error|cannot .*error' \
  || fail 'a call with `require` absent must be declared a pure report that NEVER errors'

# Exact matching, and its consequence for the caller: `have[]` is what turns a miss into a fix.
grep -qF 'a misspelling is a miss' "$SKILL" \
  || fail "capability/SKILL.md must state that matching is exact — a misspelled token is a miss, never a fuzzy hit"
grep -qF 'correct spellings' "$SKILL" \
  || fail "capability/SKILL.md must state that have[] comes back carrying the correct spellings"

# The branch key, named where the caller reads it.
grep -qF 'branch on the presence of `error`' "$SKILL" \
  || fail "capability/SKILL.md must tell a caller which key distinguishes the two returns"

# === 9. THE CANON DECLARES THE SURFACE, and disambiguates the two senses of "capability" ===
line_of(){ { grep -nF -- "$1" "$API" || true; } | head -1 | cut -d: -f1; }

L_CAP="$(line_of '## lens:capability')"
L_PROC="$(line_of '## Where the procedure lives')"
[ -n "$L_CAP" ] || fail "engine-api.md must carry a '## lens:capability' section"
[ -n "$L_PROC" ] || fail "engine-api.md must carry a '## Where the procedure lives' section"
[ "$L_CAP" -lt "$L_PROC" ] \
  || fail "'## lens:capability' must come BEFORE '## Where the procedure lives' — the index of procedures is the file's closing section"

CAPSEC="$(section '## lens:capability' "$API")"
bounded "engine-api.md § lens:capability" 30 "$CAPSEC"
capsec_has(){ printf '%s\n' "$CAPSEC" | grep -qF -- "$1" || fail "$2"; }
capsec_has 'require' "engine-api.md § lens:capability must declare the 'require' input"
capsec_has 'E_UNSUPPORTED_CAPABILITY' \
  "engine-api.md § lens:capability must name the code its failure return carries (registered in § Errors)"
capsec_has '../../capability/SKILL.md' \
  "engine-api.md § lens:capability must point at the skill that emits the advertised set rather than restating the roster"

# TWO SENSES. `capability` already means a tool-permission constraint in this plugin
# (finder-registry.md's `capability-locked` adapter row), and a reader who conflates the two will look
# for the adapter's permissions in capabilities[]. The canon separates them where both are declared.
printf '%s\n' "$CAPSEC" | grep -qF 'capability-locked' \
  || fail "engine-api.md § lens:capability must disambiguate the token sense from the 'capability-locked' tool-permission sense"
printf '%s\n' "$CAPSEC" | grep -qF './finder-registry.md' \
  || fail "the two-senses note must point at ./finder-registry.md, where the tool-permission sense lives"

# === 9b. EVERY ADVERTISED RULE NAME IS DECLARED AT A GOVERNING SITE UNDER lens/ ===
# A name is only better than a restatement if the name resolves. Advertising a rule nobody declares is
# the same drift the arrow string caused, one level up: a caller reads `lens-model-precedence-v1`,
# looks for it, and finds nothing that says what it means. Both directions of the model rule are
# pinned — the name is advertised (asserted above) AND declared beside the canonical chain here — so
# renaming one without the other fails. The names are READ from the skill, never re-listed in this
# belt, so a sixth rule added tomorrow is covered without touching this block.
MODELSEC="$(section '## Model resolution' "$API")"
bounded "engine-api.md § Model resolution" 125 "$MODELSEC"
printf '%s\n' "$MODELSEC" | grep -qF 'lens-model-precedence-v1' \
  || fail "engine-api.md § Model resolution must declare the rule NAME lens:capability advertises for model resolution — an advertised name with no declaration is a pointer to nothing"
printf '%s\n' "$MODELSEC" | grep -qF 'supports.resolutionRules.model' \
  || fail "the rule-name declaration must say which advertised slot carries it, so the two move together"

# The two VERSIONED rule names — the `-v1` slots — each resolve to a declaration outside this skill.
# A name is only better than a restatement if the name resolves, and these are the two whose meaning a
# caller cannot guess from the slot alone. Both are read from the advertised set rather than typed
# here, so renaming one in the skill without declaring the new name fails.
while IFS= read -r rulename; do
  [ -n "$rulename" ] || continue
  HITS="$( { grep -rlF -- "$rulename" "$ROOT/lens/skills" "$ROOT/lens/agents" || true; } | { grep -vF "$SKILL" || true; } | grep -c . || true)"
  [ "$HITS" -ge 1 ] \
    || fail "the advertised resolution rule '$rulename' is declared nowhere under lens/skills or lens/agents — capability advertises a name a caller cannot look up"
done < <(python3 - "$SKILL" <<'PY'
import json, re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = re.findall(r"```json\n(.*?)\n```", text, re.S)
reports = [json.loads(b) for b in blocks]
reports = [r for r in reports if isinstance(r, dict) and "capabilities" in r]
assert len(reports) == 1
versioned = [v for v in reports[0]["supports"]["resolutionRules"].values() if re.search(r"-v\d+$", v)]
assert len(versioned) == 2, (
    "exactly two resolutionRules values are versioned rule names (verify and model); "
    f"found {sorted(versioned)} — a third would need its own declaration site too"
)
for value in versioned:
    print(value)
PY
)

# The procedure index gains its row — the pointer and the file move together or not at all.
PROCSEC="$(section '## Where the procedure lives' "$API")"
bounded "engine-api.md § Where the procedure lives" 20 "$PROCSEC"
printf '%s\n' "$PROCSEC" | grep -qF '`../../capability/SKILL.md`' \
  || fail "engine-api.md § Where the procedure lives must carry a row pointing at ../../capability/SKILL.md"

echo "PASS: lens capability belt (frontmatter policy, descriptive H1, version-from-manifest, exact advertised sets, derived inputKeys, two returns, canon declaration)"
