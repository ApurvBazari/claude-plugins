# Plugin Detection Guide

Canonical source of truth for detecting installed Claude Code plugins and deriving plugin-aware generation data. Used by the generation skill (standalone mode) and referenced by the evolve skill.

## Known Plugin Probe List

Ask Claude Code which plugins are installed. `claude plugin list --json` reports every install source with its real folder: marketplace installs (`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`), plugins added from Anthropic's directory and synced from claude.ai (`~/.claude/plugins/synced/…`), and skills-directory plugins. Each entry carries `"id": "<plugin>@<source>"`, `"enabled"` and `"installPath"`.

Probing the marketplace cache alone misses directory installs, and probing a sibling folder (`${CLAUDE_PLUGIN_ROOT}/../<plugin>`) only works in a development checkout of this repo (release-gate finding B8, 2026-04-17, was the sibling-only version of this miss). Never probe a sibling folder: a directory-submitted plugin may not point outside its own folder.

```bash
# One call for the whole catalog.
INSTALLED_JSON="$(claude plugin list --json 2>/dev/null || echo '[]')"

# For each plugin name in the catalog below:
P="<plugin-name>"
ROOT="$(printf '%s' "$INSTALLED_JSON" \
  | jq -r --arg p "$P" '[.[] | select((.id | startswith($p + "@")) and (.enabled != false))][0].installPath // empty' 2>/dev/null)"

# Fallback only when the CLI or jq can't answer: the marketplace cache.
if [ -z "$ROOT" ]; then
  ROOT="$(ls -d "$HOME/.claude/plugins/cache"/*/"${P}"/*/ 2>/dev/null | head -1)"
  ROOT="${ROOT%/}"
fi

if [ -n "$ROOT" ]; then
  # Plugin is installed and enabled. Add P to installedPlugins and keep ROOT for the surface probe.
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
| `context7` | Stack-conditional | `docs-lookup` | ships in the plugin | plugin | set up by the plugin |
| `github` | Workflow-conditional | `vcs-integration` | ships in the plugin | plugin | set up by the plugin |
| `gitlab` | Workflow-conditional | `vcs-integration` | — | — | — |
| `playwright` | Stack-conditional | `e2e-testing` | — | — | — |
| `vercel` | Stack-conditional | `deploy-verification`, `platform-integration` | `mcp.vercel.com` | http | oauth |
| `prisma` | Stack-conditional | `database-orm` | ships in the plugin | plugin | set up by the plugin |
| `supabase` | Stack-conditional | `backend-as-a-service` | `mcp.supabase.com` | http | oauth |
| `chrome-devtools-mcp` | Stack-conditional | `frontend-debugging`, `browser-automation` | ships in the plugin | plugin | set up by the plugin |

## MCP Auto-Emit Signals

The `MCP Server` column above describes what each plugin maps to. MCP handling is driven by **stack signals**, not just plugin installation. For a server with a catalog URL (`vercel`, `supabase`), onboard writes a remote `https` entry into `.mcp.json` when the stack unambiguously benefits. For a plugin-delivered server (`context7`, `github`, `prisma`, `chrome-devtools-mcp`), the server ships inside the plugin, so onboard writes no `.mcp.json` entry. In both cases the plugin is **offered by name** and installed only if the person accepts (see `../catalogs/mcp-guide.md` § Install accepted plugins). The rule is in `../../../../references/plugin-install-consent.md`.

| Stack signal | MCP server | Delivery | Confidence tier |
|---|---|---|---|
| Any project | `context7` | plugin offer | any-project |
| `.github/workflows/` present | `github` | plugin offer | high |
| `vercel.json` or `@vercel/*` in package.json | `vercel` | `.mcp.json` entry + plugin offer | high |
| `prisma/` dir or `@prisma/client`/`prisma` in deps | `prisma` | plugin offer | high |
| `@supabase/*` in deps or `supabase/` config dir | `supabase` | `.mcp.json` entry + plugin offer | high |
| Frontend framework detected (React, Next.js, Vue, Svelte, Astro, Remix, SolidJS) | `chrome-devtools-mcp` | plugin offer | high |

OAuth steps for the servers onboard writes are documented in the generated `.claude/rules/mcp-setup.md`.

## CLAUDE_PLUGIN_ROOT Fallback

`CLAUDE_PLUGIN_ROOT` being unset or empty means the sibling probe cannot run — but the marketplace-cache probe still should. The `~/.claude/plugins/cache` path is stable across install methods and does NOT depend on `CLAUDE_PLUGIN_ROOT`.

Sequence:

1. Attempt both probe locations for every catalog entry (`CLAUDE_PLUGIN_ROOT` optional for sibling; always available for cache).
2. If NEITHER probe returns any hits for any plugin in the catalog AND `CLAUDE_PLUGIN_ROOT` was unset, fall back to "no plugins detected" with a structured log entry (`detectedPlugins.probeContext: "claude-plugin-root-unset-and-cache-empty"`).
3. Proceed with standalone generation. Do not fail.

## Surface Classification

After building `installedPlugins`, classify each plugin's entry surface (commands / skills / hooks / agents) per `plugin-surface-probe.md`. The resulting `pluginSurfaces` map feeds the Plugin Integration template in `../guides/claude-md-guide.md` and prevents fabricated slash refs (release-gate finding G.3, 2026-04-17 — `/security-guidance:security-review` fabricated for a hooks-only plugin).

## Detection Output Schema

The detection step produces a `detectedPlugins` object:

```jsonc
{
  "detectedPlugins": {
    "installedPlugins": ["superpowers", "commit-commands", ...],
    "coveredCapabilities": ["test-generation", "git-workflow", ...],
    "pluginSurfaces": { /* per plugin-surface-probe.md */ },
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

Start from the defaults, filter by installed plugins. Note: `feature-dev` contributes **only** its `code-architect` sub-agent to the `feature` phase — NOT `feature-dev:feature-dev` as a top-level orchestrator. When `superpowers` is installed, its `brainstorming` + `writing-plans` + `test-driven-development` pipeline owns feature entry; `feature-dev:feature-dev` is effectively dead code in that environment (release-gate finding G.4, 2026-04-17).

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

See `plugin-surface-probe.md § Disambiguation rules` (R1-R6) for the full routing-conflict resolution that applies on top of this derivation when multiple overlapping plugins are installed.
