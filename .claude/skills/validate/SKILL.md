---
description: Validate all plugins for structure, manifests, references, shell scripts, and markdown conventions
user_invocable: true
---

# /validate — Plugin Validation

Run all quality checks across every plugin in the marketplace. Reports PASS/WARN/FAIL per category.

## Step 1: Identify Plugins

Read `.claude-plugin/marketplace.json` to get the list of registered plugins. For each plugin, extract the `source` path.

## Step 2: Structure Check

For each plugin directory, verify:
- `.claude-plugin/plugin.json` exists
- `README.md` exists
- At least one of `skills/`, `commands/`, `agents/` exists

Report missing items as **FAIL**.

## Step 3: Manifest Validation

For each `plugin.json`, verify:
- Valid JSON syntax
- Required fields present: `name`, `version`, `description`, `author`, `license`, `keywords`
- `name` matches the plugin directory name

Report missing/invalid fields as **FAIL**.

## Step 4: Version Sync

Compare each plugin's `plugin.json` version with its `marketplace.json` entry:
- Versions must match exactly
- Both must be valid semver

Report mismatches as **FAIL**.

## Step 5: Reference Integrity

For each `skills/*/SKILL.md`, check if the skill directory has a `references/` subdirectory. If it does, verify every `.md` file in it exists and is non-empty.

For each `agents/*.md`, check for any script references (paths to `.sh` files). Verify those scripts exist.

Report broken references as **FAIL**.

## Step 6: ShellCheck

Run `shellcheck` on all `.sh` files across all plugins and `.claude/hooks/`.

If `shellcheck` is not installed:
- Report as **WARN**: "ShellCheck not installed — skipping script validation. Install with: brew install shellcheck"
- Do NOT report as FAIL

If installed, report any ShellCheck errors as **WARN** (not FAIL — scripts may have intentional suppressions).

## Step 7: SKILL.md Section Check

For each `SKILL.md`, verify:
- H1 title exists and starts with `/`
- Has a `## Key Rules` section (or similar closing constraints section)

Report missing sections as **WARN**.

## Step 8: Report

Present a summary table:

```
Plugin Validation Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Category              Status
  ─────────────────────────────
  Structure             PASS | FAIL (details)
  Manifests             PASS | FAIL (details)
  Version Sync          PASS | FAIL (details)
  Reference Integrity   PASS | FAIL (details)
  ShellCheck            PASS | WARN | SKIP
  SKILL.md Sections     PASS | WARN (details)

  Overall: PASS | FAIL
```

If any category is FAIL, overall is FAIL. If only WARNs, overall is PASS with warnings.

## Key Rules

- Run all checks — don't stop at the first failure
- Distinguish FAIL (structural violation) from WARN (advisory)
- ShellCheck not installed is a WARN, not a FAIL
- Report per-plugin details for any failures, not just aggregate counts
- A partially-created plugin (in progress) should get WARN for missing structure, not FAIL
