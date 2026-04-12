# Plugin Integration Rules for Evolve

Distilled rules for regenerating the Plugin Integration section in CLAUDE.md and quality-gate hooks during `/onboard:evolve`. Source of truth: `generation/SKILL.md` lines 82-125 and `tooling-generation/SKILL.md` lines 108-181.

## Known Plugin Probe List

Filesystem probe target for detecting installed plugins. For each plugin, check:
```bash
ls "${CLAUDE_PLUGIN_ROOT}/../<plugin-name>" 2>/dev/null
```

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

Also probe any plugin in `previousPlugins` that isn't in this list (custom/third-party plugins).

## Section Marker Template

The Plugin Integration section in CLAUDE.md is always wrapped in these markers:

```markdown
<!-- onboard:plugin-integration:start -->
## Plugin Integration

This project uses the following Claude Code plugins. Use them consistently.

### Research & brainstorming (MANDATORY first step for any new feature)
...
### Core discipline (applies to all phases after research)
...
### Per-feature workflow
...
### Commit discipline
...
### Quality gates
...
### Ecosystem
...
<!-- onboard:plugin-integration:end -->
```

## Subsection Content Rules

Generate only subsections that have at least one installed plugin. Each subsection answers "when do I use this?" tied to the project's tech stack.

### 1. Research & brainstorming

**When**: `superpowers` is in `installedPlugins` (always first subsection).

- Document `/superpowers:brainstorming` as the hard-gated first step for any new feature
- Reference `/superpowers:dispatching-parallel-agents` for parallel web research
- Reference `context7` only if installed (never fabricate)
- Include "design can be a few sentences for trivial work" caveat
- Point at where research outputs are saved

**Graceful degradation**: When `superpowers` is NOT installed, fall back to a generic version recommending built-in `WebSearch`/`WebFetch` and a manual-discussion protocol. Do NOT reference `/superpowers:brainstorming` — it would be a broken command. Add a note suggesting users install superpowers for the full experience.

### 2. Core discipline

**When**: `superpowers` is in `installedPlugins`.

- `superpowers:test-driven-development`
- `superpowers:verification-before-completion`
- `superpowers:systematic-debugging`

Only include skills whose plugin is installed.

### 3. Per-feature workflow

**When**: `feature-dev` is in `installedPlugins`.

- `feature-dev:code-architect`, `code-explorer`, `code-reviewer`

### 4. Commit discipline

**When**: `commit-commands` is in `installedPlugins`.

- `/commit`, `/commit-push-pr`

### 5. Quality gates

**When**: any of `code-review`, `pr-review-toolkit`, `claude-md-management` is installed.

- `code-review:code-review` (if `code-review` installed)
- `pr-review-toolkit:review-pr` (if `pr-review-toolkit` installed)
- `claude-md-management:revise-claude-md` (if `claude-md-management` installed)

### 6. Ecosystem

**When**: any of `hookify`, `security-guidance` is installed.

- `hookify` — behavioral guardrails
- `security-guidance` — hook-based security warnings

## Tone

Rich narrative voice, not a bulleted list of plugin names. Every subsection should answer "when do I use this?" tied to the project's actual tech stack.

## qualityGates Derivation

Start from the defaults below, then filter out any skill whose plugin is not in `installedPlugins`.

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
3. **featureStart** — preserve existing `criticalDirs` from `forge-meta.json` (evolve does not re-derive directory roles). Seeded only if `superpowers` installed.
4. **postFeature** — drop if `claude-md-management` not installed.
5. **Never fabricate plugin references** — if a plugin is not in `installedPlugins`, drop all references to it.

### autonomyLevel downgrade for preCommit

| `autonomyLevel` | Action on `preCommit[].mode` |
|---|---|
| `always-ask` | Downgrade ALL to `"advisory"` |
| `balanced` | Keep as seeded (`"blocking"`) |
| `autonomous` | Keep as seeded (`"blocking"`) |

Read `autonomyLevel` from `forge-meta.json.context.autonomyLevel` or `onboard-meta.json.wizardAnswers.autonomyLevel`.

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

## coveredCapabilities Derivation

For each installed plugin, look up its capabilities in the probe list table above. Combine into a deduplicated list.
