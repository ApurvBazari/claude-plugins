# Plugin Detection Guide

Canonical source of truth for detecting installed Claude Code plugins and deriving plugin-aware generation data. Used by the generation skill (standalone mode) and referenced by the evolve skill.

## Known Plugin Probe List

A plugin may live in one of two places on disk:

1. **Sibling** to the running plugin — e.g., in a development monorepo like `claude-plugins/` where `onboard/`, `forge/`, `notify/` live side-by-side under one parent. Path: `${CLAUDE_PLUGIN_ROOT}/../<plugin-name>/`.
2. **Marketplace cache** — the standard install location populated by `claude plugin install`. Path: `~/.claude/plugins/cache/<marketplace>/<plugin-name>/<version>/` where `<marketplace>` is typically `claude-plugins-official` and `<version>` is often the literal string `unknown` (not a semver).

Probing only siblings misses marketplace-installed plugins entirely (release-gate finding B8, 2026-04-17 — Standard + Minimal presets detected 2 plugins when 14+ were actually installed). Probe **both** locations:

```bash
# For each plugin name in the catalog below:
P="<plugin-name>"
FOUND=0

# (1) Sibling location (dev repo monorepo layout)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "${CLAUDE_PLUGIN_ROOT}/../${P}" ]; then
  FOUND=1
fi

# (2) Marketplace cache (standard install)
# Use globbing via [ -d <path>/*/<p> ] — the <marketplace> and <version>
# dir names vary by install, so don't hardcode them.
if [ $FOUND -eq 0 ] && ls -d "$HOME/.claude/plugins/cache"/*/"${P}"/ >/dev/null 2>&1; then
  FOUND=1
fi

# Also accept a versioned cache dir: ~/.claude/plugins/cache/<mkt>/<p>/<ver>/
if [ $FOUND -eq 0 ] && ls -d "$HOME/.claude/plugins/cache"/*/"${P}"/*/ >/dev/null 2>&1; then
  FOUND=1
fi

if [ $FOUND -eq 1 ]; then
  # Plugin is installed. Add to installedPlugins.
  :
fi
```

**Do not `exit 1`-gate the loop** — a missing plugin is the expected case for most entries. Only add found plugins to `installedPlugins`. Continue through the full catalog regardless of individual probe results.

| Plugin | Category | Capabilities Covered | MCP Server | Transport | Auth |
|---|---|---|---|---|---|
| `superpowers` | Universal | `test-generation`, `debugging`, `planning`, `code-review` | — | — | — |
| `commit-commands` | Universal | `git-workflow` | — | — | — |
| `security-guidance` | Universal | `security-audit` | — | — | — |
| `hookify` | Universal | `behavioral-guardrails` | — | — | — |
| `claude-md-management` | Universal | `documentation` | — | — | — |
| `frontend-design` | Stack-conditional | `ui-development` | — | — | — |
| `feature-dev` | Stack-conditional | `feature-development`, `code-review` | — | — | — |
| `code-review` | Workflow-conditional | `code-review` | — | — | — |
| `pr-review-toolkit` | Workflow-conditional | `code-review`, `code-simplification` | — | — | — |
| `context7` | Stack-conditional | `docs-lookup` | `@upstash/context7-mcp` | stdio | none |
| `github` | Workflow-conditional | `vcs-integration` | `api.githubcopilot.com` | http | token |
| `gitlab` | Workflow-conditional | `vcs-integration` | — | — | — |
| `playwright` | Stack-conditional | `e2e-testing` | — | — | — |
| `vercel` | Stack-conditional | `deploy-verification`, `platform-integration` | `mcp.vercel.com` | http | oauth |
| `prisma` | Stack-conditional | `database-orm` | `prisma` | stdio + http | none |
| `supabase` | Stack-conditional | `backend-as-a-service` | `mcp.supabase.com` | http | oauth |
| `chrome-devtools-mcp` | Stack-conditional | `frontend-debugging`, `browser-automation` | `chrome-devtools-mcp` | stdio | none |

## MCP Auto-Emit Signals

The `MCP Server` column above describes what each plugin maps to. `.mcp.json` emission is driven by **stack signals**, not just plugin installation — we emit when the project's detected stack unambiguously benefits, whether or not the user has installed the corresponding plugin. When we emit and the plugin is not installed, we auto-install it (see `mcp-guide.md`).

| Stack signal | Emits MCP server | Confidence tier |
|---|---|---|
| Any project | `context7` | always |
| `.github/workflows/` present | `github` | high |
| `vercel.json` or `@vercel/*` in package.json | `vercel` | high |
| `prisma/` dir or `@prisma/client`/`prisma` in deps | `prisma` | high |
| `@supabase/*` in deps or `supabase/` config dir | `supabase` | high |
| Frontend framework detected (React, Next.js, Vue, Svelte, Astro, Remix, SolidJS) | `chrome-devtools-mcp` | high |

Env-var requirements and OAuth steps are documented in the generated `.claude/rules/mcp-setup.md`.

## CLAUDE_PLUGIN_ROOT Fallback

`CLAUDE_PLUGIN_ROOT` being unset or empty means the sibling probe cannot run — but the marketplace-cache probe still should. The `~/.claude/plugins/cache` path is stable across install methods and does NOT depend on `CLAUDE_PLUGIN_ROOT`.

Sequence:

1. Attempt both probe locations for every catalog entry (`CLAUDE_PLUGIN_ROOT` optional for sibling; always available for cache).
2. If NEITHER probe returns any hits for any plugin in the catalog AND `CLAUDE_PLUGIN_ROOT` was unset, fall back to "no plugins detected" with a structured log entry (`detectedPlugins.probeContext: "claude-plugin-root-unset-and-cache-empty"`).
3. Proceed with standalone generation. Do not fail.

## Detection Output Schema

The detection step produces a `detectedPlugins` object:

```jsonc
{
  "detectedPlugins": {
    "installedPlugins": ["superpowers", "commit-commands", ...],
    "coveredCapabilities": ["test-generation", "git-workflow", ...],
    "qualityGates": { /* derived from installed plugins + autonomyLevel */ },
    "phaseSkills": { /* derived from installed plugins */ }
  }
}
```

## coveredCapabilities Derivation

For each installed plugin, look up its capabilities in the probe list table above. Combine into a deduplicated list.

**Example**: If `installedPlugins = ["superpowers", "code-review", "feature-dev"]`:
- superpowers → test-generation, debugging, planning, code-review
- code-review → code-review
- feature-dev → feature-development, code-review

Result: `["test-generation", "debugging", "planning", "code-review", "feature-development"]` (deduplicated)

## qualityGates Derivation

Start from the defaults below, then filter out any skill whose plugin is NOT in `installedPlugins`.

```jsonc
{
  "sessionStart": [
    {
      "type": "reminder",
      "message": "Starting new feature work? Begin with /superpowers:brainstorming.",
      "condition": "superpowers-installed"
    }
  ],
  "preCommit": [
    { "skill": "code-review:code-review", "triggerOn": "commit", "mode": "blocking" },
    { "skill": "superpowers:verification-before-completion", "triggerOn": "commit", "mode": "blocking" }
  ],
  "featureStart": [
    {
      "type": "reminder",
      "criticalDirs": [],
      "message": "New file in {dir}. Consider /superpowers:brainstorming first."
    }
  ],
  "postFeature": [
    { "skill": "claude-md-management:revise-claude-md", "triggerOn": "session-end", "mode": "advisory" }
  ]
}
```

### Derivation rules

1. **sessionStart** — seeded only if `superpowers` is in `installedPlugins`.
2. **preCommit** — drop entries whose plugin is not installed. Apply autonomyLevel downgrade (see below).
3. **featureStart** — seeded only if `superpowers` is installed. Derive `criticalDirs` from the analysis report's identified architectural boundaries (top-level source directories).
4. **postFeature** — drop if `claude-md-management` not installed.
5. **Never fabricate plugin references** — if a plugin is not in `installedPlugins`, drop all references to it.

### autonomyLevel downgrade for preCommit

| `autonomyLevel` | Action on `preCommit[].mode` |
|---|---|
| `always-ask` | Downgrade ALL to `"advisory"` |
| `balanced` | Keep as seeded (`"blocking"`) |
| `autonomous` | Keep as seeded (`"blocking"`) |

Read `autonomyLevel` from `wizardAnswers.autonomyLevel`.

## phaseSkills Derivation

Start from the defaults, filter by installed plugins:

```jsonc
{
  "research":   ["superpowers:brainstorming", "superpowers:dispatching-parallel-agents", "context7"],
  "planning":   ["superpowers:writing-plans"],
  "feature":    ["feature-dev:code-architect", "superpowers:test-driven-development"],
  "review":     ["code-review:code-review", "pr-review-toolkit:review-pr"],
  "commit":     ["commit-commands:commit"],
  "post-phase": ["claude-md-management:revise-claude-md"]
}
```

Drop any skill whose plugin is not in `installedPlugins`. Remove empty phases entirely.
