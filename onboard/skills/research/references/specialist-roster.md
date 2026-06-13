# Specialist Roster — the 7 built-in dimensions

These are the seven built-in research dimensions. The engine dispatches `research-specialist` once per enabled dimension (subject to the depth cap in `depth-profiles.md`), filling the per-dimension prompt template below with the dimension's `scopeGlobs` (intersected with the detected source roots). The four **core** dimensions (`architecture`, `data-model`, `testing`, `security`) run at `standard` depth; all seven run at `comprehensive`.

Each specialist returns a `research-findings.json` object (`dimension`, `status`, `claims[]` with `file:line` evidence + confidence). Every dimension below states **what evidence it produces** and gives a **concrete prompt template** the engine passes as the specialist's `prompt`.

---

## 1. `architecture` *(core)*

**Evidence produced:** layering and module boundaries — which layers call which, import direction between modules, entry points, the dominant structural pattern (MVC, hexagonal, feature-sliced, monolith vs. service split), and any layering violations.

**Default `scopeGlobs`:** `["src/**", "app/**", "lib/**", "pkg/**", "internal/**"]`

**Prompt template:**
> Assess the **architecture** of this project over {scopeGlobs}. Map the layers and their call direction (e.g. controllers → services → repositories), the module/package boundaries and which import which, the entry points, and the dominant structural pattern. Flag any layering violations (a layer reaching past its neighbor, a cycle between modules). Emit one claim per structural fact, each with `file:line` evidence you actually read and a confidence reflecting how consistent the pattern is across the sampled modules. If the project is too small or unstructured to have an architecture, return `status:"not-assessed"`.

---

## 2. `data-model` *(core)*

**Evidence produced:** persistence and domain shape — entities/tables/collections, their relationships, the ORM/query layer, schema/migration files, and where the data model is defined vs. used.

**Default `scopeGlobs`:** `["**/models/**", "**/entities/**", "**/schema*/**", "prisma/**", "migrations/**", "**/*.prisma", "**/*.sql"]`

**Prompt template:**
> Assess the **data model** of this project over {scopeGlobs}. Identify the entities/tables/collections, their relationships (1:1, 1:N, M:N, ownership), the persistence layer (ORM, query builder, raw SQL), and the schema/migration story. Note where the model is defined and how it is consumed. Emit one claim per data-model fact, each with `file:line` evidence and a confidence. If the project has no persistence layer, return `status:"not-assessed"`.

---

## 3. `testing` *(core)*

**Evidence produced:** test posture — framework(s), test layout, breadth (unit/integration/e2e), coverage signals, fixtures/mocking conventions, and obvious gaps (untested critical paths).

**Default `scopeGlobs`:** `["**/*.test.*", "**/*.spec.*", "**/tests/**", "**/test/**", "**/__tests__/**", "**/*_test.*", "**/conftest.py"]`

**Prompt template:**
> Assess the **testing** posture of this project over {scopeGlobs}. Identify the test framework(s), how tests are laid out and named, the breadth (unit vs. integration vs. e2e), any coverage configuration, and the fixture/mocking conventions. Flag conspicuous gaps — critical code with no nearby test, an e2e layer that is empty, a coverage threshold that is unset. Emit one claim per testing fact, each with `file:line` evidence and a confidence. If the project has no tests, return `status:"assessed"` with a single claim recording the absence (that absence IS the finding), or `status:"not-assessed"` if you cannot even locate a test runner.

---

## 4. `security` *(core)*

**Evidence produced:** security surface — authn/authz approach, secret handling, input validation, dangerous sinks (eval, shell-out, raw SQL), dependency-level risk signals, and security-sensitive paths.

**Default `scopeGlobs`:** `["src/**", "app/**", "**/auth/**", "**/middleware/**", "**/*.env*", "**/config/**"]`

**Prompt template:**
> Assess the **security** surface of this project over {scopeGlobs}. Identify the authentication/authorization approach, how secrets are handled (env, vault, hardcoded?), where and how input is validated, and any dangerous sinks (`eval`, shell-out, string-built SQL, unescaped output). Note security-sensitive paths (auth, payments, file upload). Emit one claim per security observation, each with `file:line` evidence and a confidence; a claimed vulnerability MUST cite the exact locus. Default to caution — do not assert a guard exists unless you read it. If there is no security-relevant surface, return `status:"not-assessed"`.

---

## 5. `conventions` *(comprehensive only)*

**Evidence produced:** code conventions — naming, file organization, import/export style, error-handling pattern, logging pattern, formatting/lint config, and how consistently they are followed.

**Default `scopeGlobs`:** `["src/**", "app/**", "lib/**", ".eslintrc*", ".prettierrc*", "biome.json", "pyproject.toml", "**/*.config.*"]`

**Prompt template:**
> Assess the **conventions** of this project over {scopeGlobs}. Identify the naming conventions (files, symbols), the import/export style (barrel files? default vs. named?), the error-handling pattern (exceptions, Result types, error middleware), the logging pattern, and the lint/format configuration. Judge how consistently each convention is followed. Emit one claim per convention, each with `file:line` evidence and a confidence reflecting consistency. If the project is too small to exhibit conventions, return `status:"not-assessed"`.

---

## 6. `domain` *(comprehensive only)*

**Evidence produced:** business domain — the ubiquitous language, the core concepts/aggregates, bounded contexts (if any), and the mapping from domain terms to code symbols (for the glossary artifact).

**Default `scopeGlobs`:** `["src/**", "app/**", "lib/**", "domain/**", "**/models/**", "docs/**", "README*"]`

**Prompt template:**
> Assess the **business domain** of this project over {scopeGlobs}. Extract the ubiquitous language — the domain nouns and verbs that recur in code and docs — and map each to its code symbol(s). Identify the core concepts/aggregates and any bounded contexts. This evidence seeds the glossary artifact, so favor terms a new contributor would need defined. Emit one claim per domain concept, each with `file:line` evidence (where the concept lives in code) and a confidence. If the project has no discernible business domain (e.g. a generic library), return `status:"not-assessed"`.

---

## 7. `dependencies` *(comprehensive only)*

**Evidence produced:** dependency posture — direct vs. transitive weight, notable/heavy/risky libraries, version currency, lockfile presence, and supply-chain signals (unmaintained or pinned-old packages).

**Default `scopeGlobs`:** `["package.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "requirements*.txt", "pyproject.toml", "poetry.lock", "go.mod", "go.sum", "Cargo.toml", "Cargo.lock", "Gemfile*"]`

**Prompt template:**
> Assess the **dependencies** of this project over {scopeGlobs}. Read the manifest(s) and lockfile(s). Identify the notable/heavy/security-relevant libraries, the direct vs. transitive split, version currency (anything conspicuously old or unmaintained), and lockfile presence. Note supply-chain signals (a package pinned years old, a deprecated library). Emit one claim per dependency observation, each with `file:line` evidence (the manifest line) and a confidence. If there is no dependency manifest, return `status:"not-assessed"`.

---

## How the engine uses this file

1. Compute the effective roster (`custom-specialist-contract.md`) and apply the depth cap (`depth-profiles.md`).
2. For each enabled built-in dimension, take its `scopeGlobs`, **intersect** with the detected source roots (root-dwelling globs — manifests/lockfiles, docs, test/lint config — are exempt from the intersection; see SKILL § Step 2), fill `{scopeGlobs}` into the prompt template above.
3. Dispatch `research-specialist` in ONE batch (Step 3 of the SKILL), one per dimension, each prompt carrying `dispatchedAsAgent: true`.
4. Collect the `research-findings.json` objects for Gate-1.

The `domain` dimension's claims are the primary feed for the glossary artifact; the `security` and (risk-tagged) claims feed the risk register — see `synthesis-and-dossier.md`.
