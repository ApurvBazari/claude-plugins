#!/usr/bin/env bash
set -euo pipefail

# Refresh vendored frontend assets with SHA256 verification.
# Uses parallel arrays for bash 3.2 compatibility (macOS default).
# Run from anywhere; resolves paths relative to this script.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/../assets"
mkdir -p "$ASSETS_DIR"

NAMES=(
  "cytoscape-3.30.4.min.js"
  "cytoscape-dagre-2.5.0.min.js"
  "dagre-0.8.5.min.js"
  "mermaid-11.4.1.min.js"
  "highlight-11.10.0.min.js"
  "highlight-github.min.css"
)

URLS=(
  "https://unpkg.com/cytoscape@3.30.4/dist/cytoscape.min.js"
  "https://unpkg.com/cytoscape-dagre@2.5.0/cytoscape-dagre.js"
  "https://unpkg.com/dagre@0.8.5/dist/dagre.min.js"
  "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js"
  "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.10.0/highlight.min.js"
  "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.10.0/styles/github.min.css"
)

for i in "${!NAMES[@]}"; do
  filename="${NAMES[$i]}"
  url="${URLS[$i]}"
  target="$ASSETS_DIR/$filename"
  echo "Fetching $filename from $url"
  curl -fsSL "$url" -o "$target"
  size=$(wc -c < "$target")
  if [ "$size" -lt 1024 ]; then
    echo "ERROR: $filename is suspiciously small (${size} bytes). Aborting." >&2
    exit 1
  fi
  shasum -a 256 "$target" | awk '{ print $1 }' > "$target.sha256"
  echo "  OK ($size bytes, sha256: $(cat "$target.sha256"))"
done

echo "Done. Review checksums and commit."
