# Empty-Repo Stub Procedure

Canonical procedure for detecting an empty repository and generating a minimal, canonical-shape `.claude/` stub when `/onboard:start` runs on a repo with no source code. This reference is the **single source** for Phase 0 behavior — the detection filter, the prior-stub re-run check, the 3-option menu, and each option's execute path all live here; `../SKILL.md` § Phase 0 (Empty-Repo Guard) is a thin pointer into this procedure.

## Why this reference exists

Before Cluster 2 (2026-04-18), `/onboard:start` on an empty repo was intercepted by Claude *before* entering the start skill. Claude improvised a 3-option menu and emitted 3 files ad-hoc. The stub had four problems (2026-04-17 release-gate findings B14, B15, B16):

- **B14**: `onboard-meta.json` used a 4th distinct schema with zero top-level keys in common with the canonical shape. Downstream consumers (verify scripts, `/onboard:update`, `/onboard:evolve`) couldn't reason about it.
- **B15**: The stub hardcoded `version: "1.0.0"` regardless of installed onboard version.
- **B16**: The start skill's own empty-path behavior was never tested because the skill never ran for empty repos.

This procedure closes all three by moving the logic INTO the start skill's Phase 0 boundary — consolidated here as the single canonical procedure — and prescribing the exact canonical-shape output.

## Detect empty repository

Runs at the top of `../SKILL.md` § Phase 0, before Phase 1 Recon. Count source-code files (exclude `.git/`, dotfiles, `README*`, `LICENSE*`, `.gitignore`):

```bash
SRC_COUNT=$(find . -type f \
  -not -path './.git/*' \
  -not -name '.*' \
  -not -name 'README*' \
  -not -name 'LICENSE*' \
  | wc -l | tr -d ' ')
```

- `SRC_COUNT > 0` → source code exists → **skip Phase 0 entirely**, fall through to Phase 1 Recon. Most common case.
- `SRC_COUNT == 0` → empty repo → proceed to the prior-stub check below.

## Detect prior stub (re-run on an empty dir)

If `.claude/onboard-meta.json` already exists AND `jq -r '.mode // empty'` returns `"stub-empty-repo"` AND `SRC_COUNT == 0` (the developer ran start twice on a still-empty dir): default to no-op — inform the developer a stub already exists, skip re-write. See § Edge cases 1 below for the full re-entry matrix, including the `SRC_COUNT > 0` case.

(When source code has since been added, `SRC_COUNT > 0` short-circuits the detection step above and the full flow runs — Recon → Research → Grounded Wizard → Plan → **hard gate** → Generation — overwriting the stub artifacts. There is no separate promotion branch.)

## Present the 3-option menu

For empty repos without a prior stub, use `AskUserQuestion` (single-select, header: `"Empty repo"`):

> This repository has no source code yet. How would you like to proceed?
>
> - **Abort** — stop here. Add source code first, then re-run `/onboard:start`.
> - **Placeholder only** — write a minimal CLAUDE.md placeholder (no `.claude/` directory). Useful if you want to set up Claude context before the code exists but don't want a formal tooling setup.
> - **Generate canonical stub** (default) — create CLAUDE.md, `.claude/settings.json`, and `.claude/onboard-meta.json` in canonical schema with stub-mode markers. Re-run `/onboard:start` later to upgrade to full tooling.

Default: **Generate canonical stub**.

**Single-option guard** (per `.claude/rules/ask-user-question-guard.md`): the menu has 3 options → no guard needed.

## Execute the selected path

- **Abort** → stop the skill. No files written.
- **Placeholder only** → write CLAUDE.md with the placeholder content from § Output artifacts below but SKIP the `.claude/` directory. Return minimal handoff. Do not proceed to further phases.
- **Generate canonical stub** (default) → continue with the rest of this procedure: the 3 files (§ Output artifacts), the canonical `onboard-meta.json` schema with all 7 generation-phase status keys set to `status: "skipped"` + `reason: "stub-mode-no-code"`, dynamic `pluginVersion` resolution (no hardcoded literals), and the 3-file atomic write order (§ Write order).

After either stub path completes, run a minimal handoff (§ Post-write handoff below) and return to `../SKILL.md` — do NOT continue to Phase 1 Recon. The stub paths never reach `../SKILL.md` § Step 0, so no task list is created for a stub run.

## Invocation

Called from `../SKILL.md` § Phase 0 Empty-Repo Guard, after:

1. The guard detected no source files (`SRC_COUNT == 0`, § Detect empty repository above)
2. The developer selected option 3 ("Generate canonical stub") from the § Present the 3-option menu above
3. The developer has been told what will happen next

Do NOT invoke this procedure from any other context — the Phase 0 guard is the only legitimate entry point.

## Output artifacts

Exactly 3 files land on disk. All paths relative to the project root.

### 1. `CLAUDE.md` (project root)

A minimal placeholder CLAUDE.md with every section marked as pending. Clear status banner explaining this is a stub and what to do next.

```markdown
<!-- onboard:maintained version=<dynamic> generated=<ISO-date> -->

# <project-name> — Stub configuration

> **Status**: Stub configuration generated for an empty repository. Re-run `/onboard:start` after scaffolding to produce the full AI tooling setup.
>
> **Status**: Stub configuration generated for an empty repository. Add source code, then re-run `/onboard:start` to produce the full AI tooling setup.

## Project overview

**Tech stack**: _To be detected after scaffolding._

**Project structure**: _To be captured once a layout exists._

**Primary tasks**: _To be determined based on project type._

## Working notes for Claude

While this project is empty:

- Ask clarifying questions before creating files — don't invent a stack or framework
- Confirm file locations before writing (the layout is unsettled)
- Re-run `/onboard:start` after at least one source file exists, so the full analysis + wizard can run

## Next steps

1. Add source code
2. Re-run `/onboard:start` to produce the full tooling setup
3. Once tooling is generated, the `## Working notes for Claude` section above will be replaced with the project-specific setup.

<!-- onboard:maintenance-end -->
```

Use the project's directory name as `<project-name>` (`$(basename "$PWD")`). Replace `<dynamic>` with the resolved plugin version (see § Dynamic version resolution below). Replace `<ISO-date>` with the current UTC date in `YYYY-MM-DD` format.

### 2. `.claude/settings.json`

Minimal valid JSON with no hooks wired in. The file exists so session-start doesn't error on missing settings:

```json
{
  "hooks": {}
}
```

Create the `.claude/` directory if absent. Do not add placeholder hooks — they would fire with no backing scripts and surface misleading errors.

### 3. `.claude/onboard-meta.json` — canonical-shape stub

**The load-bearing artifact.** Every top-level key matches the canonical schema so downstream consumers don't need stub-mode branching. All 7 generation-phase status blocks emit `status: "skipped"` with a stub-specific reason. `wizardStatus` follows the canonical 5-subkey shape (see `../../wizard/SKILL.md § Key Rule 7`).

```jsonc
{
  "pluginVersion": "<dynamic>",
  "_generated": { "by": "onboard", "version": "<dynamic>", "date": "<ISO-date>" },
  "timestamp": "<ISO-8601 UTC timestamp>",
  "source": "onboard:start",
  "mode": "stub-empty-repo",

  "wizardAnswers": {},
  "wizardStatus": {
    "presetUsed": "stub-empty-repo",
    "exchangesUsed": 0,
    "phasesAsked": [],
    "phasesSkipped": [
      "phase0", "phase1", "phase2", "phase3",
      "phase4", "phase5", "phase5.0", "phase5.1", "phase5.1.1",
      "phase5.2", "phase5.3", "phase5.4", "phase5.5",
      "phase5.6", "phase5.7", "phase6"
    ],
    "escapeHatchTriggered": false
  },

  "hookStatus":          { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [{ "event": "*", "reason": "stub-mode-no-code" }], "warnings": [] },
  "skillStatus":         { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "warnings": [] },
  "agentStatus":         { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "warnings": [] },
  "mcpStatus":           { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "autoInstalled": [], "autoInstallFailed": [] },
  "outputStyleStatus":   { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "warnings": [] },
  "lspStatus":           { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "autoInstalled": [], "autoInstallFailed": [] },
  "builtInSkillsStatus": { "status": "skipped", "reason": "stub-mode-no-code", "planned": [], "generated": [], "skipped": [], "warnings": [], "detectionSignals": {} },

  "generatedArtifacts": [
    "CLAUDE.md",
    ".claude/settings.json",
    ".claude/onboard-meta.json"
  ],

  "nextSteps": [
    "Add source code, then re-run /onboard:start",
    "Re-run /onboard:start after adding source files"
  ]
}
```

## Dynamic version resolution

**Do NOT hardcode a literal version string.** Resolve the current onboard version at runtime:

```bash
ONBOARD_VERSION=""

# 1. CLI-first: prefer the official Claude Code CLI when available
if command -v claude >/dev/null 2>&1; then
  ONBOARD_VERSION=$(claude plugins info onboard --format json 2>/dev/null | jq -r '.version // empty')
fi

# 2. Plugin-root fallback: read the manifest directly
#    (start lives inside onboard, so ${CLAUDE_PLUGIN_ROOT} resolves to onboard's root)
if [ -z "$ONBOARD_VERSION" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
  ONBOARD_VERSION=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json")
fi

# 3. Hard-fail if neither resolved — do NOT write a stub with pluginVersion: null
if [ -z "$ONBOARD_VERSION" ]; then
  echo "ERROR: Cannot resolve onboard plugin version. Reinstall onboard: claude plugins install onboard" >&2
  exit 1
fi
```

Substitute `$ONBOARD_VERSION` everywhere `<dynamic>` appears in the output schemas above. Closes release-gate finding B15.

## Timestamp format

- `timestamp` field → ISO-8601 UTC timestamp with seconds precision: `2026-04-18T14:30:00Z`
- `_generated.date` → UTC date only: `2026-04-18`
- CLAUDE.md maintenance header `generated=` → UTC date only: `2026-04-18`

Use the current time at invocation. Do not read from external time services — any discrepancies with system clock are acceptable.

## Write order

Write files in this order to minimize partial-state exposure on interrupt:

1. `mkdir -p .claude` (if absent)
2. `.claude/onboard-meta.json` first — downstream tools key off its presence
3. `.claude/settings.json` next — session hooks
4. `CLAUDE.md` last — user-facing document

Use atomic writes where possible (`write-to-tmp-then-rename`). On write failure for any artifact, do NOT retry silently — surface the error to the developer with recovery guidance:

> Stub write failed for `<path>`: `<error>`
>
> Recovery: check write permissions on the project root and `.claude/` directory, then re-run `/onboard:start`. No partial state was committed.

## Post-write handoff

After all three files land, return to the start skill for the Phase 7 Handoff. Present a minimal handoff message:

> **Stub configuration generated.**
>
> Created:
> - `CLAUDE.md` (placeholder with working-notes for Claude)
> - `.claude/settings.json` (empty hooks object)
> - `.claude/onboard-meta.json` (canonical schema, stub mode, `pluginVersion: <version>`)
>
> **Next steps:**
> 1. Add source code
> 2. Re-run `/onboard:start` to produce the full AI tooling setup once source files exist

Do NOT run Phase 7's full education/handoff content — the stub has nothing to educate about. Skip straight to this short message and return control.

## Edge cases

1. **Repo already has `.claude/onboard-meta.json` from a prior stub run** — Phase 0 guard detects it via `jq -r '.mode // empty'`. If the value is `"stub-empty-repo"`:
   - If `SRC_COUNT` is still 0: offer re-stub (rare — user ran start twice on empty dir). Default: no-op (stub already exists, exit quickly).
   - If `SRC_COUNT > 0` (source code was added since the stub): the Phase 0 guard short-circuits and the **full flow** runs — Recon → Research → Grounded Wizard → Plan → hard gate → Generation — overwriting the stub artifacts. The regenerated `onboard-meta.json` reflects the full run; no separate promotion step and no gate is skipped.

2. **Repo has `.claude/onboard-meta.json` from a prior FULL run** — the Phase 0 guard doesn't fire at all (SRC_COUNT > 0 means Phase 0 falls through to Phase 1). The existing-config check (the "Check for Existing Claude Config" step of Phase 1 Recon) already handles the "existing config, choose: Update / Start fresh / Cancel" flow.

3. **Repo has `.gitignore` + `README.md` + `LICENSE` but NO source files** — `SRC_COUNT == 0` (the detector filter excludes these files). Phase 0 fires; stub is the default. README content can be referenced as placeholder context in the generated CLAUDE.md if the developer requests it (but by default, the stub doesn't read READMEs — keep the stub strictly minimal).

4. **Write permissions denied** on `.claude/` or project root — hard-fail at Step 1 of write order; surface the error verbatim. Don't attempt fallback locations.

5. **`jq` missing from PATH during version resolution** — the CLI path requires jq for JSON parsing. If jq is missing, fall through to Step 2 (read plugin.json with a basic bash parse):

   ```bash
   # Fallback parse without jq
   ONBOARD_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' \
     "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" | \
     head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
   ```

## Key rules

1. **Canonical schema is mandatory** — every top-level key in the `onboard-meta.json` target matches the canonical shape. Downstream consumers must NOT need to branch on stub vs full mode, except to read the top-level `mode: "stub-empty-repo"` marker when they specifically want to.
2. **All 7 generation-phase status blocks emit `status: "skipped"`** with `reason: "stub-mode-no-code"` — the pre-exit self-audit (config-generator's) accepts `"skipped"` per the existing enum. Do NOT use `"documented"` here; stub mode produces no artifacts for any phase.
3. **Dynamic version resolution is not optional** — hard-fail the stub if the onboard version cannot be resolved. Never write `pluginVersion: null` or a hardcoded literal. Closes B15.
4. **Re-entry with code added falls through to the full flow** — when a prior stub is detected and `SRC_COUNT > 0`, the Phase 0 guard short-circuits to Phase 1 without re-asking. Users don't have to delete the stub before adding code; the full generation overwrites the stub artifacts (with the normal Phase 5 hard gate).
5. **Three files, in this order, atomic writes** — nothing else is emitted; no snapshots, no subdirectory CLAUDE.md files. Stub mode is minimal by design.
