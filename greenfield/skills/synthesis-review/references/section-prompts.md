# Section Prompts — Synthesis Composition Strategies

Per-section guidance for the synthesis-review skill (Step 2). Loaded at runtime; updates here flow into all future syntheses without code changes elsewhere.

## Section anatomy

Every synthesis section contains, in order:

1. **Section title** — human-friendly name (e.g., "CI Provider", "Pre-merge Gates").
2. **Captured-as** — actual value(s) collected during the wizard, rendered in a `<pre class="captured">` block. Always include the originating wizard question ID (Q5.4 etc.) for traceability.
3. **Cross-checks** — one bullet per declared dependency from `context.dependencies[phaseId]`. Format: `Assumes <dependency-path> = <value>.` followed by the rationale. If the dependency was not yet captured at synthesis time, render "not yet captured" rather than blocking.
4. **Contradictions** (only if any) — auto-detected mismatches between the section value and any dependency. Rendered as `<div class="contradiction">`.
5. **Notes for the developer** — anything the LLM noticed during composition that the developer should be aware of (rendered as `<div class="note">`).

## Contradiction detection

Run these checks at compose time. Each one fires only if both endpoint values exist.

| Check | Condition | Fires |
|---|---|---|
| Deploy-without-deploy | `phases.P8.cicd.envLadder` includes "prod" AND `phases.P0.willDeploy === false` | "P8 picked a production environment but P0 said this project won't deploy. One of these is wrong — resolve." |
| Notifications-without-channel | `phases.P8.cicd.notifications.channels` includes a channel whose corresponding stack field (e.g., Slack workspace URL) is unset | "P8 wants to notify on `<channel>` but the connection details haven't been captured yet." |
| Coverage-blocking-without-tests | `phases.P8.cicd.coverage.blocking === true` AND `phases.P7.testingPhilosophy` (Round 3) is `"manual-only"` | "P8 wants coverage to block PRs, but P7 said testing is manual-only. The block will fail every PR." |

Round 1 ships only the first check. The second and third require Round 3 phases (P7) — the rules are documented here so they fire automatically once P7 lands.

## Round 1 sections (P8 CI/CD)

Use this table to compose `p8-cicd.html` sections.

| Section | Maps to (context.phases.P8.cicd.*) | Cross-checks |
|---|---|---|
| Pipeline trigger model | `provider`, `triggers[]` | Assumes `P0.willDeploy = true`. |
| Pre-merge quality gates | `requiredPreMergeChecks[]`, `coverage{}` | Assumes `P7.testingPhilosophy` (deferred to Round 3 — annotate as "not yet captured"). |
| Environment ladder & deploy strategy | `envLadder[]`, `autoDeploy`, `deployCadence` | Assumes `P0.willDeploy`. Cross-check: any env beyond "dev" requires willDeploy=true. |
| Secrets & rollback | `secrets{}`, `rollback{}` | Assumes `P3.databaseHost` (deferred to Round 2 — annotate). |
| Notifications & on-call | `notifications{}` | Assumes `P0.teamSize`. Lone-developer + Slack notifications combination produces a warning note. |
| Performance & cost | `buildMatrix{}`, `caching{}`, `timeBudget{}` | None for Round 1. |
| Release pipeline | `releasePipeline{}` | Assumes `P2.stack`. release-please needs Node tooling; semantic-release needs Node tooling. Flag mismatches. |
| Auto-evolution & PR review | `_v1_carryover.ciAuditAction`, `_v1_carryover.autoEvolutionMode`, `_v1_carryover.prReviewTrigger` | None — these are the legacy Q5.1/Q5.2/Q5.3 answers preserved as-is. |

## Tone

- Render captured values verbatim. Do not paraphrase.
- Cross-checks are descriptive, not interrogative. "Assumes P0.willDeploy = true." not "Did you remember that P0 said willDeploy is true?"
- Contradictions are blunt. "P8 wants to auto-deploy to prod, but P0 said this project won't deploy. One of these is wrong."
- Notes are colloquial. "Heads-up — you picked GitLab CI but Round 1 only emits GitHub Actions templates."

## Anti-patterns

- Don't invent dependency cross-checks that don't have both endpoints captured. Render "not yet captured" instead.
- Don't soften contradictions. They're the point.
- Don't write more than ~3 lines per section's Notes block. Long notes belong in `CLAUDE.md`.
- Don't omit the `Captured-as` block even if the value is `null` — render `null` explicitly so the developer sees the gap.
