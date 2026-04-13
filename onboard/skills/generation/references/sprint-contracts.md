# Sprint Contracts

Sprint contracts define the success criteria for a sprint BEFORE work begins. They are interactively negotiated between Claude and the developer, creating a shared definition of "done" that the evaluator checks against.

Based on Anthropic's harness design: "Before each sprint, generator and evaluator negotiate a contract defining deliverables and success criteria."

## Contract Format

Stored in `docs/sprint-contracts/sprint-N.json`:

```json
{
  "sprint": 1,
  "name": "Core Foundation",
  "negotiatedAt": "2026-04-05T10:30:00Z",
  "features": ["F001", "F002", "F003", "F004", "F005"],
  "criteria": [
    {
      "name": "functional",
      "description": "All features pass their verification steps end-to-end",
      "threshold": "ALL features in this sprint must pass /onboard:verify",
      "weight": "required"
    },
    {
      "name": "quality",
      "description": "Code follows CLAUDE.md conventions and path-scoped rules",
      "threshold": "Linter passes with 0 errors on new/modified files",
      "weight": "required"
    },
    {
      "name": "testing",
      "description": "Each feature has at least one automated test",
      "threshold": "Test file exists for each feature's primary module; test suite passes",
      "weight": "required"
    }
  ],
  "completionGate": "ALL required criteria must pass"
}
```

### Criterion Weights

- **required**: Must pass for the sprint to be complete. Sprint gate fails if any required criterion fails.
- **recommended**: Should pass, reported in evaluation, but doesn't block sprint completion.
- **aspirational**: Nice-to-have, tracked but no impact on sprint gate.

### Standard Criteria Types

| Criterion | What it checks | Typical threshold |
|---|---|---|
| `functional` | All features pass E2E verification | ALL features pass |
| `quality` | Code follows project conventions | Linter 0 errors, type-checker clean |
| `testing` | Features have automated tests | Test file per feature module, suite passes |
| `performance` | Performance targets met | LCP < 2.5s, bundle < 200KB (if targets set) |
| `accessibility` | A11y compliance | axe-core 0 violations at target level |
| `security` | Security checks pass | No high/critical vulnerabilities |
| `documentation` | API docs updated | OpenAPI spec matches routes (if API project) |
| `design-quality` | UI has coherent visual identity | Colors, typography, layout create distinct mood (frontend only) |
| `originality` | Evidence of custom decisions vs defaults | No unmodified stock components or AI-slop patterns (frontend only) |
| `craft` | Technical execution of design | Typography hierarchy, spacing, color harmony, contrast (frontend only) |

Not all criteria apply to every sprint. Select based on the project's Phase 1 context (a11yLevel, perfTargets, securitySensitivity, apiDocs, hasFrontend).

### Design Criteria (Frontend Projects)

From Anthropic's harness research, Claude already scores well on craft and functionality by default, but struggles with design quality and originality. For frontend projects, emphasize:

1. **Design Quality** (required for UI sprints): "Does the design feel like a coherent whole rather than a collection of parts?"
2. **Originality** (recommended): "Is there evidence of custom decisions, or is this template layouts and library defaults?"

These criteria are only included for sprints that contain `ui` category features. Calibrate the evaluator's design judgment via the few-shot examples in the feature-evaluator agent.

## Interactive Negotiation Flow

Before each sprint, Claude proposes criteria and the developer negotiates:

### Step 1: Propose

Claude reads the features for the upcoming sprint from `docs/feature-list.json` and proposes criteria:

> **Sprint 2 — User Management**
> Features: F006 (signup), F007 (login), F008 (profile), F009 (password reset)
>
> I propose these completion criteria:
>
> 1. **Functional** (required): All 4 features pass E2E verification
> 2. **Quality** (required): ESLint clean, TypeScript strict mode clean
> 3. **Testing** (required): Each feature has integration test; auth flows have E2E test
> 4. **Security** (required): Auth tokens are httpOnly, passwords are hashed, CSRF protection active
> 5. **Performance** (recommended): Login flow completes in < 1s
>
> Adjust any criteria?

### Step 2: Negotiate

Developer adjusts:
- "Loosen performance for now — recommended, not required"
- "Add: password reset email must actually send in test environment"
- "Drop the E2E test requirement — integration tests are enough for Sprint 2"

Claude incorporates the feedback and presents the revised contract.

### Step 3: Confirm

> Updated Sprint 2 contract:
> [revised criteria]
>
> Lock this in?

Developer confirms. Claude writes `docs/sprint-contracts/sprint-2.json`.

### Step 4: Begin Sprint

Claude references the locked contract throughout the sprint. At sprint end, `/onboard:verify --sprint 2` checks all criteria.

## Language Priming in Criteria

From Anthropic: "Including phrases like 'the best designs are museum quality' pushed designs toward a particular visual convergence." Criteria wording is a steering mechanism — subtle language shapes output quality.

### Guidelines for Criteria Wording

**Push quality higher** with aspirational language:

| Weak (just passes) | Strong (pushes quality) |
|---|---|
| "UI renders correctly" | "UI is polished with consistent spacing, smooth transitions, and a coherent visual identity" |
| "API returns correct data" | "API responses are well-structured, properly paginated, include appropriate error codes, and have sub-200ms response times" |
| "Tests pass" | "Tests cover happy paths, edge cases, and error states with descriptive names that serve as documentation" |
| "Feature works" | "Feature is intuitive — a new user can complete the task without reading documentation" |

**Be specific** — vague criteria produce vague output:

| Vague | Specific |
|---|---|
| "Good code quality" | "No ESLint errors, TypeScript strict mode clean, no `any` types, functions under 50 lines" |
| "Secure authentication" | "Passwords bcrypt-hashed (cost 12+), tokens httpOnly + SameSite=Strict, CSRF protection on state-changing routes" |

**Criteria influence implementation ambition** — if you want Claude to reach for sophisticated solutions, say so in the criteria.

## How the Evaluator Uses Contracts

When `/onboard:verify --sprint N` runs:

1. Feature evaluator tests each feature in the sprint (standard verification)
2. After feature testing, evaluator checks each contract criterion:
   - **functional**: based on feature pass/fail results
   - **quality**: runs linter/type-checker via Bash
   - **testing**: uses Glob to find test files, runs test suite
   - **performance**: runs Lighthouse or curl timing tests
   - **accessibility**: runs axe-core if available
   - **security**: runs security checks relevant to the criterion
3. Reports criterion status: MET / NOT MET with evidence
4. Reports sprint gate: PASSED (all required met) or NOT PASSED

## Generating Sprint Contracts

### When to Generate

- **First sprint contract**: Generated during Phase 3 of Forge (along with feature-list.json). Claude proposes, developer negotiates during the handoff step.
- **Subsequent sprints**: Generated at sprint boundary. When Sprint N is complete (all verified), Claude proposes Sprint N+1 contract before work begins.

### Auto-Proposal Logic

Claude generates proposed criteria based on:
1. **Project context** from forge-meta.json (testing philosophy, security sensitivity, a11y level, perf targets)
2. **Feature categories** in the sprint (auth features → add security criterion)
3. **Previous sprint** criteria (carry forward what worked, adjust what was too strict/loose)

### Folder Structure

```
docs/
├── feature-list.json
├── progress.md
└── sprint-contracts/
    ├── sprint-1.json
    ├── sprint-2.json
    └── ...
```

The `sprint-contracts/` directory is created during Phase 3 when the first contract is negotiated.
