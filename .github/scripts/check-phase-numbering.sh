#!/usr/bin/env bash
# check-phase-numbering.sh — onboard Phase/Step labels must stay within their allowed families.
#
# Phase labels (the START orchestrator's own numbering, Phase 0-7) ban:
#   - fractional labels   ("Phase 1.4")
#   - lettered labels     ("Phase 7a")
#   - out-of-range labels ("Phase 8", "Phase 10" — START maxes at 7, so these
#                          are vestiges of the old global numbering)
#
# Step labels (used throughout the internal skills) are a richer, real namespace that must NOT
# be forced into the Phase model.
#
# What counts as a Step LABEL: DECLARATION FORM, not punctuation. A "Step <token>" is read as a
# label only where a label can be declared:
#   - a heading        "## Step 2b: Ladder rung"        / "### **Step 6 — Title**"
#   - a bold run       "**Step 1 — Collect inputs.**"
#   - a list-item lead "- Step 4: Apply"                / "1. **Step 5 — Verify**"
# Ordinary prose ("Step through the wizard", "Step One is optional") is never at a declaration
# position, so it is scanned past rather than tokenized and mis-flagged. Both conventions onboard
# actually uses are therefore seen: the colon form AND the em-dash/bold form.
#
# A label's token ends at its terminator — ':', an em-dash, '**', end of line, or a sentence '.'.
# The token is captured greedily up to that terminator (rather than by a permissive character
# class) so a malformed token ("Step 2-b:", "Step 1_2:", "Step 5,5:") REACHES the shape check
# instead of evading it: the shape decision lives in exactly one place, is_allowed_step_token.
# Emphasis markers are stripped before shaping, so "**Step 1.2.3**:" is judged on "1.2.3".
#
# Labels are judged by SHAPE, not by an inventory of the steps that happen to exist today, so a
# same-shape new step needs no edit here. Recognized as VALID:
#   - Step N              whole numbers (any magnitude)                    e.g. Step 5
#   - Step N.N            single-fractional sub-steps                      e.g. Step 2.5
#   - Step Na / Na.N      one lowercase suffix, optionally sub-numbered    e.g. Step 2b, Step 4b.3
#   - Step X / XN         one uppercase letter, optionally numbered        e.g. Step A, Step A1
# Anything else at a declaration position is flagged — a two-decimal "Step 1.2.3", a multi-letter
# "Step 9zz", a trailing-garbage "Step 5.5x", a worded "Step One", a non-alnum "Step 2-b".
#
# What this gate does NOT guarantee: it reads declaration FORM by line shape, not markdown
# structure. It does not parse fenced code blocks, so a declaration-shaped line inside a fence is
# still read as a declaration; and a label declared in some form none of the three positions above
# cover is not seen. It is a numbering guard, not a markdown parser.
#
# A root that does not exist, or a scan that errors out, exits non-zero: this gate never reports a
# pass it did not earn.
#
# CHANGELOG.md is exempt everywhere (historical, immutable record of prior numbering).
# Usage: check-phase-numbering.sh [root]   (default: onboard; a single .md file also works)
set -euo pipefail
ROOT="${1:-onboard}"
[[ -e "$ROOT" ]] || { echo "phase-numbering: ROOT not found: $ROOT"; exit 1; }

# Scans ROOT for an ERE and leaves the CHANGELOG-exempt matches in scan_out.
# grep rc 1 ("no match") is a legitimately empty result; rc >= 2 is a real error and must never be
# laundered into "clean" by a blanket `|| true`.
scan_out=""
scan_md() {
  local pattern="$1" rc=0 raw=""
  raw="$(grep -rnoE "$pattern" --include='*.md' "$ROOT" 2>/dev/null)" || rc=$?
  if [[ "$rc" -ge 2 ]]; then
    echo "phase-numbering: scan of ${ROOT} failed (grep exit ${rc}) — refusing to report a pass"
    exit 1
  fi
  scan_out="$(printf '%s\n' "$raw" | grep -v '/CHANGELOG.md:' || true)"
}

# --- Phase bans (unchanged) ---
scan_md 'Phase [0-9]+\.[0-9]+|Phase [0-9]+[a-z]\b|Phase ([89]|[1-9][0-9]+)\b'
phase_hits="$scan_out"

# --- Step label shapes ---
is_allowed_step_token() {
  if [[ "$1" =~ ^[0-9]+$ ]]; then                 # Step 5
    return 0
  fi
  if [[ "$1" =~ ^[0-9]+\.[0-9]+$ ]]; then         # Step 2.5
    return 0
  fi
  if [[ "$1" =~ ^[0-9]+[a-z](\.[0-9]+)?$ ]]; then # Step 2b, Step 4b.3
    return 0
  fi
  if [[ "$1" =~ ^[A-Z][0-9]*$ ]]; then            # Step A, Step A1
    return 0
  fi
  return 1
}

# The three declaration positions. The token is everything up to the first ':' or space, so
# non-alnum tokens land in is_allowed_step_token instead of slipping past the matcher.
STEP_DECL='^#{1,6}[[:space:]]+\**Step [^:[:space:]]+'                       # heading
STEP_DECL="${STEP_DECL}|\\*\\*Step [^:[:space:]]+"                          # bold run
STEP_DECL="${STEP_DECL}|^[[:space:]]*([-*+]|[0-9]+\\.)[[:space:]]+\\**Step [^:[:space:]]+"  # list item

scan_md "$STEP_DECL"
step_hits=""
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  token="${line#*Step }"    # strip through "file:lineno:...Step "
  token="${token//\*/}"     # emphasis is a terminator, not part of the token: "1.2.3**" -> "1.2.3"
  token="${token%.}"        # a sentence period likewise: "**Step 1.**" -> "1"
  if ! is_allowed_step_token "$token"; then
    step_hits="${step_hits}${line}
"
  fi
done < <(printf '%s\n' "$scan_out")

hits="${phase_hits}"
if [[ -n "$step_hits" ]]; then
  if [[ -n "$hits" ]]; then
    hits="${hits}
${step_hits%$'\n'}"
  else
    hits="${step_hits%$'\n'}"
  fi
fi

if [[ -z "$hits" ]]; then
  echo "phase-numbering: no forbidden phase labels and no out-of-family step labels under ${ROOT} (CHANGELOG exempt)"
  exit 0
fi
echo "phase-numbering: forbidden phase/step labels found:"
echo "$hits"
exit 1
