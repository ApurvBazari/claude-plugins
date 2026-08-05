#!/usr/bin/env bash
# Snooze-path coverage (charter) + H9 future-deferred guard.
# Runs the hook and checks whether it emits additionalContext (surfaces) or stays silent.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
HOOK="$REPO_ROOT/handoff/hooks/session-start.sh"
# shellcheck disable=SC1091
. "$HERE/lib.sh"

iso() { # <seconds-offset-from-now>  → ISO-8601 UTC
  local off="$1"
  if date -u -d "@$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then :; \
  else date -u -r "$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ; fi
}

run_hook() { # emits hook stdout for the fixture at FIXTURE_ROOT
  CLAUDE_PLUGIN_ROOT="$REPO_ROOT/handoff" bash "$HOOK" \
    <<<"{\"cwd\":\"$FIXTURE_ROOT\"}" 2>/dev/null
}

# Case A: deferred 1h ago, snooze 24h → still snoozed → SILENT
FIXTURE_ROOT="$(setup_fake_project)"
write_active_handoff "$(iso -604800)" HEAD main "$FIXTURE_ROOT" "$(iso -3600)"
out="$(run_hook)"
assert_eq "" "$out" "A: deferred 1h ago → hook silent (snoozed)"
cleanup

# Case B: deferred 48h ago, snooze 24h → expired → SURFACES
FIXTURE_ROOT="$(setup_fake_project)"
write_active_handoff "$(iso -604800)" HEAD main "$FIXTURE_ROOT" "$(iso -172800)"
out="$(run_hook)"
assert_contains "handoff:pickup" "$out" "B: deferred 48h ago → hook surfaces"
cleanup

# Case C: deferred in the FUTURE (+72h) → must NOT suppress forever → SURFACES (H9)
FIXTURE_ROOT="$(setup_fake_project)"
write_active_handoff "$(iso -604800)" HEAD main "$FIXTURE_ROOT" "$(iso 259200)"
out="$(run_hook)"
assert_contains "handoff:pickup" "$out" "C: future deferred-at → hook surfaces (no forever-suppress)"
cleanup

summary
