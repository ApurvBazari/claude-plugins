# Validation Check Details

## Structure Check Commands

```bash
# Check plugin.json exists
test -f "<plugin>/.claude-plugin/plugin.json"

# Check README exists
test -f "<plugin>/README.md"

# Check at least one component dir exists
test -d "<plugin>/skills" || test -d "<plugin>/commands" || test -d "<plugin>/agents"
```

## Manifest Validation with jq

```bash
# Validate required fields in plugin.json
jq -e '.name and .version and .description and .author.name and .license and .keywords' \
  "<plugin>/.claude-plugin/plugin.json"

# Check name matches directory
PLUGIN_DIR="$(basename "<plugin>")"
MANIFEST_NAME="$(jq -r '.name' "<plugin>/.claude-plugin/plugin.json")"
[ "$PLUGIN_DIR" = "$MANIFEST_NAME" ]
```

## Version Sync Check

```bash
# Compare plugin.json version with marketplace.json entry
PLUGIN_VERSION="$(jq -r '.version' "<plugin>/.claude-plugin/plugin.json")"
MARKETPLACE_VERSION="$(jq -r --arg name "$PLUGIN_NAME" '.plugins[] | select(.name == $name) | .version' .claude-plugin/marketplace.json)"
[ "$PLUGIN_VERSION" = "$MARKETPLACE_VERSION" ]
```

## Reference Integrity

```bash
# Find all reference directories in skills
find "<plugin>/skills" -name "references" -type d | while read ref_dir; do
  # Check each .md file exists and is non-empty
  find "$ref_dir" -name "*.md" -type f | while read ref_file; do
    test -s "$ref_file" || echo "Empty reference: $ref_file"
  done
done
```

## ShellCheck

```bash
# Run on all .sh files
find . -name "*.sh" -type f -exec shellcheck {} \;

# Check if installed
command -v shellcheck &>/dev/null || echo "WARN: ShellCheck not installed"
```

## SKILL.md Section Checks

```bash
# Check H1 starts with /
grep -q '^# /' "<skill>/SKILL.md"

# Check for Key Rules section
grep -q '## Key Rules' "<skill>/SKILL.md"
```
