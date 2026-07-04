#!/usr/bin/env bash
# H8 coverage: settings.md overrides are honored by compute-progress (snooze
# window) and the hook (stale-day-threshold). Uses the lib.sh deferred param.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
HOOK="$REPO_ROOT/handoff/hooks/session-start.sh"
# shellcheck disable=SC1091
. "$HERE/lib.sh"

iso() { local off="$1"
  date -u -d "@$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -r "$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ; }

# (1) deferral-snooze-hours override: deferred 5h ago; default 24h would snooze,
#     but an override of 1h means the snooze already expired → compute-progress
#     reports "expired", hook surfaces.
FIXTURE_ROOT="$(setup_fake_project)"
write_active_handoff "$(iso -604800)" HEAD main "$FIXTURE_ROOT" "$(iso -18000)"
printf -- '---\ndeferral-snooze-hours: 1\n---\n' > "$FIXTURE_ROOT/.claude/handoff/settings.md"
eval "$(bash "$REPO_ROOT/handoff/scripts/compute-progress.sh" "$FIXTURE_ROOT")"
# snooze_remaining is assigned by the eval'd compute-progress output above — the
# SC2154 "referenced but not assigned" warning is a false positive (same as the
# sibling test_compute_progress.sh contract).
# shellcheck disable=SC2154
assert_contains "expired" "$snooze_remaining" "override snooze=1h → compute-progress reports expired"
out="$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT/handoff" bash "$HOOK" <<<"{\"cwd\":\"$FIXTURE_ROOT\"}" 2>/dev/null)"
assert_contains "handoff:pickup" "$out" "override snooze=1h → hook surfaces (not silent)"
cleanup

# (2) stale-day-threshold override: saved 10 days ago; default 90 keeps it live,
#     but an override of 5 triggers the stale auto-archive.
FIXTURE_ROOT="$(setup_fake_project)"
write_active_handoff "$(iso -864000)" HEAD main "$FIXTURE_ROOT"
printf -- '---\nstale-day-threshold: 5\n---\n' > "$FIXTURE_ROOT/.claude/handoff/settings.md"
out="$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT/handoff" bash "$HOOK" <<<"{\"cwd\":\"$FIXTURE_ROOT\"}" 2>/dev/null)"
assert_contains "auto-archived" "$out" "override stale=5d → hook auto-archives at 10 days old"
assert_file_exists "$(find "$FIXTURE_ROOT/.claude/handoff/archive" -name 'expired-*.md' | head -1)"
cleanup

summary
