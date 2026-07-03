---
paths:
  - "**/*.sh"
---

# Shell Script Conventions

## Header

Every script must start with:

```bash
#!/usr/bin/env bash
```

## Error Handling

Two categories with different conventions:

**Utility scripts** (analysis, detection, installation):
- Use `set -euo pipefail` — fail fast on errors
- Exit non-zero on failure — callers handle the error

**Hook scripts** (called by Claude Code hooks):
- Do NOT use `set -e` — handle errors inline
- MUST always `exit 0` — never block Claude execution
- Failures should be logged/warned but not fatal

## ShellCheck

All scripts must pass ShellCheck without errors. Common rules:
- Quote all variable expansions: `"$VAR"` not `$VAR`
- Use `command -v` to check tool availability, not `which`
- Use `[[ ]]` for conditionals, not `[ ]`
- Avoid `eval` — use arrays for dynamic commands

## POSIX Compatibility

Scripts must work on both macOS (BSD) and Linux (GNU):
- `awk`: avoid GNU-only features — stick to POSIX awk
- `sed`: use `sed ''` patterns that work on both BSD and GNU
- `find`: avoid `-printf` (GNU-only) — use `-exec` or pipe to other tools
- `grep`: use `-E` for extended regex, not `\+` (BSD incompatible)

## Structured Output

For scripts that produce output consumed by agents:
- Use `## Section Name` headers for parseable sections
- Use consistent key-value formats within sections
- Include a usage comment at the top: `# Usage: script.sh <args>`

## JSON Parsing Pattern

When parsing JSON from stdin (common in hooks):

```bash
# Preferred (requires jq)
value=$(cat - | jq -r '.key')

# Fallback (no dependency)
value=$(cat - | grep -o '"key": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
```

Use jq-with-fallback for hook scripts to avoid hard dependencies.
