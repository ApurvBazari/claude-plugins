#!/usr/bin/env bash
set -euo pipefail

# Structural drift checks for CI tooling audit pipeline.
# Checks whether CLAUDE.md, rules, hooks, and skills are in sync with the codebase.
# Outputs a drift report and sets has_drift output for GitHub Actions.

PROJECT_ROOT="${1:-.}"
DRIFT_FOUND=0
REPORT=""

add_drift() {
  DRIFT_FOUND=1
  REPORT="${REPORT}  - $1\n"
}

cd "$PROJECT_ROOT"

echo "## Tooling Audit Report"
echo ""

# --- Check 1: CLAUDE.md commands still exist ---
echo "### Checking CLAUDE.md commands..."
if [ -f "CLAUDE.md" ]; then
  # Extract npm script references from CLAUDE.md
  if [ -f "package.json" ]; then
    while IFS= read -r script_name; do
      if [ -n "$script_name" ]; then
        if ! python3 -c "import json,sys; d=json.load(open('package.json')); sys.exit(0 if '$script_name' in d.get('scripts',{}) else 1)" 2>/dev/null; then
          add_drift "CLAUDE.md references 'npm run $script_name' but script not found in package.json"
        fi
      fi
    done < <(grep -oP '(?:npm run |pnpm run |yarn )\K[\w:-]+' CLAUDE.md 2>/dev/null || true)
  fi
fi

# --- Check 2: Rule file path targets exist ---
echo "### Checking rule path targets..."
if [ -d ".claude/rules" ]; then
  for rule_file in .claude/rules/*.md; do
    [ -f "$rule_file" ] || continue
    # Extract paths from YAML frontmatter
    while IFS= read -r rule_path; do
      rule_path=$(echo "$rule_path" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '"' | tr -d "'")
      if [ -n "$rule_path" ] && [ "$rule_path" != "**" ]; then
        # Check if the glob pattern matches any files
        # shellcheck disable=SC2086
        if ! compgen -G "$rule_path" >/dev/null 2>&1; then
          add_drift "Rule '$rule_file' targets path '$rule_path' but no matching files found"
        fi
      fi
    done < <(sed -n '/^---$/,/^---$/{ /^paths:/,/^[^ ]/{ /^  *- /s/^  *- //p } }' "$rule_file" 2>/dev/null || true)
  done
fi

# --- Check 3: Hook scripts exist ---
echo "### Checking hook script references..."
if [ -f ".claude/settings.json" ]; then
  while IFS= read -r script_path; do
    script_path=$(echo "$script_path" | sed 's/.*bash //' | sed 's/ .*//' | tr -d '"')
    if [ -n "$script_path" ] && [ ! -f "$script_path" ]; then
      add_drift "settings.json references script '$script_path' but file not found"
    fi
  done < <(grep -o '"command"[[:space:]]*:[[:space:]]*"bash [^"]*"' .claude/settings.json 2>/dev/null || true)
fi

# --- Check 4: Detect uncovered directories ---
echo "### Checking for uncovered directories..."
if [ -f "CLAUDE.md" ]; then
  # Find directories with >5 source files that don't have a CLAUDE.md
  while IFS= read -r dir; do
    file_count=$(find "$dir" -maxdepth 1 -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" \) 2>/dev/null | wc -l | tr -d ' ')
    if [ "$file_count" -gt 5 ] && [ ! -f "$dir/CLAUDE.md" ]; then
      add_drift "Directory '$dir' has $file_count source files but no CLAUDE.md"
    fi
  done < <(find src app lib -maxdepth 2 -type d 2>/dev/null || true)
fi

# --- Check 5: Detect new dependencies not in CLAUDE.md ---
echo "### Checking for undocumented dependencies..."
if [ -f "package.json" ] && [ -f "CLAUDE.md" ]; then
  while IFS= read -r dep; do
    if [ -n "$dep" ] && ! grep -q "$dep" CLAUDE.md 2>/dev/null; then
      # Only flag "important" deps (not type definitions or small utilities)
      case "$dep" in
        @types/*|eslint-*|prettier*|typescript) ;;  # skip dev tooling
        *) add_drift "Dependency '$dep' in package.json not mentioned in CLAUDE.md" ;;
      esac
    fi
  done < <(python3 -c "import json; d=json.load(open('package.json')); [print(k) for k in {**d.get('dependencies',{}), **d.get('devDependencies',{})}.keys()]" 2>/dev/null || true)
fi

# --- Output ---
echo ""
if [ "$DRIFT_FOUND" -eq 1 ]; then
  echo "### Drift Detected"
  echo ""
  echo -e "$REPORT"
  # GitHub Actions output
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      echo "has_drift=true"
      echo "report<<EOF"
      echo -e "$REPORT"
      echo "EOF"
    } >> "$GITHUB_OUTPUT"
  fi
  exit 0
else
  echo "### No Drift"
  echo "All tooling is in sync with the codebase."
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "has_drift=false" >> "$GITHUB_OUTPUT"
  fi
  exit 0
fi
