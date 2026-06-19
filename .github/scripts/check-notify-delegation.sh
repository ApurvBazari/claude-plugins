#!/usr/bin/env bash
# check-notify-delegation.sh — assert onboard DELEGATES notify setup to /notify:setup
# and never wires notify per-repo from its start / generate flows.
# Usage: check-notify-delegation.sh   (run from the claude-plugins repo root)
#
# Background: onboard used to copy notify.sh into a project's .claude/hooks/, write a
# project notify-config.json, run notify's install-notifier.sh, and merge notify hooks
# into the project settings.json. That duplicated the notify plugin's own /notify:setup
# and — in marketplace (versioned-cache) installs, where the sibling copy path doesn't
# resolve — produced a hand-rolled, config-blind notify.sh. The fix delegates entirely to
# /notify:setup. This gate guards that so the per-repo emission can't silently regress.
#
# It deliberately matches the EMISSION CONSTRUCTS (command/probe tokens), never plain
# prose, so the legitimate "onboard does NOT copy notify.sh / write notify-config.json"
# delegation wording does not trip it. The install-presence probe
# (${CLAUDE_PLUGIN_ROOT}/../notify/scripts/notify.sh) is intentionally still allowed.
set -euo pipefail

START="onboard/skills/start/SKILL.md"
GEN="onboard/skills/generate/SKILL.md"
fail=0

for f in "$START" "$GEN"; do
  [ -f "$f" ] || { echo "missing $f"; fail=1; }
done

# NEGATIVE — these per-repo emission constructs must NOT appear in start/generate flows.
for f in "$START" "$GEN"; do
  [ -f "$f" ] || continue
  # Removed buggy global-detection probe.
  if grep -q 'HAS_GLOBAL_HOOK' "$f"; then
    echo "$f: carries the removed globalConfigured/HAS_GLOBAL_HOOK probe"; fail=1
  fi
  # cp destination of the per-repo hook copy.
  if grep -qF 'BASE_DIR/hooks/notify.sh' "$f"; then
    echo "$f: writes a per-repo .claude/hooks/notify.sh (delegate to /notify:setup instead)"; fail=1
  fi
  # Running notify's installer per-repo (path form is the invocation, not prose).
  if grep -qE 'notify/scripts/install-notifier' "$f"; then
    echo "$f: runs notify's install-notifier.sh per-repo (delegate to /notify:setup instead)"; fail=1
  fi
  # Writing a project notify-config.json (the write instruction pairs it with BASE_DIR).
  if grep -qE 'notify-config\.json.*BASE_DIR|BASE_DIR.*notify-config\.json' "$f"; then
    echo "$f: writes a project notify-config.json (delegate to /notify:setup instead)"; fail=1
  fi
done

# POSITIVE — start must point the developer at /notify:setup.
if [ -f "$START" ] && ! grep -qF '/notify:setup' "$START"; then
  echo "$START: no /notify:setup delegation found"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "notify-delegation: start + generate delegate to /notify:setup; no per-repo notify emission"
  exit 0
fi
exit 1
