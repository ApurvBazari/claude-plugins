# Plugin Detection Guide

Canonical source of truth for detecting installed Claude Code plugins and deriving plugin-aware generation data. Used by the generation skill (standalone mode) and referenced by the evolve skill.

## Known Plugin Probe List

For each plugin, probe the filesystem:
```bash
ls "${CLAUDE_PLUGIN_ROOT}/../<plugin-name>" 2>/dev/null
```

A successful probe (exit 0) means the plugin is installed.

| Plugin | Category | Capabilities Covered |
|---|---|---|
| `superpowers` | Universal | `test-generation`, `debugging`, `planning`, `code-review` |
| `commit-commands` | Universal | `git-workflow` |
| `security-guidance` | Universal | `security-audit` |
| `hookify` | Universal | `behavioral-guardrails` |
| `claude-md-management` | Universal | `documentation` |
| `engineering` | Universal | `engineering-lifecycle`, `architecture-decisions`, `deploy-verification` |
| `frontend-design` | Stack-conditional | `ui-development` |
| `feature-dev` | Stack-conditional | `feature-development`, `code-review` |
| `code-review` | Workflow-conditional | `code-review` |
| `pr-review-toolkit` | Workflow-conditional | `code-review`, `code-simplification` |
| `context7` | Stack-conditional | `docs-lookup` |
| `github` | Workflow-conditional | `vcs-integration` |
| `gitlab` | Workflow-conditional | `vcs-integration` |
| `playwright` | Stack-conditional | `e2e-testing` |

## CLAUDE_PLUGIN_ROOT Fallback

If `CLAUDE_PLUGIN_ROOT` is unset or empty (e.g., running outside plugin context), skip all probes and treat as "no plugins detected." Do not fail — proceed with standalone generation.

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
