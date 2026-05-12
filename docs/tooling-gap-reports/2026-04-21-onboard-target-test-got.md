# Onboard Target-Test Gap Report — `sindresorhus/got` (2026-04-21)

## Summary

One-off manual test running `/onboard:init` (via the underlying `codebase-analyzer` and `config-generator` agents) against a real third-party OSS codebase — `sindresorhus/got` v15.0.3, a TypeScript HTTP client library with no prior Claude tooling. Purpose: reality-check whether onboard's generation is genuinely project-tailored or template boilerplate, and surface concrete quality gaps for the next sprint.

**Bottom line:** the analyzer and generator both deliver legitimate project-specific output — deep reading, honest conventions, no template fluff. But one real bug (wrong hook env var) will silently break every auto-format / auto-typecheck hook onboard generates. Two smaller polish issues round out the punch list.

## Test setup

| Field | Value |
|---|---|
| Target repo | `sindresorhus/got` @ latest (commit `e9489c1`, v15.0.3) |
| Clone path | `/Users/apurvbazari/tmp/onboard-test/got` |
| Shape | 120 files, ~32K LOC TS, 35 ava tests, pure ESM, Node ≥22, no prior CLAUDE.md |
| Preset | Standard |
| Autonomy | guided |
| Enriched flags | all false (Core-only) |
| Installed plugins | none |
| Invocation | `codebase-analyzer` agent → `config-generator` agent (bypassing the interactive wizard since `onboard:init` is `disable-model-invocation: true`) |

Generated artifacts (12 files, 808 LOC total):

```
CLAUDE.md                                    (122 lines)
.claude/rules/source-imports.md              ( 48 lines)
.claude/rules/no-runtime-logging.md          ( 50 lines)
.claude/rules/tests-ava-patterns.md          ( 74 lines)
.claude/rules/public-api-boundary.md         ( 70 lines)
.claude/rules/pr-checklist.md                ( 45 lines)
.claude/skills/write-ava-test/SKILL.md       ( 90 lines)
.claude/skills/write-ava-test/references/why-no-nock.md
.claude/skills/add-got-option/SKILL.md       ( 94 lines)
.claude/agents/api-surface-reviewer.md       (105 lines)
.claude/agents/test-writer.md                (110 lines)
.claude/settings.json                        ( 24 lines)
.claude/onboard-meta.json
```

Existing `.github/PULL_REQUEST_TEMPLATE.md` correctly preserved (not overwritten).

## What worked

### 1. Analyzer beats the Phase 1 scripts by a wide margin

The three bundled scripts (`analyze-structure.sh`, `detect-stack.sh`, `measure-complexity.sh`) missed nearly everything important when run directly. The `codebase-analyzer` agent caught all of it.

| Claim | Scripts | Agent |
|---|---|---|
| Framework | Flagged `Express ^5.2.1` as the framework (wrong — devDep only) | Correctly: no framework; got *is* the HTTP client |
| Test files | "0 test files" | 35 ava entry files + 7 helpers + 3 type-only |
| Test framework | (not detected) | ava + tsx/esm loader, 969 test() invocations, 52 test.serial |
| Linter/formatter | (not detected) | xo (combined ESLint+Prettier), 15 load-bearing rule overrides |
| TS config | (not read) | Extends `@sindresorhus/tsconfig` strict preset; 5 local overrides enumerated |
| Project-specific lore | — | Found "never use nock" rule in `maintainer.md` with the MSW-interceptor + `workerThreads: false` rationale |
| Observability | — | `node:diagnostics_channel` publish-side — library writes zero runtime logs |
| Error contract | — | Enumerated the 8 stable `code` strings (`ERR_GOT_REQUEST_ERROR`, `ERR_TOO_MANY_REDIRECTS`, etc.) |
| Model recommendation | — | Opus for `options.ts` / `core/index.ts` state machines; Sonnet elsewhere; Haiku not recommended due to type-fest generics |

If onboard ran on scripts alone, the output would be mediocre. The analyzer is where deep value happens.

### 2. Generated artifacts are project-specific, not boilerplate

Spot-checked every artifact. No "this project uses TypeScript" fluff. Concrete examples:

- **CLAUDE.md leads with** "`got` is a published npm **library** — ... It is NOT an application, NOT a framework user, and NOT a server." — precisely the framing that avoids the downstream errors a template would make.
- **Non-negotiable guards** are numbered and specific: nock ban with mechanism, `.js`-extension-in-TS-imports NodeNext quirk, tabs-not-spaces from `.editorconfig`, `.npmrc` disables lockfile, 15 xo rule overrides are load-bearing.
- **`tests-ava-patterns.md` rule** encodes the exact macro signature (`test('name', withServer, async (t, server, got) => ...)`), explains why `workerThreads: false` + single-process makes nock catastrophic, lists the 5 macro variants (`withServer`, `withHttpsServer`, `withBodyParsingServer`, `withServerAndFakeTimers`, `withSocketServer`) with when to use each.
- **`write-ava-test` skill** is 8 actionable steps with correct assertion style (`t.throwsAsync` + `error.code`, not `error.message` because messages shift freely) and common pitfalls (forgetting `.js`, registering routes after request, writing in a subdir).
- **`api-surface-reviewer` agent** is read-only (`disallowedTools: Write, Edit`, `permissionMode: readOnly`), narrowly scoped to the 7 public API files, explicitly enumerates all 8 stable error codes for audit, opus + high effort + isolated + red color — all correct choices.

### 3. Scope discipline

808 LOC across 12 files for a Core-only Standard preset on a medium-complexity library. Not bloated. Not minimal. Correct default.

### 4. Respect for existing artifacts

Did not overwrite `.github/PULL_REQUEST_TEMPLATE.md`. Generated a `pr-checklist.md` rule (drafting guidance only) instead. Correct restraint.

## Gaps

### P0 — GAP-TT-001 — Hook command uses non-existent env var (breaks silently)

**File:** `.claude/settings.json` (generated by `config-generator` via `generation/references/hooks-guide.md` guidance).

**What the generator wrote:**

```bash
if [[ "$CLAUDE_TOOL_FILE" == *.ts || "$CLAUDE_TOOL_FILE" == *.js ]] && ...
```

**What Claude Code actually provides:** PostToolUse hooks receive a JSON payload on **stdin**, not env vars. The correct pattern is documented in onboard's own guide at `onboard/skills/generation/references/hooks-guide.md`:

```bash
file=$(cat - | jq -r '.tool_input.file_path' 2>/dev/null || \
       cat - | grep -o '"file_path": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
```

**Impact:** `$CLAUDE_TOOL_FILE` is always empty. Every test inside the `if` branch fails. **Net result: the `npx xo --fix` and `npx tsc --noEmit` hooks silently no-op on every edit.** The user believes they have auto-format + auto-typecheck. They have neither. They'll ship lint failures and not know why until CI catches it.

This is the worst class of bug: generated tooling that looks correct but doesn't run.

**Root cause:** `config-generator` hallucinated an env var name instead of following its own `hooks-guide.md`. The self-audit (Phase 7 telemetry check) validated JSON structure but not command semantics, so it passed.

**Fix (P0):**

1. Add a generator-side template for PostToolUse format/lint hooks that uses the stdin-JSON pattern from `hooks-guide.md` directly. Do not let the agent synthesize the command from scratch.
2. Add an output-validation step in the `generate` skill: after writing `settings.json`, spawn a sample PostToolUse payload (JSON with `tool_input.file_path`) through each generated hook command in a dry-run mode and confirm the command parses the file path. Fail the generation if it doesn't.
3. Regression fixture: check in a snapshot test that runs the generator against a known project and verifies the `settings.json` hook commands match the canonical pattern.

**Priority:** P0 — generated tooling is visibly broken for every onboard-created project that enables PostToolUse hooks.
**Size:** S (half-day).

---

### P1 — GAP-TT-002 — Repeated maintenance-header boilerplate

**Observation:** Every generated artifact opens with an 8-line maintenance comment:

```
<!-- onboard v0.1.0 | Generated: 2026-04-21 -->
<!-- MAINTENANCE: Claude, while working in this codebase, if you notice that:
     - The patterns described here no longer match the actual code
     - New conventions have emerged that aren't captured here
     - The project structure has changed in ways that affect these rules
     - Code changes you're currently making should also update this file
     Notify the developer in the terminal that this file may need updating.
     Suggest running /onboard:update to refresh the tooling configuration. -->
```

Repeated verbatim across 9 artifact files. That's ~72 lines of pure comment boilerplate in a 808-line artifact set — ~9% overhead, pure duplication.

**Impact:** Low functional impact (Claude reads them). But artifacts look noisier, the info is diluted, and onboarding users seeing their first CLAUDE.md notice the redundancy.

**Fix:**

- Put the maintenance note **once** in root CLAUDE.md.
- Per-artifact header reduces to a single line: `<!-- onboard v0.1.0 | Generated: 2026-04-21 | see CLAUDE.md §Maintenance -->`.

**Priority:** P1 — cosmetic but hurts perceived output quality.
**Size:** XS (< 1 hour).

---

### P1 — GAP-TT-003 — Self-audit doesn't catch semantic failures

**Observation:** The `config-generator` Phase 7 self-audit passed ("Audit passes. All Phase 7 telemetry keys present with valid `skipped` enum values. Both agent files have valid YAML frontmatter."). Meanwhile GAP-TT-001 ships broken hooks.

**Gap:** The self-audit is a structural/keys check — it validates JSON shape, YAML frontmatter presence, line count ranges. It doesn't validate:

- Whether hook commands parse the intended input
- Whether `paths:` frontmatter in rules matches real project files
- Whether skill/agent YAML required fields are complete (e.g., `description` being present is checked, but not whether it's project-specific vs. boilerplate)
- Whether referenced files (in skill references, agent boundary rules) actually exist post-generation

**Impact:** Without semantic validation, any generator bug downstream of the structural contract (the exact class GAP-TT-001 falls into) will ship unnoticed. The self-audit gives false confidence.

**Fix:**

- Add a `post-generation smoke suite` step to the `generate` skill. Runs *after* the config-generator writes files, *before* reporting success. Checks:
  - Every `settings.json` hook command runs end-to-end with a sample payload without erroring
  - Every rule's `paths:` matches ≥1 real file in the target project
  - Every agent's `disallowedTools` / `tools` field references valid tool names
  - Every skill's `references/*.md` links resolve to existing files
- If any smoke check fails, the generator re-plans that artifact or surfaces the failure instead of claiming success.

**Priority:** P1 — foundational. Fixes this one and it catches entire bug classes.
**Size:** M (1-2 days).

---

## Anthropic surface coverage (informal)

Not an automated surface audit — this is a target-run report. No baseline comparison against Anthropic docs. See regular `<YYYY-MM-DD>-gap-report.md` files for that.

## Recommendations

Priority order for the next onboard sprint:

1. **Fix GAP-TT-001 now.** Unblocks every user of onboard-generated hooks. One-line template fix + regression test.
2. **Add the post-generation smoke suite (GAP-TT-003).** This is the single highest-leverage investment — it catches bug classes like GAP-TT-001 automatically instead of relying on manual target-runs like this one.
3. **Re-run this target-test against 5 more repos.** One data point (got) is not enough. Recommended targets spanning stacks:
   - A Next.js app (e.g., `vercel/commerce` or `shadcn-ui/taxonomy`)
   - A Python/FastAPI service
   - A Go service (single binary)
   - A monorepo (pnpm workspaces or turborepo)
   - A project with an existing CLAUDE.md (tests `/onboard:update`, not `init`)
4. **Collapse the maintenance header boilerplate (GAP-TT-002).** Easy polish.

## What this run *did not* test

- `/onboard:evolve` — drift detection wasn't exercised (would require modifying got and re-running)
- The interactive wizard (`/onboard:init` direct) — bypassed because it's `disable-model-invocation: true`
- Enriched tier (CI/CD, harness, evolution hooks, sprint contracts, teams, verification) — deliberately skipped for a cleaner baseline
- Plugin-aware generation with `coveredCapabilities` — target had no installed plugins
- Monorepo handling — got is single-package

Each of these is a separate target-test to run later.

## Artifacts

Generated output left in place at `/Users/apurvbazari/tmp/onboard-test/got/`. Safe to inspect or delete.
