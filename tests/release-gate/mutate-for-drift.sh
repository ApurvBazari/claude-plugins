#!/usr/bin/env bash
set -euo pipefail

# mutate-for-drift.sh — Apply drift mutations for Phase 4 testing
# Usage: mutate-for-drift.sh <REPO_PATH>
# Run AFTER /onboard:init has completed on the repo.
# Then run /onboard:update to test drift detection.

REPO="${1:-}"

if [[ -z "$REPO" || ! -d "$REPO" ]]; then
  echo "Usage: mutate-for-drift.sh <REPO_PATH>"
  exit 1
fi

cd "$REPO"

echo "## Applying Drift Mutations"
echo ""
echo "Repo: ${REPO}"
echo ""

MUTATIONS=0

# ─────────────────────────────────────────────────
echo "### Mutation 1: Delete a generated rule (Artifact Gap — PR #33)"
# ─────────────────────────────────────────────────
RULE_FILE=$(find .claude/rules -name '*.md' -type f 2>/dev/null | head -1)
if [[ -n "$RULE_FILE" ]]; then
  echo "  Deleting: ${RULE_FILE}"
  rm "$RULE_FILE"
  MUTATIONS=$((MUTATIONS + 1))
  echo "  Expected: /onboard:update detects Artifact Gap, offers regenerate"
else
  echo "  SKIP: no rule files found to delete"
fi
echo ""

# ─────────────────────────────────────────────────
echo "### Mutation 2: Edit agent frontmatter (User Edit — PR #36)"
# ──────────���──────────────────────────────────────
AGENT_FILE=$(find .claude/agents -name '*.md' -type f 2>/dev/null | head -1)
if [[ -n "$AGENT_FILE" ]]; then
  echo "  Editing: ${AGENT_FILE}"
  # Change model field to a different value
  if grep -q '^model:' "$AGENT_FILE"; then
    sed -i.bak 's/^model: .*/model: claude-haiku-4-5-20251001/' "$AGENT_FILE"
    rm -f "${AGENT_FILE}.bak"
    echo "  Changed model → claude-haiku-4-5-20251001"
  else
    # Add a model field if none exists
    sed -i.bak '1,/^---$/{ /^---$/i\
model: claude-haiku-4-5-20251001
}' "$AGENT_FILE"
    rm -f "${AGENT_FILE}.bak"
    echo "  Added model: claude-haiku-4-5-20251001"
  fi
  MUTATIONS=$((MUTATIONS + 1))
  echo "  Expected: /onboard:update classifies as user-edit, preserves change"
else
  echo "  SKIP: no agent files found to edit"
fi
echo ""

# ─────────────────────���───────────────────────────
echo "### Mutation 3: Edit output style body (Body Edit — PR #37)"
# ─────────────────────────────��───────────────────
STYLE_FILE=$(find .claude/output-styles -name '*.md' -type f 2>/dev/null | head -1 || true)
if [[ -n "$STYLE_FILE" ]]; then
  echo "  Editing body of: ${STYLE_FILE}"
  {
    echo ""
    echo "## Custom Addition"
    echo "This paragraph was added to test that body edits are not flagged."
  } >> "$STYLE_FILE"
  MUTATIONS=$((MUTATIONS + 1))
  echo "  Expected: /onboard:update does NOT flag this (body outside snapshot scope)"
else
  echo "  SKIP: no output style files found to edit"
fi
echo ""

# ─────���─────────────���─────────────────────────────
echo "### Mutation 4: Add @anthropic-ai/sdk dependency (PR #39)"
# ─────────────────────────────────────────────────
if [[ -f "package.json" ]]; then
  echo "  Adding @anthropic-ai/sdk to package.json dependencies"
  # Use jq to add the dependency
  jq '.dependencies["@anthropic-ai/sdk"] = "0.30.0"' package.json > package.json.tmp
  mv package.json.tmp package.json
  MUTATIONS=$((MUTATIONS + 1))
  echo "  Expected: /onboard:update flags /claude-api as newly relevant built-in skill"
else
  echo "  SKIP: no package.json found"
fi
echo ""

# ────────────────────────────��────────────────────
echo "### Mutation 5: Add Rust source file (PR #38)"
# ���────────────────────────────────────────────────
echo "  Creating src/main.rs"
mkdir -p src
cat > src/main.rs <<'ERS'
fn main() {
    println!("Hello, drift test!");
}
ERS
MUTATIONS=$((MUTATIONS + 1))
echo "  Expected: /onboard:update flags rust-analyzer-lsp as newLanguage candidate"
echo ""

# ──���──────────────────────────────────────────────
echo "═══════════════════════════════════════════"
echo "## Mutations Applied: ${MUTATIONS}"
echo ""
echo "Next steps:"
echo "  1. cd ${REPO}"
echo "  2. claude"
echo "  3. Run: /onboard:update"
echo "  4. Approve/review each finding"
echo "  5. Exit Claude"
echo "  6. Run: verify-drift-output.sh ${REPO}"
