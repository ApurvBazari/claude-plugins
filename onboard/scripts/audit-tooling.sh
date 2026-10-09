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
# Prints one drift line per `paths:` pattern that matches no file, judged the way Claude Code judges
# it. Claude Code splits a `paths` value on commas, expands braces, drops a trailing `/**`, and
# matches with the `ignore` library, so the semantics are gitignore's: a pattern with no slash matches
# at any depth, one with a slash is anchored to the project root, a directory's name covers the files
# under it, letter case is ignored, and a dot-directory matches like any other. python3 does all of
# it, so the result is the same under bash 3.2 and 5 and under BSD and GNU tools. .git and
# node_modules are not searched.
check_rule_paths() {
  python3 - <<'PY'
import glob
import os
import re
import warnings

YAML_FLOW_ITEM = r'"(?:[^"\\]|\\.)*"' + "|'(?:[^']|'')*'|[^,]+"


def unquote(value):
    """A YAML scalar's text: its quotes removed, or a plain one's trailing comment dropped."""
    value = value.strip()
    if value[:1] == '"':
        m = re.match(r'"((?:[^"\\]|\\.)*)"', value)
        return re.sub(r"\\(.)", r"\1", m.group(1)) if m else value[1:]
    if value[:1] == "'":
        m = re.match(r"'((?:[^']|'')*)'", value)
        return m.group(1).replace("''", "'") if m else value[1:]
    return re.sub(r"\s+#.*$", "", value)


def rule_paths(text):
    """The `paths` value of a rule file's frontmatter as written: a block list, a flow list or one string."""
    lines = text.split("\n")
    if lines[0].rstrip() != "---":
        return []
    items, in_paths = [], False
    for line in lines[1:]:
        if line.rstrip() == "---":
            break
        key = re.match(r"paths:\s*(.*)$", line)
        if key:
            value = key.group(1).strip()
            in_paths = not value or value.startswith("#")
            if value.startswith("["):
                inner = value[1:value.rindex("]")] if "]" in value else value[1:]
                items += [unquote(v) for v in re.findall(YAML_FLOW_ITEM, inner)]
            elif not in_paths:
                items.append(unquote(value))
            continue
        if not in_paths or not line.strip() or line.lstrip().startswith("#"):
            continue
        item = re.match(r"\s*-\s+(.*)$", line)
        if not item:
            in_paths = False
            continue
        items.append(unquote(item.group(1)))
    return items


def split_paths(value):
    """One `paths` string as Claude Code splits it: on commas outside braces, trimmed, blanks dropped."""
    parts, cur, depth = [], "", 0
    for c in value:
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        if c == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += c
    parts.append(cur.strip())
    return [part for part in parts if part]


def expand_braces(pattern, limit=1000):
    """Claude Code's brace expansion: the first {a,b} group at a time; past its budget, unexpanded."""
    done, todo = [], [pattern]
    while todo:
        cur = todo.pop()
        m = re.match(r"^([^{]*)\{([^}]+)\}(.*)$", cur, re.S)
        if not m:
            done.append(cur)
            continue
        alts = [alt.strip() for alt in m.group(2).split(",")]
        if len(done) + len(todo) + len(alts) > limit:
            return [pattern]
        todo.extend(m.group(1) + alt + m.group(3) for alt in reversed(alts))
    return done


def js_regex(src):
    """A JavaScript regex source as Python reads it. The ignore library writes JavaScript: there an
    escaped letter with no special meaning is that letter, the first `]` always closes a class, and
    `[]` matches nothing."""
    def escape(c):
        return c if c.isalpha() and c not in "bBdDsSwWfnrtvxuc" else "\\" + c

    out, i = [], 0
    while i < len(src):
        c = src[i]
        if c == "\\" and i + 1 < len(src):
            out.append(escape(src[i + 1]))
            i += 2
        elif c == "[":
            j = i + 1
            while j < len(src) and src[j] != "]":
                j += 2 if src[j] == "\\" else 1
            if j >= len(src):
                raise ValueError("unterminated class")
            body = src[i + 1:j]
            if body == "":
                out.append("(?!)")
            elif body == "^":
                out.append("[\\s\\S]")
            else:
                cls, k = [], 0
                while k < len(body):
                    if body[k] == "\\" and k + 1 < len(body):
                        cls.append(escape(body[k + 1]))
                        k += 2
                    else:
                        cls.append("\\[" if body[k] == "[" else body[k])
                        k += 1
                out.append("[" + "".join(cls) + "]")
            i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def ignore_regex(pattern):
    """The regex the ignore library (5.x) builds for one gitignore pattern, or None for a pattern it
    skips or cannot compile. Each substitution below is one of its replacers, in its order."""
    if not pattern.strip() or pattern.startswith("#") or re.search(r"(?:[^\\]|^)\\$", pattern):
        return None
    pattern = re.sub(r"^\\([!#])", r"\1", pattern)

    def even(slashes):
        return slashes[:len(slashes) - len(slashes) % 2]

    def bracket(m):
        lead, rng, end, close = m.group(1), m.group(2), m.group(3), m.group(4)
        if lead:
            return "\\[" + rng + even(end) + close
        if close != "]" or len(end) % 2:
            return "[]"
        ordered = re.sub(r"([0-z])-([0-z])", lambda r: r.group(0) if r.group(1) <= r.group(2) else "", rng)
        return "[" + ordered + end + "]"

    s = re.sub(r"^﻿", "", pattern)
    s = re.sub(r"((?:\\\\)*?)(\\?\s+)$",
               lambda m: m.group(1) + (" " if m.group(2).startswith("\\") else ""), s, count=1)
    s = re.sub(r"(\\+?)\s", lambda m: even(m.group(1)) + " ", s)
    s = re.sub(r"[\\$.|*+(){^]", lambda m: "\\" + m.group(0), s)
    s = s.replace("?", "[^/]")
    s = re.sub(r"^/", "^", s, count=1)
    s = s.replace("/", "\\/")
    s = re.sub(r"^\^*\\\*\\\*\\/", lambda m: "^(?:.*\\/)?", s, count=1)
    anchored = re.search(r"/(?!$)", pattern)
    s = re.sub(r"^(?=[^^])", lambda m: "^" if anchored else "(?:^|\\/)", s, count=1)
    s = re.sub(r"\\/\\\*\\\*(?=\\/|$)",
               lambda m: "(?:\\/[^\\/]+)*" if m.start() + 6 < len(m.string) else "\\/.+", s)
    s = re.sub(r"(^|[^\\]+)(\\\*)+(?=.+)", lambda m: m.group(1) + "[^\\/]*", s)
    s = re.sub(r"\\\\\\(?=[$.|*+(){^])", lambda m: "\\", s)
    s = re.sub(r"\\\\", lambda m: "\\", s)
    s = re.sub(r"(\\)?\[([^\]/]*?)(\\*)($|\])", bracket, s)
    s = re.sub(r"[^*]$", lambda m: m.group(0) + ("$" if m.group(0) == "/" else "(?=$|\\/$)"), s, count=1)
    s = re.sub(r"(\^|\\/)?\\\*$",
               lambda m: ((m.group(1) + "[^/]+") if m.group(1) else "[^/]*") + "(?=$|\\/$)", s, count=1)
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            return re.compile(js_regex(s), re.I)
    except (re.error, ValueError):
        return None


# What a pattern is tested against: every file, and every directory that holds one, the directory
# with a trailing slash. The library matches a file when it or a directory above it matches.
files = []
for top, subdirs, names in os.walk("."):
    subdirs[:] = [d for d in subdirs if d not in (".git", "node_modules")]
    rel = "" if top == "." else os.path.relpath(top, ".").replace(os.sep, "/") + "/"
    files += [rel + name for name in names]
parents = set()
for path in files:
    parts = path.split("/")
    parents.update("/".join(parts[:i]) + "/" for i in range(1, len(parts)))
entries = files + sorted(parents)

for rule_file in sorted(glob.glob(".claude/rules/**/*.md", recursive=True)):
    with open(rule_file, encoding="utf-8", errors="replace") as f:
        written = [piece for item in rule_paths(f.read()) for piece in split_paths(item)]
    globs = dict((piece, [g[:-3] if g.endswith("/**") else g for g in expand_braces(piece)]) for piece in written)
    for piece in written:
        if piece.startswith("!"):
            continue  # a negation narrows the rule's other paths; it targets no file itself
        regexes = [ignore_regex(g) for g in globs[piece] if g]
        if not any(regex and any(regex.search(entry) for entry in entries) for regex in regexes):
            print("Rule '%s' targets path '%s' but no matching files found" % (rule_file, piece))
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
