#!/usr/bin/env bash
# assert-claude-run-complete.sh — fail a CI job unless its claude-code-action step completed.
#
# claude-code-action v1 sets outputs.conclusion to "success" only when Claude ran and ended in
# a successful result. It can also exit GREEN without running Claude at all — no prompt reached
# it, or the Claude-App token exchange skipped a PR that changes workflow files — and leaves
# conclusion empty. Without this step that path shows a passing check for a review that never
# happened. Run it with `if: always()` right after the action step.
#
# Env:
#   CLAUDE_CONCLUSION      ${{ steps.<id>.outputs.conclusion }}
#   CLAUDE_EXECUTION_FILE  ${{ steps.<id>.outputs.execution_file }}  (optional; used for diagnostics)
set -euo pipefail

conclusion="${CLAUDE_CONCLUSION:-}"
exec_file="${CLAUDE_EXECUTION_FILE:-}"

if [[ "$conclusion" == "success" ]]; then
  echo "Claude run completed (conclusion=success)."
  exit 0
fi

detail="no execution record: the action exited before Claude ran (no prompt reached it, the PR changes workflow files, or an earlier step failed)"
if [[ -n "$conclusion" ]]; then
  detail="conclusion=${conclusion}"
fi
if [[ -n "$exec_file" && -f "$exec_file" ]] && command -v jq >/dev/null 2>&1; then
  detail="$(jq -r '
    if type != "array" or length == 0 then "empty execution record"
    elif (last | .type) == "result" then (last | "subtype=\(.subtype) is_error=\(.is_error) turns=\(.num_turns)")
    else "no result message: the stream ended before Claude finished"
    end' "$exec_file" 2>/dev/null)" || detail="unreadable execution record at ${exec_file}"
fi

echo "::error title=Claude run incomplete::The Claude step did not complete (${detail}). A passing check here would report a review that never happened."
exit 1
