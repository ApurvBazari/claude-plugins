# Onboard Target-Test Batch Report — 5 diverse repos (2026-04-22)

## Summary

Second target-test pass after got. Ran onboard's `codebase-analyzer` + `config-generator` agents against 5 deliberately diverse repos: **sqlmodel** (Python library), **gin** (Go web framework), **create-t3-app** (pnpm+turbo monorepo + CLI), **shadcn-ui/ui** (3-workspace monorepo, 8582 files, pre-existing distributed AI tooling), **ccusage** (existing full Claude tooling — update-path test).

**Top-line findings:**

1. **GAP-TT-001 (hook env-var bug) is conditionally fixable** — when the prompt explicitly cites `hooks-guide.md`, config-generator uses the correct stdin-JSON pattern. Without that prompt, it regresses. Root-cause is in the prompt scaffolding, not the guide.
2. **Config-generator correctly refused the update-path target** (ccusage). Wrote zero files, surfaced the right recommendation (`/onboard:update`). Strong positive signal.
3. **Analyzer depth remains consistently high across 5 stacks** — Python, Go, TypeScript-CLI, monorepo, TypeScript+existing-Claude-tooling all got detailed, idiosyncratic analysis that beats the bundled scripts by wide margins.
4. **Monorepo per-package CLAUDE.md** worked well on both monorepo targets (create-t3-app: 3 files; shadcn-ui: 3 files across 3 workspaces).
5. **Pre-existing AI tooling preservation works correctly** — shadcn-ui had `.claude/settings.local.json` + `skills/shadcn/` (distributed) + `.cursor*` artifacts; all preserved untouched.
6. **5 new gaps surfaced** (GAP-TT-004 through GAP-TT-008), 1 P0, 3 P1, 1 P2.

Every target's generated artifacts live at `~/tmp/onboard-test/<repo>/` for manual inspection.

---

## Batch scope

| # | Target | Stack | Shape | Files | Outcome |
|---|---|---|---|---|---|
| 1 | `tiangolo/sqlmodel` | Python library (SA + Pydantic) | Single package, uv+pdm-backend | 509 | 11 artifacts generated |
| 2 | `gin-gonic/gin` | Go web framework | Single package, go mod | 130 | 20 artifacts generated (first target with MCP+output-style+LSP) |
| 3 | `t3-oss/create-t3-app` | TS CLI + monorepo | 2 workspaces (pnpm+turbo) | 543 | 21 artifacts incl. 3 CLAUDE.md (root/cli/www) |
| 4 | `shadcn-ui/ui` | Large TS monorepo | 3 workspaces, 8582 files | 8582 | 18 artifacts incl. 3 CLAUDE.md + preserved 4 user-owned files |
| 5 | `ryoppippi/ccusage` | TS monorepo + existing Claude tooling | 6 apps / 2 pkgs / 10 CLAUDE.md | 223 | **0 artifacts — correctly refused** |

---

## GAP-TT-001 reproduction matrix

Our previous target-test flagged GAP-TT-001 (hook commands use non-existent `$CLAUDE_TOOL_FILE` env var, silently no-op).

| Target | GAP-TT-001 status | Hook pattern used |
|---|---|---|
| got (baseline) | **Reproduced** | `$CLAUDE_TOOL_FILE` (broken) |
| sqlmodel | **Avoided** | `cat - \| jq -r '.tool_input.file_path'` ✓ |
| gin | **Avoided** | Same stdin-JSON pattern ✓ |
| create-t3-app | **Avoided** | Same stdin-JSON pattern ✓ |
| shadcn-ui | **Avoided** | Same stdin-JSON pattern ✓ |
| ccusage | N/A (refused) | N/A |

**Why it was avoided in 4/4 of this batch:** the dispatch prompt for each of these targets explicitly told the generator:
> PostToolUse hooks MUST use the stdin-JSON pattern from `hooks-guide.md`. Do not use `$CLAUDE_TOOL_FILE` env var — that's GAP-TT-001.

**Interpretation:** the bug reproduces under the default generation path (no explicit hooks-guide citation in got's prompt). It's prompt-scaffolding-fixable, not a deeper generation logic bug. The fix (GAP-TT-001 resolution) should wire the stdin-JSON citation into the default generation dispatch prompt — or better, into a canonical hooks template the generator uses by reference.

---

## Per-target findings

### Target 1 — `tiangolo/sqlmodel` (Python library)

**Analyzer depth** (new dimensions probed vs got):
- Python `pyproject.toml [dependency-groups]` (PEP 735) correctly parsed — distinguishes runtime / test / docs / dev groups. The script reported "FastAPI listed as framework" wrongly; analyzer identified fastapi as test-only dep used to verify integration examples.
- Detected `uv` as package manager (`uv.lock`), `pdm-backend` for wheel building — unusual combination but caught correctly.
- Detected `ty` (Astral's Go-port type checker) as the typechecker, NOT mypy. Scripts didn't catch this.
- Detected `prek` (Rust pre-commit reimpl, invoked as `uvx prek run`) — not `pre-commit`.
- Detected 99% coverage gate (both `coverage report --fail-under=99` AND `smokeshow` threshold).
- Detected **tutorial-as-test contract** — 149 example files in `docs_src/` have 1:1 paired tests in `tests/test_tutorial/`. Tiangolo signature pattern inherited from FastAPI.
- Detected **sqlmodel-slim/** deprecated-placeholder sibling (not a real monorepo member).
- Detected remote vs manifest URL mismatch (git remote `tiangolo/sqlmodel` but package metadata points to `fastapi/sqlmodel` after org move).

**Generated artifacts** (11 files, 191-line CLAUDE.md):
- `CLAUDE.md` leads with "uv not pip, ty not mypy, prek not pre-commit, ruff not black"
- Rules: `tutorial-test-pairing.md`, `library-source-discipline.md`, `generated-files.md`, `pr-template.md`
- Skills: `write-tutorial/SKILL.md` (7-step flow for docs_src + paired test), `write-pytest-test/SKILL.md`
- Agents: `api-boundary-reviewer.md`, `coverage-guardian.md`
- Hooks: `uv run ruff format`, `uv run ruff check`, `uv run ty check` — all stdin-JSON pattern

**Specificity highlights** (project-tailored content, not boilerplate):
1. `.claude/skills/write-tutorial/SKILL.md` uses the exact `mod.sqlite_url = "sqlite://"` idiom + `print_mock.calls` assertion pattern from tiangolo's codebase
2. The 3-dot `from ...conftest import PrintMock` relative import depth is encoded per-depth in a table
3. `coverage-guardian` agent specifically checks for "docs_src/ change without matching tests/test_tutorial/ mirror"
4. Python 3.10 floor (`.python-version`) + CI tests 3.14 = contradiction pattern is flagged
5. `sqlmodel-slim/` is called out as deprecated, edits to it rejected outright

### Target 2 — `gin-gonic/gin` (Go web framework)

**Analyzer depth** (new dimensions probed):
- Correctly identified: web framework (library-shaped), `master` branch (not `main`)
- Detected `go 1.25.0` floor, 5-tag × 2-OS × 2-Go-version = 20-leg CI matrix
- Detected build-tag polymorphism (sonic/go_json/jsoniter/nomsgpack/appengine) as load-bearing
- Detected testify split usage (assert 37 files / require 14 files) + testifylint `enable-all: true`
- Detected httptest-centric mocking (real servers, no `testify/mock`)
- Detected `ginS/` Sinatra-style adapter requiring mirror on Engine method additions
- Detected 99% codecov gate (same as sqlmodel, different mechanism)
- Detected `context.go` as 1489-LOC god-object — flagged for planning
- Detected `auth.go`'s IP-trust logic as CVE-sensitive

**Generated artifacts** (20 files — first target with MCP + output-style + LSP):
- `CLAUDE.md` (160 lines), `.mcp.json` (context7 + github), output-styles/solo-minimal.md, LSP snapshot for gopls
- Rules: `testing.md`, `api-boundary.md`, `build-tags.md`, `go-file-conventions.md`, `mcp-setup.md`
- Skills: `write-go-test/SKILL.md` (4 test patterns), `add-binding-or-render/SKILL.md` (canonical 2-file pattern)
- Agents: `api-boundary-reviewer.md` (sonnet), `coverage-guardian.md` (**haiku + maxTurns:2** — mechanical check, fast)

**Specificity highlights:**
1. `write-go-test` skill distinguishes 4 test archetypes (pure, Context, full HTTP, real listener) with exact file references (`test_helpers.go`, `gin_integration_test.go`)
2. `add-binding-or-render` skill encodes the ginS/ mirror requirement as an explicit step
3. `build-tags.md` rule scoped to `codec/json/**` + `*_nomsgpack.go` + `*_appengine.go` (precise)
4. Makefile's `lint` target (uses deprecated `golint`) is flagged as NOT the real lint; CI uses golangci-lint v2.11
5. coverage-guardian uses haiku because the gate check is mechanical — a smart choice

### Target 3 — `t3-oss/create-t3-app` (pnpm monorepo + CLI scaffolder)

**Analyzer depth** (monorepo-specific):
- Correctly identified **two-workspace** monorepo (cli/ + www/), not 3 as folklore suggested (dead `upgrade/` reference in `.vscode/settings.json`)
- Detected tailwind version split (cli uses v4, www aliases to v3) — intentional
- Detected **installer plugin registry** pattern (`cli/src/installers/index.ts` tuple + factory)
- Detected **template-driven codegen** with underscore-prefix convention (`_eslint.base.js`, `_gitignore`, `_npmrc`)
- Detected **no unit tests** — E2E matrix is the test surface (`.github/scripts/generate-matrix.js`)
- Detected **version pinning single source of truth** (`dependencyVersionMap.ts`)
- Detected Turbo v1 `pipeline` schema (not v2 `tasks`)
- Detected changesets-driven releases with `ignore: ["@ct3a/www"]`
- Detected CHANGELOG.md (78 KB) as Changesets-generated — "don't edit"
- Detected `cli/README.md` symlinked from root
- Detected ESLint 9 flat config

**Generated artifacts** (21 files, 3 CLAUDE.md files):
- Root CLAUDE.md (156 lines) + `cli/CLAUDE.md` (115) + `www/CLAUDE.md` (80) = first multi-CLAUDE.md target
- 6 rules incl. `installer-registry.md`, `template-authoring.md`, `e2e-matrix.md`, `locale-translations.md`, `changesets-releases.md`
- 3 skills: `add-installer`, `write-template-file`, `add-e2e-matrix-combo`
- 2 agents: `installer-registry-reviewer`, `monorepo-consistency-guardian`
- `.mcp.json` with context7 + github
- Hooks: workspace-aware prettier (detects cli/ vs www/ from path), advisory eslint

**Specificity highlights:**
1. `add-e2e-matrix-combo` skill explicitly tells Claude "don't add unit tests — extend the E2E matrix instead" (respects the project's chosen test philosophy)
2. `monorepo-consistency-guardian` agent checks manypkg drift + Turbo v1 schema preservation + Tailwind split integrity + cli/README.md symlink integrity
3. `add-installer` skill captures the 10-step flow (source, config, installer registry, flag mapping, incompatibility check, version map)
4. Template-underscore-prefix convention is encoded in both the rule and the skill

### Target 4 — `shadcn-ui/ui` (3-workspace monorepo, 8582 files, pre-existing AI tooling)

**Analyzer depth** (enterprise-scale + AI-tooling-already-present):
- Correctly identified 3 workspace members (`apps/v4`, `packages/shadcn`, `packages/tests`) + confirmed templates/* are NOT workspace members
- Explained `apps/v4/` version-dir pattern (major version; v5/ will live alongside during next migration)
- Identified **registry-as-product** — `apps/v4/public/r/*.json` (536+ files) is the SHIPPED artifact, not build cache
- Identified **Base UI vs Radix UI duality** in registry/bases/ + the existing cursor rule enforcing parity
- Identified **MCP inside CLI** (`shadcn mcp` subcommand, @modelcontextprotocol/sdk dep)
- Identified **16 presets** (2 bases × 8 styles) with encoded preset codes
- Identified **reserved namespace list** (hard-coded in `validate-registries.yml`)
- Correctly handled pre-existing AI tooling:
  - `.claude/settings.local.json` (user-personal, `npm` allowlist + Explanatory outputStyle)
  - `skills/shadcn/` TOP-LEVEL (distributed to downstream users via Cursor + Claude Code ecosystems)
  - `.cursor-plugin/plugin.json`, `.cursor/rules/registry-bases-parity.mdc`
- Identified 20 specific script gaps including: per-workspace package.json scan missed, Turbo v1-vs-v2, Tailwind v3/v4 split, OIDC trusted publishing, sync-templates destructive script

**Generated artifacts** (18 files, 3 CLAUDE.md):
- Root CLAUDE.md + `apps/v4/CLAUDE.md` + `packages/shadcn/CLAUDE.md`
- 5 rules: `registry-bases-parity.md` (Claude equivalent of cursor rule), `registry-sync.md`, `cli-preflight.md`, `templates-sync.md`, `release-publishing.md`
- 3 skills: `add-registry-component`, `add-cli-command`, `update-base-radix-parity`
- 2 agents: `registry-parity-guardian`, `cli-preflight-reviewer`
- `.mcp.json` with context7 + github
- `.claude/settings.json` (project-level, separate from settings.local.json) with stdin-JSON hooks

**Preservation audit** (all user-owned files verified untouched post-generation):
- `.claude/settings.local.json` — unchanged (size 253 bytes, same content)
- `.cursor-plugin/plugin.json` — unchanged
- `skills/shadcn/SKILL.md` — unchanged (17326 bytes)
- `.cursor/rules/registry-bases-parity.mdc` — unchanged

**Specificity highlights:**
1. `registry-sync.md` rule enumerates the 16 reserved namespaces verbatim
2. `templates-sync.md` rule explicitly warns that `pnpm sync:templates` is DESTRUCTIVE (wipes + mirrors templates to separate repos)
3. `cli-preflight-reviewer` agent audits: preflight existence + MCP mirror + fixture presence for new commands
4. `add-registry-component` skill instructs authoring in BOTH `bases/base/` AND `bases/radix/` trees
5. Per-workspace CLAUDE.md split correctly — apps/v4 covers Turbopack+fumadocs, packages/shadcn covers commander+ts-morph+tsup

### Target 5 — `ryoppippi/ccusage` (UPDATE-PATH TEST: existing full Claude tooling)

**Analyzer depth** (update-path-aware):
- Fully inventoried the existing 10 CLAUDE.md files + 9 AGENTS.md symlinks + `.claude/settings.json` + `.claude/commands/` + 2 skills + `.mcp.json` + `.githooks/pre-commit`
- Identified **stale content** precisely: Claude model list at lines 263-265 is 2025-only; line 204 has "double quotes" contradicting `oxfmt.config.ts`'s `singleQuote: true`; `apps/mcp/package.json` violates the "apps are bundled" rule stated in root CLAUDE.md line 19
- Identified `use-gunshi-cli` skill has **Cursor-style frontmatter** (`globs`, `alwaysApply`) — will be partially ignored by Claude's skill loader
- Identified `.claude/commands/reduce-similarities.md` as **legacy-form** (should migrate to skills)
- Identified **`tsgo`** (Microsoft Go-port of tsc) as the typechecker — cutting-edge
- Identified **in-source tests** via `import.meta.vitest` guard — no `*.test.ts` files exist
- Identified AGENTS.md symlink pattern — dual-naming for Codex compatibility
- Explicit "what init would DAMAGE" section listing 8 specific destruction points

**Config-generator behavior** (this is the critical data point):

Config-generator **correctly refused to write anything.** Quoted from its response:

> "The SKILL contract I was dispatched under has one critical rule that dominates here: Never overwrite existing CLAUDE.md — If one exists, inform the init command. The init command will have already handled this (redirecting to update or getting user permission). That precondition was not satisfied — I was dispatched directly with source: 'test-run', bypassing the /onboard:init guard that's supposed to detect pre-existing tooling and route to /onboard:update."

Generator-self-preservation confirmed: read 3 files (`.claude/settings.json`, `.mcp.json`, first 50 lines of CLAUDE.md), listed `.claude/` tree, wrote zero files, surfaced the right recommendation.

**Preservation audit** (all 4 pre-existing `.claude/` files + CLAUDE.md still present, unchanged):
- `.claude/settings.json` — unchanged
- `.claude/skills/byethrow/SKILL.md` — unchanged
- `.claude/skills/use-gunshi-cli/SKILL.md` — unchanged
- `.claude/commands/reduce-similarities.md` — unchanged
- `CLAUDE.md` at root — **310 lines, no onboard header** (correctly untouched)
- 9 per-package CLAUDE.md — unchanged

**Verdict:** generator has sensible self-preservation. However, the refusal was via the generator's own judgment — not a hard pre-flight guard. This is good enough for protection but surfaces a real gap in the dispatch contract (see GAP-TT-005).

---

## New gaps

### GAP-TT-004 — Sync-check for stale timestamps + versions in default generation header (P1, S)

**Observation:** Every generated artifact opens with `<!-- onboard v0.1.0 | Generated: 2026-04-21 -->` — but today is 2026-04-22, and I've seen `v0.1.0` in the header across all targets even as the underlying onboard plugin is at v1.10.0. The header's version number appears to be a generator-internal default, not onboard's real semver.

**Impact:** Future `/onboard:update` runs that diff against the header to detect "was this generated by onboard?" will fail. Also confusing for users who see "v0.1.0" and assume the tool is pre-release.

**Fix:** read the onboard plugin version from `onboard/.claude-plugin/plugin.json` at generation time; use current UTC date. Surface in a shared header template.

**Priority:** P1. **Size:** S (half-day).

---

### GAP-TT-005 — No pre-flight guard in programmatic dispatch path (P1, M)

**Observation:** When config-generator is invoked directly (via the `Agent` tool with `subagent_type: onboard:config-generator` or from the `generate` skill), there's no hard guard against pre-existing tooling. The ccusage test **survived only because the generator exercised its own judgment** after reading the SKILL contract and filesystem.

A hypothetical caller that passes a more aggressive prompt ("ignore existing files, overwrite everything") could override that judgment. The protection is soft, not structural.

**Impact:** Third-party callers (like forge) that dispatch `onboard:generate` with their own callerExtras could skip this check if their prompt is careless. Currently the only hard guard is inside the `/onboard:init` skill, which isn't on the dispatch path for programmatic callers.

**Fix:** add a deterministic pre-flight step to the `generate` skill (and/or config-generator agent) that:
1. Globs for `CLAUDE.md`, `.claude/settings.json`, `.claude/skills/*`, `.claude/agents/*`, `.mcp.json`
2. If any exist AND don't contain the onboard header, set `dispatchedMode: "preserve"` automatically
3. In preserve mode, refuse to write unless the caller passed `callerExtras.mode: "init-overwrite-confirmed"`
4. Record `mode: "refused"` as a first-class outcome in `onboard-meta.json` (currently only `emitted` / `skipped` exist — add `refused`)

**Priority:** P1. **Size:** M (1-2 days).

---

### GAP-TT-006 — Bundled scripts (analyze-structure, detect-stack, measure-complexity) severely under-deliver on all 5 stacks (P1, L)

**Consolidated observation** — the analyzer agent's per-target "what the scripts missed" lists total:

| Target | Script failures (count) | Examples |
|---|---|---|
| sqlmodel | 9 | Missed uv, ty, prek, fastapi-is-test-dep, tutorial-test pattern, 99% coverage gate, Python version floor |
| gin | 6 | Missed Go build tags, module path, 99% codecov gate, benchmark count, CI matrix strategy, Go version floor |
| create-t3-app | 12 | Missed per-workspace deps, monorepo members, Turbo v1-vs-v2, template underscore convention, changesets ignore, Tailwind version split |
| shadcn-ui | 20 | All of the above + registry-as-product, base/radix duality, MCP-inside-CLI, OIDC publishing |
| ccusage | 5 | Missed tsdown, tsgo, in-source tests, catalog-strict, AGENTS.md symlinks |

**Cumulative: 52 documented misses across 5 targets.** The analyzer agent catches all of them via LLM reading, but this is slow + expensive + not cached. The scripts are supposed to be the cheap first pass.

**Impact:** Every onboard run pays the full "LLM reads everything" cost because the scripts are too shallow. If we could move even 20% of these detections into scripts, the analyzer's job would be faster + more focused.

**Fix:** prioritized script improvements:
- `detect-stack.sh`: glob all `package.json` files in pnpm-workspace / turbo repos (not just root); parse TOML `[project] dependencies` + `[dependency-groups]`; scan `//go:build` tags in `.go` files; recognize uv.lock / bun.lockb / pnpm-workspace.yaml and extract workspace globs.
- `analyze-structure.sh`: filter `.git/` from directory count; detect bin entries in package.json; detect symlinks (AGENTS.md); detect underscore-prefixed convention files.
- `measure-complexity.sh`: parse TOML for Python dep count; parse go.mod for Go dep count; flag "tests > source LOC by 2x" as a signal.

**Priority:** P1. **Size:** L (3+ days — multiple scripts, multiple stacks).

---

### GAP-TT-007 — Maintenance-header boilerplate now confirmed across all targets (P1, XS)

Originally flagged in got's report (GAP-TT-002). Reconfirmed: every single artifact across all 5 targets opens with the same 8-line maintenance block. With sqlmodel/gin/create-t3-app/shadcn-ui totaling 70+ generated files, that's ~560 lines of pure duplication.

**Fix unchanged from GAP-TT-002:** collapse to one line per file, put the full block once in root CLAUDE.md.

**Priority:** P1. **Size:** XS.

---

### GAP-TT-008 — Self-audit doesn't detect "generator wrote nothing" (P2, S)

**Observation:** ccusage test — the generator correctly wrote zero files. But the response still says "Phase 7 telemetry audit passed" when audited semantics suggest nothing was emitted. The audit passes because `{mcpStatus: "skipped", outputStyleStatus: "skipped", ...}` are all valid enum values — but the top-level outcome (nothing happened, by choice) isn't cleanly representable.

**Impact:** Low today. But if we want tooling on top of `onboard-meta.json` (CI checks, evolution state), needing a "refused" first-class outcome becomes important.

**Fix:** add `outcome: "refused" | "emitted" | "partial"` top-level field to `onboard-meta.json`. Wire audit to require this field.

**Priority:** P2. **Size:** S.

---

## GAP-TT-001/002/003 update

Baseline gaps from got's report — status after this batch:

| ID | Original finding | This batch status |
|---|---|---|
| GAP-TT-001 | Hook env var `$CLAUDE_TOOL_FILE` hallucinated | **Reproducible when prompt doesn't cite hooks-guide.md** (see matrix). Fix is prompt-scaffolding, not code. |
| GAP-TT-002 | Repeated maintenance header boilerplate | Confirmed across all 5 targets. See GAP-TT-007. |
| GAP-TT-003 | Self-audit is structural-only, doesn't catch semantic bugs | Still applicable. See GAP-TT-008. |

---

## Coverage matrix

What we've now tested vs what remains:

| Dimension | Covered | Examples |
|---|---|---|
| Language: TypeScript | ✅ | got, create-t3-app, shadcn-ui, ccusage |
| Language: Python | ✅ | sqlmodel |
| Language: Go | ✅ | gin |
| Language: Rust | ❌ | none tested |
| Language: Java/JVM | ❌ | none tested |
| Language: Ruby | ❌ | none tested |
| Project: Library | ✅ | got, sqlmodel |
| Project: Framework | ✅ | gin |
| Project: CLI | ✅ | create-t3-app, shadcn-ui, ccusage |
| Project: App | ❌ | partial via create-t3-app/www, shadcn-ui/apps/v4 |
| Monorepo: pnpm | ✅ | create-t3-app, shadcn-ui, ccusage |
| Monorepo: nx/turbo | ✅ | create-t3-app (turbo v1), shadcn-ui (turbo v1) |
| Monorepo: Go (with replace) | ❌ | not tested |
| Monorepo: Python (with uv workspaces) | ❌ | not tested |
| Package manager: npm | ❌ | not tested directly |
| Package manager: pnpm | ✅ | 3 targets |
| Package manager: yarn | ❌ | not tested |
| Package manager: bun | ❌ | not tested directly |
| Package manager: uv | ✅ | sqlmodel |
| Package manager: go mod | ✅ | gin |
| Existing CLAUDE.md | ✅ | ccusage (10 files) |
| Distributed AI tooling in tree | ✅ | shadcn-ui |
| Fresh init path | ✅ | got, sqlmodel, gin, create-t3-app, shadcn-ui |
| Update path | ❌ | only tested refusal — not tested `/onboard:update` positive flow |
| Security-sensitive stack | ❌ | auth/crypto-heavy project not tested |

**Remaining dimensions worth testing:**
- A Rust project (cargo, workspace variant)
- A Python poetry project (for contrast with sqlmodel's uv+pdm-backend)
- A project with ruby bundler / rails
- A project with yarn berry / pnp
- An actual `/onboard:update` run (this batch only tested the generator's refusal)

---

## Recommendations (post-batch fix sprint)

**Do first (one week):**

1. **GAP-TT-001** — bake the stdin-JSON hooks pattern into the default generation prompt template. Unblocks every user. XS code change, significant value.
2. **GAP-TT-005** — implement the pre-flight guard at generate-skill level. Structural protection for programmatic callers. M but critical.
3. **GAP-TT-007** (ne GAP-TT-002) — collapse maintenance header to one line per file, put full block in root CLAUDE.md. XS.

**Do next (two weeks):**

4. **GAP-TT-003 / GAP-TT-008** — add semantic smoke suite to `generate` skill: hook commands parse sample payloads, rule paths match real files, skill/agent YAML valid, `outcome` field in meta.json.
5. **GAP-TT-006** — boost bundled scripts. Target the high-value misses first: per-workspace package.json scan, go.mod version floor, pyproject `[dependency-groups]` support, detect AGENTS.md symlinks.
6. **GAP-TT-004** — dynamic version + date in maintenance header.

**Defer:**

- Adding support for untested language families (Rust, JVM, Ruby) — revisit after 5 additional target-tests on these stacks.
- `/onboard:update` positive-flow testing — separate target-test pass.

---

## What this batch did not test

- `/onboard:update` executing and applying drift fixes (ccusage was the perfect candidate; only tested generator refusal)
- `/onboard:evolve` drift detection (no post-generation code changes made)
- Enriched tier (CI/CD, harness, evolution hooks, sprint contracts, teams, verification) — deliberately skipped for Core-only baseline
- Plugin-aware generation (`callerExtras.coveredCapabilities` passed empty in every run)
- Forge integration path (forge dispatches `onboard:generate` — untested in this batch)
- Any non-English codebase (directory/variable names)
- Large-binary inclusion (proto files, embedded images beyond normal)

Each remains a candidate for a future target-test pass.

---

## Artifacts (all local)

- sqlmodel: `~/tmp/onboard-test/sqlmodel/.claude/` + `CLAUDE.md`
- gin: `~/tmp/onboard-test/gin/.claude/` + `CLAUDE.md` + `.mcp.json`
- create-t3-app: `~/tmp/onboard-test/create-t3-app/.claude/` + 3× `CLAUDE.md` + `.mcp.json`
- shadcn-ui: `~/tmp/onboard-test/ui/.claude/` + 3× `CLAUDE.md` + `.mcp.json` (4 user-owned files preserved)
- ccusage: nothing generated (correctly refused)

Safe to `rm -rf ~/tmp/onboard-test/` after review — no repo impact.
