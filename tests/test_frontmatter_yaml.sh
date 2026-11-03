#!/usr/bin/env bash
# test_frontmatter_yaml.sh — every shipped skill and agent frontmatter block parses as YAML.
#
# Usage: tests/test_frontmatter_yaml.sh
#
# Claude Code loads a frontmatter block that a YAML parser rejects, and so does
# `claude plugin validate --strict`. Anthropic's plugin directory does not: it held lens 1.5.3 with
# "Couldn't confirm what the plugin runs or connects to" (REACH_UNKNOWN), because three descriptions
# carried a bare ': ' that YAML reads as a second key. The fix for that case is to wrap the
# description in double quotes, as onboard's internal skills do.
#
# Scope: for every plugin in .claude-plugin/marketplace.json, the tracked SKILL.md files under
# skills/ and the .md files under agents/, commands/ and output-styles/. These are the files Claude
# Code reads frontmatter from. Reference docs are left out: nothing reads their frontmatter, and a
# leading '---' there can be a horizontal rule. A file that doesn't open with '---' has no
# frontmatter and is skipped.
#
# Parser: python3 with PyYAML (CI's belts job installs it), else Ruby's bundled Psych. Set
# FRONTMATTER_YAML_PARSER=python or =ruby to force one. With neither available the belt fails, never
# skips. Before scanning, it proves the parser rejects the bare ': ' and accepts the quoted form.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*"; exit 1; }

cat > "$TMP/parse.py" <<'PY'
import sys
import yaml

bad = 0
for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as f:
        lines = f.read().replace("\r\n", "\n").split("\n")
    if lines[0].strip() != "---":
        continue
    close = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
    if close is None:
        print(f"FAIL: {path}: frontmatter opens with --- but never closes")
        bad += 1
        continue
    try:
        data = yaml.safe_load("\n".join(lines[1:close]))
    except yaml.YAMLError as e:
        mark = getattr(e, "problem_mark", None)
        where = f":{mark.line + 2}" if mark else ""
        problem = getattr(e, "problem", None) or str(e).splitlines()[0]
        print(f"FAIL: {path}{where}: {problem}")
        bad += 1
        continue
    if not isinstance(data, dict):
        print(f"FAIL: {path}: frontmatter is a {type(data).__name__}, not a mapping of keys")
        bad += 1
sys.exit(1 if bad else 0)
PY

cat > "$TMP/parse.rb" <<'RB'
require "yaml"

bad = 0
ARGV.each do |path|
  lines = File.read(path, encoding: "UTF-8").gsub("\r\n", "\n").split("\n", -1)
  next if lines.empty? || lines[0].strip != "---"
  close = (1...lines.length).find { |i| lines[i].strip == "---" }
  if close.nil?
    puts "FAIL: #{path}: frontmatter opens with --- but never closes"
    bad += 1
    next
  end
  begin
    data = YAML.safe_load(lines[1...close].join("\n"))
  rescue Psych::SyntaxError => e
    puts "FAIL: #{path}:#{e.line + 1}: #{e.problem}"
    bad += 1
    next
  rescue StandardError => e
    puts "FAIL: #{path}: #{e.class}: #{e.message.lines.first&.strip}"
    bad += 1
    next
  end
  unless data.is_a?(Hash)
    puts "FAIL: #{path}: frontmatter is a #{data.class}, not a mapping of keys"
    bad += 1
  end
end
exit(bad.zero? ? 0 : 1)
RB

have_pyyaml() { python3 -c 'import yaml' 2>/dev/null; }
have_psych() { command -v ruby >/dev/null 2>&1 && ruby -ryaml -e '' 2>/dev/null; }

case "${FRONTMATTER_YAML_PARSER:-auto}" in
  python) have_pyyaml || fail "FRONTMATTER_YAML_PARSER=python, but python3 can't import yaml (pip install pyyaml)"
          PARSER=(python3 "$TMP/parse.py"); PARSER_NAME="python3 + PyYAML" ;;
  ruby)   have_psych || fail "FRONTMATTER_YAML_PARSER=ruby, but ruby with its yaml library isn't available"
          PARSER=(ruby "$TMP/parse.rb"); PARSER_NAME="ruby + Psych" ;;
  auto)   if have_pyyaml; then PARSER=(python3 "$TMP/parse.py"); PARSER_NAME="python3 + PyYAML"
          elif have_psych; then PARSER=(ruby "$TMP/parse.rb"); PARSER_NAME="ruby + Psych"
          else fail "no YAML parser on this machine: install PyYAML (pip install pyyaml) or Ruby"
          fi ;;
  *)      fail "FRONTMATTER_YAML_PARSER must be python, ruby or unset; got '${FRONTMATTER_YAML_PARSER}'" ;;
esac

# The parser must reject the exact shape that held lens 1.5.3, and accept its quoted fix.
printf -- '---\nname: probe\ndescription: Checks the diff against its plan: each step followed or not.\n---\n' > "$TMP/bare.md"
printf -- '---\nname: probe\ndescription: "Checks the diff against its plan: each step followed or not."\n---\n' > "$TMP/quoted.md"
if "${PARSER[@]}" "$TMP/bare.md" >/dev/null; then
  fail "$PARSER_NAME accepted a description with a bare ': ', so this belt could not catch one"
fi
"${PARSER[@]}" "$TMP/quoted.md" >/dev/null || fail "$PARSER_NAME rejected a double-quoted description"

files=()
nplugins=0
while IFS= read -r plugin; do
  [ -n "$plugin" ] || continue
  nplugins=$((nplugins + 1))
  found=0
  while IFS= read -r f; do
    files+=("$f")
    found=$((found + 1))
  done < <(git -C "$ROOT" ls-files -- "$plugin" \
             | grep -E "^${plugin}/(skills/.+/SKILL|agents/.+|commands/[^/]+|output-styles/[^/]+)\.md$" || true)
  [ "$found" -gt 0 ] || fail "found no skill or agent files under $plugin/ — check the path filter"
done < <(python3 -c '
import json, sys
for p in json.load(open(sys.argv[1]))["plugins"]:
    s = p.get("source")
    if not isinstance(s, str) or not s.startswith("./"):
        sys.exit("marketplace entry %r has no ./ source this belt can scan" % p.get("name"))
    print(s[2:].rstrip("/"))
' "$ROOT/.claude-plugin/marketplace.json")

[ "$nplugins" -gt 0 ] || fail "read no plugins from .claude-plugin/marketplace.json"

if ! (cd "$ROOT" && "${PARSER[@]}" "${files[@]}"); then
  echo "FAIL: frontmatter above doesn't parse as YAML ($PARSER_NAME). A plain value can't hold ': '; wrap it in double quotes."
  exit 1
fi
echo "PASS: ${#files[@]} skill and agent files across $nplugins plugins have frontmatter that parses as YAML ($PARSER_NAME)"
