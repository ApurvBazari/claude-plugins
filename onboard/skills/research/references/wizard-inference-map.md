# Wizard Inference Map — findings → `wizardInferences`

Synthesis derives `research-dossier.wizardInferences` — a best-effort, evidence-grounded guess at the wizard answers, so the Plan-3 grounded wizard can pre-fill questions instead of asking cold. Each inference is emitted as `{ value, evidence[], confidence }` (the `research-dossier.json` `wizardInferences` value shape: `value` required, `evidence`/`confidence` optional).

**Hard rule:** `autonomyLevel` is **NEVER inferred.** It is a human preference about how much latitude Claude gets — research cannot read it from code, and guessing it would be unsafe. The wizard always asks it directly. Do not emit a `wizardInferences.autonomyLevel` key.

## The inference rules

Each rule names the source dimension(s), the signal, and how to set `value`. `evidence[]` carries the `file:line` (or repo-fact) anchors behind the guess; `confidence` reflects signal strength. Emit a field ONLY when there is a real signal — omit it (rather than guessing blind) when no signal exists.

| Wizard field | Value enum | Inference rule | Primary signal source |
|---|---|---|---|
| `teamSize` | `solo` \| `small` \| `medium` \| `large` | Bucket the distinct git contributor count (`git shortlog -sn`): 1 → solo, 2–5 → small, 6–15 → medium, 15+ → large. | repo git history (a `dependencies`/recon read) |
| `projectMaturity` | `new` \| `early` \| `established` \| `legacy` | Combine commit history depth, presence of tests + CI, and dependency currency: no tests/CI + few commits → new/early; tests + CI + steady history → established; old deps + large history → legacy. | `testing` + `dependencies` + git history |
| `codeStyleStrictness` | `relaxed` \| `moderate` \| `strict` | From the `conventions` dimension: a configured linter+formatter with strict rules (typed, no-implicit-any, etc.) → strict; a linter present but lax → moderate; none → relaxed. | `conventions` |
| `securitySensitivity` | `standard` \| `elevated` \| `high` | From the `security` dimension: auth + payments/PII + secret-handling surface → high; auth present → elevated; none of these → standard. | `security` |
| `codeReviewProcess` | `none` \| `informal` \| `formal-pr` | From repo signals: PR templates, CODEOWNERS, branch-protection-style CI gates → formal-pr; merge commits / PR history without templates → informal; direct-to-main commits only → none. | `conventions` + recon (`.github/**`) |
| `branchingStrategy` | `trunk-based` \| `gitflow` \| `feature-branches` | From branch names + git history: `develop` + `release/*` + `hotfix/*` → gitflow; many short-lived `feat/*` merged to main → feature-branches; commits mostly straight to main → trunk-based. | recon (git branches) |
| `deployFrequency` | `continuous` \| `daily` \| `weekly` \| `manual` \| `none` | From CI/CD: auto-deploy on merge → continuous; scheduled/tagged releases → daily/weekly; a deploy workflow run by hand → manual; no deploy pipeline → none. | recon (`.github/workflows/**`) + `conventions` |
| `primaryWork` | free-form / project-shaped | From `architecture` + `domain`: characterize the dominant work (e.g. "API service", "React SPA", "CLI tool", "data pipeline", "library"). | `architecture` + `domain` |

## Emission shape (per field)

```json
"wizardInferences": {
  "teamSize":             { "value": "small",   "evidence": ["git shortlog: 4 contributors"], "confidence": 0.8 },
  "securitySensitivity":  { "value": "elevated", "evidence": ["src/auth/", "stripe SDK in package.json:24"], "confidence": 0.7 },
  "codeStyleStrictness":  { "value": "strict",  "evidence": [".eslintrc.json:3 (typescript-strict)"], "confidence": 0.85 }
}
```

## Rules

1. **Never infer `autonomyLevel`** — omit it entirely; the wizard asks it directly.
2. **Signal-or-omit** — emit a field only when a real signal exists; do not guess a value with no evidence (an absent inference is honest; a blind guess pollutes the grounded wizard).
3. **Evidence-backed** — every emitted inference carries `evidence[]` anchors (a `file:line` or a stated repo fact like `"git shortlog: 4 contributors"`).
4. **Confidence reflects signal strength** — a single weak signal → low confidence; converging signals → high.
5. **Values stay in the wizard's enums** — match the `wizardAnswers` enum values the generate skill expects (`teamSize`, `projectMaturity`, `codeStyleStrictness`, `securitySensitivity`, `codeReviewProcess`, `branchingStrategy`, `deployFrequency`); `primaryWork` is the one free-form characterization.
6. **Derive from verified findings first** — prefer claims in `verifiedClaims` over dropped ones when forming an inference.
