#!/usr/bin/env bash
set -euo pipefail

GRAPH=""
STATE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --graph) [ $# -ge 2 ] || { echo "usage: $0 --graph G --state S" >&2; exit 2; }; GRAPH="$2"; shift 2 ;;
    --state) [ $# -ge 2 ] || { echo "usage: $0 --graph G --state S" >&2; exit 2; }; STATE="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$GRAPH" ] && [ -n "$STATE" ] || { echo "usage: $0 --graph G --state S" >&2; exit 2; }

jq -n \
  --slurpfile g "$GRAPH" \
  --slurpfile s "$STATE" \
  '
  ($g[0]) as $graph
  | ($s[0]) as $state
  | ($state.phase0 // {}) as $p0
  | ($state.synthesisStatus // {}) as $approved
  | ($state.parkedPhases // []) as $parked
  | ($state.currentPhase // null) as $current

  # matches_hide: evaluate a single hideIf clause against state.
  # clause is an object like {"phase0.appType":"cli"} or {"personas.commerceUser":false}.
  # Routing rules:
  #   - path[0] == "phase0"   -> look up rest of path in $p0 (which IS phase0)
  #   - path[0] == "personas" -> $p0.personas is an array; hide when ALL elements
  #                              match the clause value at the sub-path
  #   - anything else         -> look up full path in $state
  | def matches_hide(clause; p0; st):
      (clause | to_entries[0]) as $kv
      | ($kv.key | split(".")) as $path
      | if $path[0] == "phase0" then
          (p0 | getpath($path[1:])) == $kv.value
        elif $path[0] == "personas" then
          ((p0.personas // []) | map(getpath($path[1:])) | all(. == $kv.value))
        else
          (st | getpath($path)) == $kv.value
        end;

  # Build the set of hidden phase names in two passes:
  # Pass 1: phases with a direct hideIf match.
  # Pass 2: phases whose every required phase is already hidden (inherited HIDDEN).
  # One round of propagation is sufficient for the graph depth.
  def directly_hidden(g; p0; st):
      g.phases | to_entries
      | map(select(
          (.value.hideIf | length > 0) and
          (.value.hideIf | map(matches_hide(.; p0; st)) | any)
        ))
      | map(.key);
  # INVARIANT: single-pass propagation is sufficient because the 18-phase
  # dependency graph has no chain where a phase is hidden only by transitive
  # propagation without a direct hideIf match (every transitively-hidden
  # phase shares a hideIf prefix with at least one of its requires).
  # If you add a phase whose only requires are transitively-hidden
  # (not directly-hidden), convert this to a fixed-point loop.
  def compute_hidden(g; p0; st):
      directly_hidden(g; p0; st) as $dh
      | g.phases | to_entries
      | map(select(
          (.key as $k | $dh | index($k) != null) or
          ((.value.requires // []) | length > 0 and
           all(. as $req | $dh | index($req) != null))
        ))
      | map(.key);

  compute_hidden($graph; $p0; $state) as $hidden_phases
  | def is_hidden(name): name as $n | $hidden_phases | index($n) != null;
  def status_for(name; phase):
      name as $n | phase as $ph
      | if is_hidden($n) then "HIDDEN"
        elif $approved[$n] == "approved" then "APPROVED"
        elif ($parked | index($n)) != null then "PARKED"
        elif $current == $n then "IN_PROGRESS"
        elif ($ph.requires // []) | map($approved[.] == "approved") | all then "AVAILABLE"
        else "LOCKED"
        end;

  def blocking_reason(phase):
      phase as $ph
      | (($ph.requires // []) | map(select($approved[.] != "approved"))) as $unmet
      | if ($unmet | length) > 0 then "Requires: " + ($unmet | join(", ")) else null end;

  def hidden_reason(name; phase):
      name as $n | phase as $ph
      | if ($ph.hideIf // []) | map(matches_hide(.; $p0; $state)) | any then
          (($ph.hideIf // []) | map(select(matches_hide(.; $p0; $state))) | first) as $hit
          | if $hit != null then ($hit | to_entries[0] | "\(.key): \(.value)") else null end
        else
          "inherited: required phase is hidden"
        end;

  {
      schemaVersion: "1.0",
      renderedAt: (now | todate),
      phase0: $p0,
      phases: (
        $graph.phases | to_entries | map({
          key: .key,
          value: (
            .value as $ph
            | status_for(.key; $ph) as $st
            | {
                label: $ph.label,
                layer: $ph.layer,
                icon: $ph.icon,
                hint: $ph.hint,
                status: $st,
                synthesisDocUrl: (if $st == "APPROVED" then "/adr/" + (.key | gsub("(?<x>[A-Z])"; "-\(.x | ascii_downcase)") | ltrimstr("-")) else null end),
                blockingReason: (if $st == "LOCKED" then blocking_reason($ph) else null end),
                hiddenReason: (if $st == "HIDDEN" then hidden_reason(.key; $ph) else null end)
              }
          )
        }) | from_entries
      ),
      completionPolicy: (
        ($graph.phases | to_entries | map(select(.value.requiredForCompletion == true))) as $req
        | {
            requiredApproved: ($req | length),
            currentApproved: ($req | map(select($approved[.key] == "approved")) | length),
            canAdvanceToScaffold: ($req | all($approved[.key] == "approved"))
          }
      )
    }
  '
