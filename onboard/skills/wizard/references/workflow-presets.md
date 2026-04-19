# Workflow Presets

Pre-configured profiles for common development setups. Presets provide sensible defaults so developers can skip the full wizard flow. The developer still provides their project description (always project-specific) and confirms the summary before generation.

---

## Preset Definitions

### Minimal

Best for: Solo developers, side projects, prototypes, or developers who prefer Claude to stay out of the way.

| Setting | Value |
|---------|-------|
| Autonomy | Autonomous |
| Code Style Strictness | Relaxed |
| Testing Philosophy | TDD |
| Security Sensitivity | Standard |
| Agents | 1 (code-reviewer) |
| Skills | 2 (stack-specific) |
| Hooks | Auto-format only (no quality-gate hooks) |

```json
{
  "selectedPreset": "minimal",
  "autonomyLevel": "autonomous",
  "codeStyleStrictness": "relaxed",
  "testingPhilosophy": "tdd",
  "securitySensitivity": "standard",
  "codeReviewProcess": "informal",
  "branchingStrategy": "feature-branches",
  "deployFrequency": "manual"
}
```

### Standard

Best for: Small teams, active projects with established workflows, balanced oversight.

| Setting | Value |
|---------|-------|
| Autonomy | Balanced |
| Code Style Strictness | Moderate |
| Testing Philosophy | TDD |
| Security Sensitivity | Elevated |
| Agents | 3 (code-reviewer, test-writer, security-checker) |
| Skills | 2-3 (stack + workflow) |
| Hooks | Auto-format + lint + SessionStart reminder |

```json
{
  "selectedPreset": "standard",
  "autonomyLevel": "balanced",
  "codeStyleStrictness": "moderate",
  "testingPhilosophy": "tdd",
  "securitySensitivity": "elevated",
  "codeReviewProcess": "formal-pr",
  "branchingStrategy": "feature-branches",
  "deployFrequency": "daily"
}
```

### Comprehensive

Best for: Larger teams, enterprise projects, regulated environments, or developers who want maximum guardrails.

| Setting | Value |
|---------|-------|
| Autonomy | Always-ask |
| Code Style Strictness | Strict |
| Testing Philosophy | TDD |
| Security Sensitivity | High |
| Agents | 4 (code-reviewer, test-writer, security-checker, docs-writer) |
| Skills | 3 (stack + workflow + domain) |
| Hooks | Auto-format + lint + all quality-gate hooks (SessionStart, preCommit, featureStart, postFeature) |

```json
{
  "selectedPreset": "comprehensive",
  "autonomyLevel": "always-ask",
  "codeStyleStrictness": "strict",
  "testingPhilosophy": "tdd",
  "securitySensitivity": "high",
  "codeReviewProcess": "formal-pr",
  "branchingStrategy": "gitflow",
  "deployFrequency": "continuous"
}
```

### Custom

Full wizard flow — every question whose entry condition has signal is asked. Choose this when no preset fits or when you want fine-grained control over every setting. Custom mode also exposes a mid-wizard escape hatch (Phase 5.0 in `wizard/SKILL.md`) so developers can opt into Quick Mode defaults at any point in Phase 5 without restarting.

---

## Per-preset exchange targets (no hard cap)

There is **no hard 6-exchange cap**. Each preset has a target based on what it actually needs to ask:

| Preset | Exchange target | Notes |
|---|---|---|
| Minimal | 2 | Preset selection + project description. Everything else pre-filled per the table above. |
| Standard | 3 | Preset + description + autonomy confirmation. |
| Comprehensive | 4 | Preset + description + autonomy + advanced hook events confirmation. |
| Custom | N (typically 5–8) | Phase 0 + 1 + 2 + 4 + 5 (with multi-block AskUserQuestion folding LSP+built-ins together) + 5.1 (advanced events) + 6 (summary). Phases with no signal (Phase 3 tech-stack-specific, Phase 5.6 LSP when no candidates) are skipped automatically. The escape hatch (Phase 5.0) lets the developer opt out of remaining customizations. |

**Default models per preset** (used when wizard's Phase 5.2 model question is skipped — i.e., for non-Custom presets):

| Preset | Default model |
|---|---|
| Minimal | `claude-opus-4-7[1m]` (Opus 4.7 1M context) |
| Standard | `claude-opus-4-7[1m]` (Opus 4.7 1M context) |
| Comprehensive | `claude-opus-4-7[1m]` (Opus 4.7 1M context) |
| Custom | Asked explicitly in Phase 5.2; defaults to `claude-opus-4-7[1m]` if skipped |

The high-tier default reflects: Claude tooling generation is a one-time-per-project investment; the model strength makes a measurable difference in the quality of the artifacts produced. Users can downgrade per-project by editing `.claude/settings.json` after init.

---

## How Presets Work

1. Developer is presented with preset options at the start of the wizard (Phase 0)
2. If a preset is chosen, its values are loaded into the wizard answers
3. The wizard still asks Q1.1 (project description) — this is always project-specific
4. The wizard skips directly to the summary phase (Phase 6) for confirmation
5. The developer can tweak any pre-filled value during the summary review
6. If Custom is chosen, the full wizard flow runs as normal — adaptive, no cap, escape hatch available at Phase 5.0

## Preset Values Not Covered

Presets do not set these fields (they come from analysis or are always asked):
- `projectDescription` — Always asked (Q1.1)
- `teamSize` — Inferred from analysis or asked
- `sharedStandards` — Conditional follow-up from team size
- `projectMaturity` — Inferred from analysis or asked
- `primaryTasks` — Developer-specific
- `frontendPatterns` / `backendPatterns` / `devopsPatterns` — Stack-specific, from analysis
- `painPoints` — Developer-specific, cannot be preset
