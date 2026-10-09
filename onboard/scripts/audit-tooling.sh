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

cd "$PROJECT_ROOT" || exit 1

echo "## Tooling Audit Report"
echo ""

# --- Check 1: CLAUDE.md commands still exist ---
echo "### Checking CLAUDE.md commands..."
if [ -f "CLAUDE.md" ]; then
  # Extract npm script references from CLAUDE.md
  if [ -f "package.json" ]; then
    while IFS= read -r script_name; do
      if [ -n "$script_name" ]; then
        if ! python3 -c "import json,sys; d=json.load(open('package.json')); sys.exit(0 if sys.argv[1] in d.get('scripts',{}) else 1)" "$script_name" 2>/dev/null; then
          add_drift "CLAUDE.md references 'npm run $script_name' but script not found in package.json"
        fi
      fi
    done < <(grep -oE '(npm run |pnpm run |yarn )[a-zA-Z0-9_:-]+' CLAUDE.md 2>/dev/null | sed 's/^.*run //; s/^yarn //' || true)
  fi
fi

# --- Check 2: Rule file path targets exist ---
# Prints one drift line per `paths:` glob that matches nothing. python3 reads the frontmatter and
# matches the globs itself, so the result is the same under bash 3.2 and 5 and under BSD and GNU sed:
# `**` spans directories, `*` and `?` stay inside one path segment, a dot-directory matches like any
# other, and `{a,b}` lists expand. .git and node_modules are not searched.
check_rule_paths() {
  python3 - <<'PY'
import glob
import os
import re


def rule_paths(text):
    """The `paths:` list of a rule file's frontmatter, unquoted."""
    lines = text.split("\n")
    if lines[0].rstrip() != "---":
        return []
    paths, in_paths = [], False
    for line in lines[1:]:
        if line.rstrip() == "---":
            break
        if re.match(r"paths:\s*$", line):
            in_paths = True
            continue
        if not in_paths or not line.strip() or line.lstrip().startswith("#"):
            continue
        item = re.match(r"\s*-\s+(.*)$", line)
        if not item:
            in_paths = False
            continue
        value = item.group(1).strip()
        if value[:1] in ("'", '"'):
            end = value.find(value[0], 1)
            value = value[1:end] if end > 0 else value[1:]
        else:
            value = re.sub(r"\s+#.*$", "", value)
        paths.append(value)
    return paths


def glob_regex(pattern):
    braces = pattern.count("{") == pattern.count("}")
    out, i, depth = [], 0, 0
    while i < len(pattern):
        c = pattern[i]
        if c == "*":
            j = i
            while j < len(pattern) and pattern[j] == "*":
                j += 1
            if j - i == 1:
                out.append("[^/]*")
            elif pattern[j:j + 1] == "/" and (i == 0 or pattern[i - 1] == "/"):
                out.append("(?:.*/)?")
                j += 1
            else:
                out.append(".*")
            i = j
            continue
        close = pattern.find("]", i + 2) if c == "[" else -1
        if c == "?":
            out.append("[^/]")
        elif close != -1:
            body = pattern[i + 1:close]
            if body[0] in "!^":
                body = "^" + body[1:]
            out.append("[" + body.replace("\\", "\\\\") + "]")
            i = close
        elif braces and c == "{":
            out.append("(?:")
            depth += 1
        elif braces and depth and c == ",":
            out.append("|")
        elif braces and depth and c == "}":
            out.append(")")
            depth -= 1
        else:
            out.append(re.escape(c))
        i += 1
    return re.compile("".join(out) + r"\Z")


entries = []
for top, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in (".git", "node_modules")]
    rel = os.path.relpath(top, ".")
    for name in dirs + files:
        entries.append(name if rel == "." else rel.replace(os.sep, "/") + "/" + name)

for rule_file in sorted(glob.glob(".claude/rules/*.md")):
    with open(rule_file, encoding="utf-8", errors="replace") as f:
        text = f.read()
    for path in rule_paths(text):
        if not path:
            continue
        target = path[2:] if path.startswith("./") else path.lstrip("/")
        regex = glob_regex(target)
        if not any(regex.match(e) for e in entries):
            print("Rule '%s' targets path '%s' but no matching files found" % (rule_file, path))
PY
}

echo "### Checking rule path targets..."
if [ -d ".claude/rules" ]; then
  # A check that cannot run is drift too: a silent pass here is what hid this check on macOS.
  if rule_drift="$(check_rule_paths)"; then
    while IFS= read -r drift_line; do
      if [ -n "$drift_line" ]; then
        add_drift "$drift_line"
      fi
    done <<< "$rule_drift"
  else
    add_drift "Rule path check could not run (python3 missing or failed)"
  fi
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
  printf '%b\n' "$REPORT"
  # GitHub Actions output
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      echo "has_drift=true"
      echo "report<<EOF"
      printf '%b\n' "$REPORT"
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
