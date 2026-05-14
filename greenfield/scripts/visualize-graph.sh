#!/usr/bin/env bash
# greenfield/scripts/visualize-graph.sh
#
# Reads all docs/architecture/p*-dependencies.json files in the current project
# and outputs a Mermaid graph showing cross-phase dependencies.
#
# Usage:
#   bash visualize-graph.sh                  # output to stdout
#   bash visualize-graph.sh > graph.mmd      # write to file
#   GREENFIELD_DOC_DIR=path bash visualize-graph.sh   # custom doc dir

set -euo pipefail

DOC_DIR="${GREENFIELD_DOC_DIR:-docs/architecture}"

if [ ! -d "$DOC_DIR" ]; then
  echo "no $DOC_DIR/ directory — run a greenfield synthesis review first" >&2
  exit 1
fi

mapfile -t dep_files < <(find "$DOC_DIR" -maxdepth 1 -name "p*-dependencies.json" -type f | sort)

if [ "${#dep_files[@]}" -eq 0 ]; then
  echo "no dependency files in $DOC_DIR/ — nothing to visualize" >&2
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (brew install jq / apt install jq)" >&2
  exit 1
fi

echo "graph TD"
echo "  %% Greenfield phase dependency graph"
echo "  %% Generated from ${#dep_files[@]} dependency file(s) in $DOC_DIR/"
echo ""

# First pass: collect all unique phase ids that appear (as declarer or as source).
declare -A seen_phases
for f in "${dep_files[@]}"; do
  declarer="$(jq -r '.phase' "$f")"
  seen_phases["$declarer"]=1
  while IFS= read -r dep_phase; do
    [ -n "$dep_phase" ] && seen_phases["$dep_phase"]=1
  done < <(jq -r '.dependencies[].path | split(".")[0]' "$f")
done

# Node declarations (sorted for stable output).
for phase in $(printf '%s\n' "${!seen_phases[@]}" | sort); do
  # Replace dots in phase ids (e.g., P10.5) with underscores for Mermaid node ids.
  node_id="${phase//./_}"
  echo "  ${node_id}[\"${phase}\"]"
done

echo ""

# Second pass: edges. Each dependency.path emits one edge from source-phase to declarer.
for f in "${dep_files[@]}"; do
  declarer="$(jq -r '.phase' "$f")"
  declarer_node="${declarer//./_}"
  while IFS= read -r dep_path; do
    [ -z "$dep_path" ] && continue
    dep_phase="${dep_path%%.*}"
    dep_node="${dep_phase//./_}"
    field="${dep_path#*.}"
    # Mermaid edge with a label = the depended-on field.
    echo "  ${dep_node} -->|${field}| ${declarer_node}"
  done < <(jq -r '.dependencies[].path' "$f")
done
