# Workflow Profiles

Three pre-configured profiles for common development setups. The profile is chosen in `/onboard:start` Step 1.4 — it does **two** things:

1. **Bounds research depth** — how deep the research engine reads before the wizard runs (recon-only → core-4 → all-7).
2. **Pre-fills the generation scope** — sensible autonomy / strictness / agent-count / hook defaults the wizard then presents as overridable.

The profile no longer changes how *much* the wizard asks: the grounded confirm/override wizard runs ~2–3 exchanges for **all** profiles. The developer still provides their project description (always project-specific) and confirms the summary before generation. There are exactly three profiles — fine-grained control happens by overriding any pre-filled value inside the grounded wizard, not by selecting a free-form profile.

---

## Profile Definitions

Each profile maps to a **research depth** (consumed by `/onboard:start` Step 1.5 / the research engine — see `../../research/references/depth-profiles.md`) plus a **generation-scope pre-fill** (the autonomy / strictness / agent / hook defaults the wizard seeds as recommended, overridable options).

### Minimal

Best for: Solo developers, side projects, prototypes, or developers who prefer Claude to stay out of the way.

**Research depth:** `minimal` — recon-only research (no specialists dispatched; produces a valid dossier with an empty roster).

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
  "researchDepth": "minimal",
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

**Research depth:** `standard` — core-4 specialists (`architecture`, `data-model`, `testing`, `security`) + a single adversarial verify pass.

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
  "researchDepth": "standard",
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

**Research depth:** `comprehensive` — all 7 specialists (`architecture`, `data-model`, `testing`, `security`, `conventions`, `domain`, `dependencies`) + any enabled custom specialists + a single adversarial verify pass.

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
  "researchDepth": "comprehensive",
  "autonomyLevel": "always-ask",
  "codeStyleStrictness": "strict",
  "testingPhilosophy": "tdd",
  "securitySensitivity": "high",
  "codeReviewProcess": "formal-pr",
  "branchingStrategy": "gitflow",
  "deployFrequency": "continuous"
}
```

---

## Profile → research depth at a glance

| Profile | Research depth | What research does |
|---|---|---|
| Minimal | `minimal` | Recon only — no specialists, empty roster, valid dossier. |
| Standard | `standard` | Core-4 specialists + single adversarial verify pass. |
| Comprehensive | `comprehensive` | All 7 specialists + customs + single adversarial verify pass. |

The depth profile is the primary cost dial on large repos. See `../../research/references/depth-profiles.md` for how depth caps the specialist roster and per-specialist scope.

---

## Exchange target (uniform across profiles)

The grounded confirm/override wizard runs **~2–3 `AskUserQuestion` exchanges for every profile**. There is no hard exchange cap and the profile does **not** change exchange count — it only sets research depth + the generation-scope pre-fills the wizard presents as overridable. (The old per-preset exchange-count table and the fourth free-form profile are gone: the inference-driven fast path and the step-by-step interrogation both converged into this single grounded surface.)

**Default model** (used when the wizard's model question is skipped):

| Profile | Default model |
|---|---|
| Minimal | `claude-opus-4-7[1m]` (Opus 4.7 1M context) |
| Standard | `claude-opus-4-7[1m]` (Opus 4.7 1M context) |
| Comprehensive | `claude-opus-4-7[1m]` (Opus 4.7 1M context) |

The high-tier default reflects: Claude tooling generation is a one-time-per-project investment; the model strength makes a measurable difference in the quality of the artifacts produced. Users can downgrade per-project by editing `.claude/settings.json` after start.

---

## How Profiles Work

1. The developer picks a profile (Minimal / Standard / Comprehensive) in `/onboard:start` Step 1.4 — before research runs.
2. The profile's `researchDepth` bounds the research engine in Step 1.5 (Step 1.5 wiring lands in a later task).
3. The profile's generation-scope values are loaded as the **recommended (overridable) defaults** for the grounded wizard.
4. The grounded wizard confirms or overrides those values (~2–3 exchanges) — the developer still provides Q1.1 (project description, always project-specific).
5. The developer can tweak any pre-filled value during the wizard or at the summary review before generation.

## Profile Values Not Covered

Profiles do not set these fields (they come from analysis/research or are always asked):
- `projectDescription` — Always asked (Q1.1)
- `teamSize` — Inferred from analysis/research or confirmed
- `sharedStandards` — Conditional follow-up from team size
- `projectMaturity` — Inferred from analysis/research or confirmed
- `primaryTasks` — Developer-specific
- `frontendPatterns` / `backendPatterns` / `devopsPatterns` — Stack-specific, from analysis/research
- `painPoints` — Developer-specific, cannot be preset
