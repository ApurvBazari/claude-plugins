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
| Testing Philosophy | Write-after |
| Security Sensitivity | Standard |
| Agents | 1 (code-reviewer) |
| Skills | 2 (stack-specific) |
| Hooks | Auto-format only |

```json
{
  "selectedPreset": "minimal",
  "autonomyLevel": "autonomous",
  "codeStyleStrictness": "relaxed",
  "testingPhilosophy": "write-after",
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
| Testing Philosophy | Comprehensive |
| Security Sensitivity | Elevated |
| Agents | 3 (code-reviewer, test-writer, security-checker) |
| Skills | 2-3 (stack + workflow) |
| Hooks | Auto-format + lint check |

```json
{
  "selectedPreset": "standard",
  "autonomyLevel": "balanced",
  "codeStyleStrictness": "moderate",
  "testingPhilosophy": "comprehensive",
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
| Hooks | Auto-format + lint + pre-commit validation |

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

Full wizard flow — all questions are asked. Choose this when no preset fits or when you want fine-grained control over every setting.

---

## How Presets Work

1. Developer is presented with preset options at the start of the wizard (Phase 0)
2. If a preset is chosen, its values are loaded into the wizard answers
3. The wizard still asks Q1.1 (project description) — this is always project-specific
4. The wizard skips directly to the summary phase (Phase 6) for confirmation
5. The developer can tweak any pre-filled value during the summary review
6. If Custom is chosen, the full wizard flow runs as normal

## Preset Values Not Covered

Presets do not set these fields (they come from analysis or are always asked):
- `projectDescription` — Always asked (Q1.1)
- `teamSize` — Inferred from analysis or asked
- `sharedStandards` — Conditional follow-up from team size
- `projectMaturity` — Inferred from analysis or asked
- `primaryTasks` — Developer-specific
- `frontendPatterns` / `backendPatterns` / `devopsPatterns` — Stack-specific, from analysis
- `painPoints` — Developer-specific, cannot be preset
