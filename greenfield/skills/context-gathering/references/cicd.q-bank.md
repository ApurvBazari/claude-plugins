# CI/CD & Delivery Q-bank — Step 11

> **Round:** 4 (migrated from R3 consolidated `question-bank.md`)
> **Step:** 11 (CI/CD & Delivery; the longest established phase, originally Round 1 / Q5.1–Q5.17)
> **Modes:** Heavy 17 Qs (CICD.Q1–Q17 + Q_RISK) / Light ~10 Qs (foundational + Q_RISK; depth Qs use defaults)
> **Coupling:** No auto-loop — CI/CD is pipeline-level, not persona/entity-scoped.
> **Source:** Q content migrated from `question-bank.md` § "Category 5: CI/CD & Auto-Evolution" (lines 1420–1620); R4 added Q_RISK + showInLight + format conversion. Q-IDs renumbered from `Q5.N` → `CICD.QN` for per-phase naming consistency.
> **See also:** `runtime-operations.q-bank.md`, `architectural-framing.q-bank.md`, `inline-risk.q-bank.md`, design spec § Distributed Risk.

This phase covers CI/CD pipeline decisions: drift detection action, auto-evolution mode, CI provider, release strategy, environment ladder, deploy targets, branching strategy, test gates, PR template, rollback strategy, secret management, canary/blue-green, dep-update bots, and pipeline observability. Synthesis review fires inline after CICD.Q_RISK.

## Q-bank

### CICD.Q1 — Drift detection action

- **type:** single-select
- **options:** ["Create a PR with fixes", "Comment on the commit", "Create a GitHub issue"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`; default to `"Create a PR with fixes"` without asking**
- **R3-updates-path:** `context.phases.cicdAndDelivery.ciAuditAction`

**Prompt:** "When tooling drift is detected, what should the CI pipeline do?"

**Stores to:** `cicdAndDelivery.ciAuditAction`

**Default:**
- Else → `"Create a PR with fixes"` (always — greenfield opinion: automated PRs are actionable; comments and issues require follow-up effort that often gets deferred)

### CICD.Q2 — Auto-evolution mode

- **type:** single-select
- **options:** ["Auto-update in real-time", "Log changes, I'll run /greenfield:evolve", "Just notify me"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always (even local projects have local hooks)
- **R3-updates-path:** `context.phases.cicdAndDelivery.autoEvolutionMode`

**Prompt:** "Should AI tooling update automatically when code changes?"

**Stores to:** `cicdAndDelivery.autoEvolutionMode`

**Default:**
- If `hasTeam: false` → `"Log changes, I'll run /greenfield:evolve"` (greenfield opinion: solo developers prefer explicit control over what gets committed)
- If `hasTeam: true` AND `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `"Just notify me"` (greenfield opinion: team projects need human review before tooling changes are applied)
- Else → `"Log changes, I'll run /greenfield:evolve"` (greenfield opinion: logged changes give the developer a diff to review before applying; auto-update can surprise)

### CICD.Q3 — AI PR review trigger

- **type:** single-select
- **options:** ["Auto-review every PR", "Only when I comment @claude", "Auto with skip label"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `willDeploy: true AND hasTeam: true` — **SKIP if `willDeploy: false` OR `hasTeam: false`; default to `"Only when I comment @claude"` without asking**
- **R3-updates-path:** `context.phases.cicdAndDelivery.prReviewTrigger`

**Prompt:** "Should PRs get AI review automatically?"

**Stores to:** `cicdAndDelivery.prReviewTrigger`

**Default:**
- If `architecturalFraming.scaleTarget: "enterprise"` → `"Auto-review every PR"` (greenfield opinion: enterprise teams benefit from consistent automated review)
- Else → `"Only when I comment @claude"` (greenfield opinion: auto-review every PR can create noise; opt-in keeps signal high)

### CICD.Q4 — CI provider

- **type:** single-select
- **options:** ["GitHub Actions", "GitLab CI", "CircleCI", "BuildKite", "Jenkins", "None"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`; default to `"GitHub Actions"` without asking**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.provider`

**Prompt:** "Which CI provider will you use?"

**Stores to:** `cicdAndDelivery.cicd.provider`

**Note:** Round 1 only emits GitHub Actions workflow templates. Non-GHA values are captured but produce a note in synthesis review; non-GHA template support lands in Round 6.

**Default:**
- Else → `"GitHub Actions"` (always — greenfield opinion: GitHub Actions is the de facto standard for new projects; zero-overhead integration with GitHub repos, generous free tier)

### CICD.Q5 — CI trigger events

- **type:** multi-select
- **options:** ["Push to main", "Every PR", "Scheduled", "Manual dispatch", "On tag"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.triggers`

**Prompt:** "When should CI run?"

**Stores to:** `cicdAndDelivery.cicd.triggers[]`

**Default:**
- If `architecturalFraming.scaleTarget: "hobby"` → `["Push to main"]` (greenfield opinion: hobby projects don't need PR-level CI; push-to-main is enough)
- If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `["Every PR", "Push to main", "Scheduled"]` (greenfield opinion: scheduled runs catch dependency-injection or external API failures that only appear after time passes)
- Else → `["Every PR", "Push to main"]` (greenfield opinion: these two triggers catch the most issues for the least noise)

### CICD.Q6 — Required pre-merge checks

- **type:** multi-select
- **options:** ["Lint", "Typecheck", "Unit tests", "Integration tests", "E2E tests", "Security scan", "Coverage", "Build"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.requiredPreMergeChecks`

**Prompt:** "Which checks must pass before a PR can merge?"

**Stores to:** `cicdAndDelivery.cicd.requiredPreMergeChecks[]`

**Recommend:** Default selection adapts to stack — Node/TS projects get lint+typecheck+unit+build; Python adds ruff in place of lint+typecheck.

**Default:**
- If `stack.stack.language: "typescript"` → `["Lint", "Typecheck", "Unit tests", "Build"]`
- If `stack.stack.language: "python"` → `["Lint", "Unit tests", "Build"]` (ruff covers lint+typecheck in Python)
- If `stack.stack.language: "go"` → `["Lint", "Unit tests", "Build"]` (go vet + staticcheck cover typecheck)
- If `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → add `"Integration tests"` and `"Security scan"` to the above
- If `appType: "fullstack"` → add `"E2E tests"` to the above
- Else → `["Lint", "Typecheck", "Unit tests", "Build"]` (greenfield opinion: lint + typecheck + unit tests + build is the minimum viable gate; these four checks catch the majority of regressions before merge)

### CICD.Q7 — Coverage threshold

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `willDeploy: true AND cicdAndDelivery.cicd.requiredPreMergeChecks includes "Coverage"` — **SKIP if condition not met**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.coverage`

**Prompt:** "Coverage threshold — what value blocks merges, if any?"

**Stores to:** `cicdAndDelivery.cicd.coverage` (object)

**Sub-questions:**
- `threshold` (integer or null): numeric 0–100, or `null` for no threshold
- `scope` (single-select): `"Global"` | `"Per-package"` | `"Per-file"`
- `blocking` (boolean): whether coverage drops block PRs

**Default:**
- If `architecturalFraming.scaleTarget: "hobby"` → `threshold: null`, `blocking: false` (greenfield opinion: hobby projects don't need enforced coverage floors)
- If `architecturalFraming.scaleTarget: "enterprise"` → `threshold: 90`, `scope: "Per-package"`, `blocking: true` (enterprise teams require high coverage floors enforced per package to prevent regressions in any module)
- Else → `threshold: 80`, `scope: "Global"`, `blocking: true` (greenfield opinion: 80% global coverage is the industry standard baseline; blocking keeps the floor from eroding)

### CICD.Q8 — Environment ladder

- **type:** single-select
- **options:** ["Single (prod only)", "Preview + prod", "Staging + prod", "Dev + staging + prod", "Custom"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`; default to `"Preview + prod"` without asking**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.envLadder`

**Prompt:** "Environment ladder — what environments will you deploy to?"

**Stores to:** `cicdAndDelivery.cicd.envLadder[]`

**Recommend:** Default to "Preview + prod" for SaaS; "Single" for hobby projects; "Staging + prod" for B2B with paying customers.

**Default:**
- If `architecturalFraming.scaleTarget: "hobby"` → `"Single (prod only)"` (greenfield opinion: hobby projects don't need staging environments)
- If `architecturalFraming.scaleTarget: "enterprise"` → `"Dev + staging + prod"` (greenfield opinion: enterprise requires environment isolation for compliance and release gates)
- If `architecturalFraming.scaleTarget: "startup"` AND `Q3.4.deployTarget: "vercel"` → `"Preview + prod"` (Vercel's preview deployments are automatic per-PR)
- If `architecturalFraming.scaleTarget: "production-scale"` → `"Staging + prod"` (greenfield opinion: staging for regression testing before hitting real users)
- Else → `"Preview + prod"` (greenfield opinion: preview deployments give per-PR validation without the operational overhead of a persistent staging environment)

### CICD.Q9 — Deployment trigger

- **type:** single-select
- **options:** ["Auto on merge", "Manual button", "Scheduled window", "Tag-triggered", "None — I'll deploy by hand"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`; default to `"Auto on merge"` without asking**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.autoDeploy`

**Prompt:** "How does deployment happen?"

**Stores to:** `cicdAndDelivery.cicd.autoDeploy`

**Default:**
- If `architecturalFraming.scaleTarget: "hobby"` → `"Auto on merge"` (greenfield opinion: hobby projects benefit from zero-friction deployments)
- If `architecturalFraming.scaleTarget: "enterprise"` → `"Manual button"` (greenfield opinion: enterprise deployments need a human sign-off before production traffic is affected)
- If `releaseStrategy: "Semantic versioning + changelog"` → `"Tag-triggered"` (greenfield opinion: semver releases should be triggered by a signed tag, not every merge)
- Else → `"Auto on merge"` (greenfield opinion: continuous delivery reduces batch size and makes problems easier to diagnose)

### CICD.Q10 — Deploy cadence

- **type:** single-select
- **options:** ["Continuous (multiple per day)", "Daily", "Weekly", "On-demand only", "Not deploying"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`; default to `"On-demand only"` without asking**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.deployCadence`

**Prompt:** "Deploy cadence — how often will you ship?"

**Stores to:** `cicdAndDelivery.cicd.deployCadence`

**Default:**
- If `cicdAndDelivery.cicd.autoDeploy: "Auto on merge"` → `"Continuous (multiple per day)"` (greenfield opinion: auto-on-merge implies continuous cadence)
- If `architecturalFraming.scaleTarget: "enterprise"` → `"Weekly"` (greenfield opinion: enterprise change management processes typically gate weekly release cycles)
- If `architecturalFraming.scaleTarget: "startup"` → `"Daily"` (greenfield opinion: startups ship often to learn faster)
- Else → `"On-demand only"` (greenfield opinion: explicit deploy decisions give the developer control without committing to a schedule)

### CICD.Q11 — Rollback strategy

- **type:** repeating structured
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `willDeploy: true AND cicdAndDelivery.cicd.autoDeploy ≠ "None — I'll deploy by hand"` — **SKIP if condition not met**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.rollback`

**Prompt:** "Rollback strategy?"

**Stores to:** `cicdAndDelivery.cicd.rollback` (object)

**Sub-questions:**
- `strategy` (single-select): `"Redeploy previous SHA"` | `"Blue-green"` | `"Canary"` | `"None"`
- `automation` (boolean): automated on failure detection?

**Default:**
- If `architecturalFraming.scaleTarget: "enterprise"` → `strategy: "Blue-green"`, `automation: true` (greenfield opinion: blue-green with automated cutover is the gold standard for zero-downtime enterprise rollback)
- If `architecturalFraming.scaleTarget: "production-scale"` → `strategy: "Canary"`, `automation: false` (greenfield opinion: canary rollouts detect issues in a small traffic slice before full promotion)
- Else → `strategy: "Redeploy previous SHA"`, `automation: false` (greenfield opinion: SHA redeploy is the simplest rollback; automation adds alert-integration complexity that's only worth it at scale)

### CICD.Q12 — CI secret management

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.secrets`

**Prompt:** "How are CI secrets managed?"

**Stores to:** `cicdAndDelivery.cicd.secrets` (object)

**Sub-questions:**
- `manager` (single-select): `"Provider-stored (GitHub/GitLab secrets)"` | `"OIDC to cloud"` | `"Vault"` | `"1Password"` | `"Doppler"` | `"Manual env files"`
- `rotation` (single-select): `"Manual only"` | `"Scheduled"` | `"On incident only"`

**Default:**
- If `architecturalFraming.scaleTarget: "enterprise"` → `manager: "Vault"`, `rotation: "Scheduled"` (greenfield opinion: enterprise requires audit trails and automated rotation)
- If `Q3.4.deployTarget: "aws"` AND `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `manager: "OIDC to cloud"` (greenfield opinion: OIDC eliminates long-lived credentials entirely)
- Else → `manager: "Provider-stored (GitHub/GitLab secrets)"`, `rotation: "Manual only"` (greenfield opinion: GitHub/GitLab secrets are encrypted at rest and sufficient for most projects)

### CICD.Q13 — CI notification channels

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.notifications`

**Prompt:** "Where should CI notifications go?"

**Stores to:** `cicdAndDelivery.cicd.notifications` (object)

**Sub-questions:**
- `channels` (multi-select): `"Slack"` | `"Discord"` | `"Email"` | `"GitHub checks only"`
- `events` (multi-select): `"Build failure"` | `"Deploy success"` | `"Deploy failure"` | `"Security alert"`

**Note:** Solo developer + Slack channel selection triggers a warning in synthesis review.

**Default:**
- If `hasTeam: true` → `channels: ["Slack"]`, `events: ["Build failure", "Deploy failure", "Deploy success"]`
- If `architecturalFraming.scaleTarget: "enterprise"` → add `"Security alert"` to `events`
- Else → `channels: ["GitHub checks only"]`, `events: ["Build failure", "Deploy failure"]` (greenfield opinion: GitHub checks are zero-config and sufficient for solo developers; Slack adds setup overhead)

### CICD.Q14 — Build matrix

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.buildMatrix`

**Prompt:** "Build matrix?"

**Stores to:** `cicdAndDelivery.cicd.buildMatrix` (object)

**Sub-questions:**
- `os` (multi-select): `"ubuntu-latest"` | `"macos-latest"` | `"windows-latest"`
- `languageVersions` (single-select): `"Single (current LTS)"` | `"Multi (current LTS + previous)"`
- `parallelization` (single-select or integer): `"Auto (CI provider decides)"` | `"Off (serial)"` | numeric value

**Recommend:** Most projects → single ubuntu-latest. Cross-platform tools → multi-OS. Libraries → multi-version.

**Default:**
- If `appType: "library"` OR `appType: "cli"` → `languageVersions: "Multi (current LTS + previous)"` (greenfield opinion: libraries and CLIs must not silently break on older runtimes)
- If `appType: "cli"` AND `stack.stack.language ∈ (go, rust)` → `os: ["ubuntu-latest", "macos-latest", "windows-latest"]` (cross-platform CLIs must be tested on all target OSes)
- Else → `os: ["ubuntu-latest"]`, `languageVersions: "Single (current LTS)"`, `parallelization: "Auto (CI provider decides)"` (greenfield opinion: ubuntu-latest + current LTS covers 95% of deployment targets)

### CICD.Q15 — CI caching strategy

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.caching`

**Prompt:** "Caching strategy?"

**Stores to:** `cicdAndDelivery.cicd.caching` (object)

**Sub-questions:**
- `deps` (boolean): cache dependency installs
- `build` (boolean): cache build outputs
- `dockerLayers` (boolean): cache Docker layers
- `remote` (single-select): `"Turbo Remote Cache"` | `"BuildKite Cache"` | `"None"`

**Default:**
- If `isMonorepo: true` → `remote: "Turbo Remote Cache"`, `build: true` (greenfield opinion: monorepos with Turborepo benefit enormously from remote caching)
- If `dockerStrategy ∈ (both, deployment-only)` → `dockerLayers: true`
- Else → `deps: true`, `build: false`, `dockerLayers: false`, `remote: "None"` (greenfield opinion: caching deps is a 1-2 min win for free; caching build outputs is only worth it for slow builds)

### CICD.Q16 — CI time budget

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.timeBudget`

**Prompt:** "CI time budget?"

**Stores to:** `cicdAndDelivery.cicd.timeBudget` (object)

**Sub-questions:**
- `perPipelineMinutes` (integer): target minutes per pipeline run
- `blockingThresholdMinutes` (integer or null): pipelines exceeding this fail; `null` means no block

**Default:**
- If `architecturalFraming.scaleTarget: "hobby"` → `perPipelineMinutes: 5`, `blockingThresholdMinutes: null` (greenfield opinion: hobby projects have low CI investment; 5 minutes is generous enough)
- If `architecturalFraming.scaleTarget: "enterprise"` → `perPipelineMinutes: 15`, `blockingThresholdMinutes: 20` (enterprise teams with large test suites need more time but enforcement prevents pipeline sprawl)
- Else → `perPipelineMinutes: 10`, `blockingThresholdMinutes: null` (greenfield opinion: 10 minutes is the standard target for fast-feedback CI; blocking thresholds add enforcement only when time budgets are a formal team requirement)

### CICD.Q17 — Release pipeline

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `willDeploy: true` — **SKIP if `willDeploy: false`**
- **R3-updates-path:** `context.phases.cicdAndDelivery.cicd.releasePipeline`

**Prompt:** "Release pipeline?"

**Stores to:** `cicdAndDelivery.cicd.releasePipeline` (object)

**Sub-questions:**
- `separate` (boolean): separate pipeline from main CI
- `triggeredBy` (single-select): `"Tag"` | `"Manual"` | `"Schedule"`
- `convention` (single-select): `"release-please"` | `"semantic-release"` | `"Manual"` | `"None"`

**Note:** `release-please` and `semantic-release` are Node-centric. Mismatches with `stack.stack.framework` (non-Node stacks) trigger a synthesis warning.

**Default:**
- If `releaseStrategy: "Semantic versioning + changelog"` AND `stack.stack.language: "typescript"` → `convention: "release-please"`, `triggeredBy: "Tag"` (greenfield opinion: release-please automates changelog generation from conventional commits)
- If `releaseStrategy: "Continuous deployment"` → `separate: false`, `convention: "None"` (no separate release pipeline needed for CD)
- If `architecturalFraming.scaleTarget: "enterprise"` → `separate: true`, `triggeredBy: "Manual"` (greenfield opinion: enterprise release pipelines need a dedicated, manually-triggered process with approval gates)
- Else → `separate: false`, `triggeredBy: "Tag"`, `convention: "None"` (greenfield opinion: tag-triggered releases are explicit without requiring a separate pipeline)

**After CICD.Q17**, invoke synthesis-review inline:

> Invoke `Skill(synthesis-review, phaseId: "cicdAndDelivery")` — renders `docs/adr/cicd-and-delivery.html` and walks the developer through approve/adjust/skip.

---

### CICD.Q_RISK — CI/CD risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["ops", "scaling", "vendor-lock"]

**Prompt:** "What's the biggest CI/CD risk for THIS project? (e.g., 'single-region deploys, no canary path yet', 'tooling drift bot creates noise that masks real PRs', 'no automatic rollback on failed health check'.)"

**Stores to:** `risks[]` array (new entry with `originatingPhase = "cicdAndDelivery"`, id auto-assigned `R-CICDANDDELIVERY-1`)

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| CICD.Q1 | ✓ | ✓ | Drift detection action — foundational; skipped if willDeploy: false |
| CICD.Q2 | ✓ | ✓ | Auto-evolution mode — foundational; always fires |
| CICD.Q3 | ✓ | — | AI PR review trigger — depth; skipped for solo or no-deploy; uses default in light |
| CICD.Q4 | ✓ | ✓ | CI provider — foundational; skipped if willDeploy: false |
| CICD.Q5 | ✓ | ✓ | CI trigger events — foundational pipeline timing |
| CICD.Q6 | ✓ | ✓ | Required pre-merge checks — foundational |
| CICD.Q7 | ✓ | — | Coverage threshold — depth; only fires if Coverage in Q6 selection |
| CICD.Q8 | ✓ | ✓ | Environment ladder — foundational |
| CICD.Q9 | ✓ | ✓ | Deployment trigger — foundational |
| CICD.Q10 | ✓ | ✓ | Deploy cadence — foundational ship rhythm |
| CICD.Q11 | ✓ | ✓ | Rollback strategy — foundational |
| CICD.Q12 | ✓ | — | CI secret management — depth; uses defaults in light |
| CICD.Q13 | ✓ | — | CI notification channels — depth; uses defaults in light |
| CICD.Q14 | ✓ | — | Build matrix — depth; uses defaults in light |
| CICD.Q15 | ✓ | — | CI caching strategy — depth; uses defaults in light |
| CICD.Q16 | ✓ | — | CI time budget — depth; uses defaults in light |
| CICD.Q17 | ✓ | — | Release pipeline — depth; uses defaults in light |
| CICD.Q_RISK | ✓ | ✓ | Always fires |
