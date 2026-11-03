#!/usr/bin/env bash
# H8 coverage: settings.md overrides are honored. Since 1.1.0 the snooze window is
# applied by snooze.sh (marker = now + deferral-snooze-hours) and the stale check by
# compute-progress.sh (`stale`), which the pickup skill acts on; the hook only reads
# the marker.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib.sh"

iso() { local off="$1"
  date -u -d "@$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -r "$(( $(date +%s) + off ))" +%Y-%m-%dT%H:%M:%SZ; }

# (1) deferral-snooze-hours override: 1h. snooze.sh sets the marker ~1h ahead, so
#     the hook is silent now; once that hour has passed (simulated by moving the
#     marker 5h back, i.e. "deferred 5h ago"), compute-progress reports expired and
#     the hook announces.
FIXTURE_ROOT="$(setup_fake_project)"
write_active_handoff "$(iso -604800)" HEAD main "$FIXTURE_ROOT"
printf -- '---\ndeferral-snooze-hours: 1\n---\n' > "$FIXTURE_ROOT/.claude/handoff/settings.md"
bash "$REPO_ROOT/handoff/scripts/snooze.sh" "$FIXTURE_ROOT" >/dev/null
assert_eq "" "$(run_hook_in "$FIXTURE_ROOT")" "override snooze=1h → silent right after Save for later"
set_snooze_marker "$FIXTURE_ROOT" -14400   # deferred 5h ago with a 1h window
eval "$(bash "$REPO_ROOT/handoff/scripts/compute-progress.sh" "$FIXTURE_ROOT")"
# snooze_remaining is assigned by the eval'd compute-progress output above — SC2154 false positive.
# shellcheck disable=SC2154
assert_contains "expired" "$snooze_remaining" "override snooze=1h, 5h later → compute-progress reports expired"
assert_contains "handoff:pickup" "$(run_hook_in "$FIXTURE_ROOT")" "override snooze=1h, 5h later → hook announces"
cleanup

# (2) stale-day-threshold override: saved 10 days ago; default 90 keeps it live,
#     an override of 5 marks it stale (pickup then archives it as expired).
FIXTURE_ROOT="$(setup_fake_project)"
write_active_handoff "$(iso -864000)" HEAD main "$FIXTURE_ROOT"
eval "$(bash "$REPO_ROOT/handoff/scripts/compute-progress.sh" "$FIXTURE_ROOT")"
# shellcheck disable=SC2154
assert_eq "no" "$stale" "default stale=90d → 10-day-old handoff is not stale"
printf -- '---\nstale-day-threshold: 5\n---\n' > "$FIXTURE_ROOT/.claude/handoff/settings.md"
eval "$(bash "$REPO_ROOT/handoff/scripts/compute-progress.sh" "$FIXTURE_ROOT")"
assert_eq "yes" "$stale" "override stale=5d → 10-day-old handoff is stale"
# shellcheck disable=SC2154
assert_eq "5" "$stale_day_threshold" "override threshold is reported"
printf -- '---\nstale-day-threshold: soon\n---\n' > "$FIXTURE_ROOT/.claude/handoff/settings.md"
eval "$(bash "$REPO_ROOT/handoff/scripts/compute-progress.sh" "$FIXTURE_ROOT")"
assert_eq "90" "$stale_day_threshold" "non-integer threshold → default 90"
# A zero-padded value is decimal: 08 days, not an octal error that leaves the handoff never stale.
printf -- '---\nstale-day-threshold: 08\n---\n' > "$FIXTURE_ROOT/.claude/handoff/settings.md"
eval "$(bash "$REPO_ROOT/handoff/scripts/compute-progress.sh" "$FIXTURE_ROOT")"
assert_eq "8" "$stale_day_threshold" "zero-padded 08 → 8, not read as octal"
assert_eq "yes" "$stale" "08-day threshold → 10-day-old handoff is stale"
cleanup

summary
