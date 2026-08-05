# Generate — qualityGates semantics, emission disable flags, telemetry status enum

Detail extracted from the `generate` skill's Step 1 (Read Context Input). The generate skill cites this file for the `qualityGates` emission semantics, the two emission disable-flag families, the telemetry status enum, and the per-entry hook-type skip-reason table. The caller-parsed contract strings (the dispatch contract, the three reject errors, and the Step-5 response shape) stay inline in the skill.

## qualityGates semantics

Full per-event spec in `../../generation/SKILL.md`.

- `mode: "blocking"` → generated hook script exits 2 with stderr feedback. Claude cannot proceed without addressing the block. Default for `preCommit`.
- `mode: "advisory"` → generated hook script exits 0 with stdout. Claude sees the message and continues. Default for everything else.
- **autonomyLevel downgrade**: callers are expected to downgrade `preCommit[].mode` to `"advisory"` when `wizardAnswers.autonomyLevel === "always-ask"`. Onboard honors whatever mode it receives — it does not second-guess the caller's autonomy derivation.
- **Plugin availability**: onboard checks that each referenced skill's plugin is in `installedPlugins` before writing a hook entry. Missing → entry is dropped + warning recorded in `onboard-meta.json`.
- **Advanced event fields** (`sessionEnd`, `userPromptSubmit`, `preCompact`, `subagentStart`, `taskCreated`, `taskCompleted`, `fileChanged`, `configChange`, `elicitation`) are all optional. Each accepts either an explicit array or is inferred from wizard answers and analyzer signals — see `../../generation/references/emission/hooks-generation.md` § Advanced Event Hooks for the per-event inference rules. Matcher-incompatible events (see `../../generation/references/guides/hooks-guide.md` § Matcher Compatibility) must have no `matcher` field in the generated settings entry regardless of what the caller passes.
- **Hook type selection** (per-entry `hookType` + aux fields — specified in `../../generation/references/emission/hooks-generation.md` § Hook Type Validation) is optional on every entry. Absent → per-event default applies (see `../../generation/references/emission/hooks-generation.md` § Advanced Event Hooks § Per-event defaults). The 10 validation rules in `../../generation/references/emission/hooks-generation.md` § Hook Type Validation drop invalid entries with a structured `skipped` reason — they never fail the whole generation.
- **HTTP opt-in**: `callerExtras.allowHttpHooks` must be `true` for any `hookType: "http"` entry to be emitted. Omitting it (or setting `false`) causes http entries to be skipped with reason `http-not-opted-in`. Non-https URLs are always refused with reason `insecure-http-url`.

**Backward compat**: `callerExtras.qualityGates`, `phaseSkills`, `allowPluginReferences`, and `allowHttpHooks` are all optional. Callers that omit them get the pre-upgrade behavior (no quality-gate hooks, no Plugin Integration section, no plugin cross-references in rules, no http hooks). Callers that pass the legacy 4-field `qualityGates` shape (only `sessionStart` / `preCommit` / `featureStart` / `postFeature`) also get pre-upgrade behavior for the advanced event fields — they fall through to the inference rules in `../../generation/SKILL.md`. Callers that omit the new per-entry `hookType`/aux fields get `command`-type output identical to pre-upgrade behavior (every current fixture remains byte-identical).

## Default behavior matrix — emission disable flags

There are **two distinct families** of `callerExtras` disable flags. They MUST NOT be conflated in implementation. Treating them identically is the bug that caused MCP, output-style, LSP, built-in skills, and snapshots to disappear from non-interactive runs in the 2026-04-16 release-gate test.

| Flag | Family | Effect when `true` | Telemetry written | Artifacts written |
|---|---|---|---|---|
| `disableMCP` | **SKIP-PHASE** | Skip emission Step 1 entirely | `mcpStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [], skipped: [...] }` | None |
| `disableLSP` | **SKIP-PHASE** | Skip emission Step 3 entirely | `lspStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [], skipped: [...] }` | None |
| `disableBuiltInSkills` | **SKIP-PHASE** | Skip emission Step 4 entirely | `builtInSkillsStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [], skipped: [...] }` | None |
| `disableSkillTuning` | **SUPPRESS-PROMPT** | Skip per-skill batched confirmation only | `skillStatus: { status: "emitted", source: "inferred", ... }` | Skill files + `onboard-skill-snapshot.json` |
| `disableAgentTuning` | **SUPPRESS-PROMPT** | Skip per-agent batched confirmation only | `agentStatus: { status: "emitted", source: "inferred", ... }` | Agent files (with YAML frontmatter) + `onboard-agent-snapshot.json` |
| `disableOutputStyleTuning` | **SUPPRESS-PROMPT** | Skip emission Step 2 batched confirmation only | `outputStyleStatus: { status: "emitted", source: "inferred", ... }` | Output style file + `onboard-output-style-snapshot.json` |

**Telemetry status enum** (used in every emission status object):

| Value | Meaning |
|---|---|
| `"emitted"` | Phase ran, artifacts written, snapshot recorded. |
| `"documented"` | Phase ran, guidance was written INTO an existing artifact (e.g., a CLAUDE.md subsection) rather than as a separate file + snapshot. Used by emission Step 4 (built-in skills) whose "artifact" is documentation-only by design. Semantically distinct from `"emitted"` (new file) and `"skipped"` (phase did not run). |
| `"skipped"` | Phase intentionally skipped (caller flag, no signal, no candidates, stub mode). Telemetry still recorded so verify scripts can distinguish "intentional skip" from "silent bug". |
| `"declined"` | User explicitly declined in interactive flow (wizard answered "no" / empty array). |
| `"failed"` | Phase attempted but failed (e.g., script crash, write error). Triggers warning in `warnings[]` but never aborts the run. |

**Hard rule** (load-bearing): EVERY emission block MUST emit its telemetry status key in `onboard-meta.json`, even when status is `"skipped"`. Missing keys are bugs, not absences. The `config-generator` agent's pre-exit self-audit verifies all four keys (`mcpStatus`, `outputStyleStatus`, `lspStatus`, `builtInSkillsStatus`) exist before returning. See `../../generation/SKILL.md` emission blocks for the per-phase Path A/B/C firing logic that ensures this invariant holds whether wizard answers are present, absent, or the SUPPRESS-PROMPT-ONLY flags are set.

## Hook Type skip reasons

Per-entry hook-type validation is applied during generation, not at Step 1. Each `callerExtras.qualityGates.<event>[]` entry passes through the 10-rule validator in `../../generation/references/emission/hooks-generation.md` § Hook Type Validation. Validation failures drop the offending entry and record a `skipped[]` entry with a structured reason; they never fail the overall generation. The complete skip-reason table (for authoritative reference):

| Skip reason | Condition |
|---|---|
| `missing-prompt-source` | `hookType="prompt"` but neither `promptRef` nor `promptInline` supplied |
| `ambiguous-prompt-source` | `hookType="prompt"` with BOTH `promptRef` AND `promptInline` |
| `prompt-file-not-found` | `hookType="prompt"` + `promptRef` points to non-existent file |
| `missing-agentRef` | `hookType="agent"` but `agentRef` is absent or empty |
| `missing-httpUrl` | `hookType="http"` but `httpUrl` is absent or empty |
| `unsupported-type-for-event` | `hookType ∈ {prompt, agent}` on `PreToolUse` or `PostToolUse` event |
| `http-not-opted-in` | `hookType="http"` without `callerExtras.allowHttpHooks === true` |
| `insecure-http-url` | `hookType="http"` with URL that does not start with `https://` |
| `agent-not-found` | `hookType="agent"` + `agentRef` referencing an agent whose plugin is not in `effectivePlugins` |
| `invalid-timeout` | `timeout` field present but not a positive integer |
| `high-frequency-event-unsuitable-for-agent` | `hookType="agent"` on `UserPromptSubmit` (fires on every prompt — agent latency makes it unusable) |
