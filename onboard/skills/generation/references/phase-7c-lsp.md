<!-- Extracted from generation/SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# LSP Plugin Recommendations — Phase 7c

Follow `references/lsp-plugin-catalog.md` for the 12-entry language→plugin mapping. Phase 7c recommends and installs official marketplace LSP plugins based on detected source-file presence. Onboard does NOT emit any project-level `.lsp.json` — installing the right plugin is the complete story (LSP config ships inside each plugin's manifest).

**When to run**: After Phase 7b (Output Styles) and before Hooks. Runs once per generation; drift handling lives in `update`/`evolve`.

**Firing paths** (mutually exclusive — exactly one fires per generation):

| Path | Trigger | Behavior |
|---|---|---|
| **Path A — explicit caller list** | `callerExtras.lspPlugins` is a non-null array | Use it verbatim as the accepted list. Empty array = "detected but declined all" → `lspStatus: { status: "declined", accepted: [] }`. |
| **Path A — wizard answer** | `wizardAnswers.lspPlugins` present | Use wizard's accepted list. Same `declined` semantics if empty. |
| **Path B — Quick Mode default** | wizard answer absent AND callerExtras list absent AND detection found candidates | Accept ALL detected plugins. Emit + snapshot + telemetry `status: "emitted"`. |
| **Path NO-CANDIDATES** | `detect-lsp-signals.sh` returns empty array | No install, no snapshot. Telemetry: `lspStatus: { status: "skipped", reason: "detection-empty", planned: [], generated: [] }`. |
| **Path SKIP — caller-disabled** | `callerExtras.disableLSP === true` | No script run, no install, no snapshot. Telemetry: `lspStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [] }`. **Telemetry IS still written.** |

**Inputs**:
- `callerExtras.disableLSP` (optional, headless) — see Path SKIP above; headless callers may pass `true` by default for placeholder code in scaffolds
- `callerExtras.lspPlugins` (optional, headless) — see Path A above
- `wizardAnswers.lspPlugins` (optional) — see Path A above
- Output of `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-lsp-signals.sh" "$PROJECT_ROOT"` — JSON array sorted by fileCount desc

**Telemetry contract**: `lspStatus` MUST be present in `onboard-meta.json` after every generation, regardless of which path fired. Use the `status` enum (`emitted | documented | skipped | declined | failed`) per the Default behavior matrix in `generate/SKILL.md`.

**Step 1 — Detect candidate plugins.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-lsp-signals.sh" "$PROJECT_ROOT"`. Output is a JSON array sorted by fileCount desc, e.g.:

```json
[
  {"language":"typescript","plugin":"typescript-lsp","fileCount":1247,"extensions":[".ts",".tsx","..."]},
  {"language":"rust","plugin":"rust-analyzer-lsp","fileCount":312,"extensions":[".rs"]}
]
```

Empty array → nothing to recommend. Emit `lspStatus: { planned: [], generated: [] }` and skip the remaining steps.

**Step 2 — Resolve selected plugins.**

- If `callerExtras.lspPlugins` is a non-null array → use it verbatim as the accepted list (headless path; caller supplies an explicit list or nothing).
- Else if `wizardAnswers.lspPlugins` exists (from wizard Phase 5.6) → use that as the accepted list.
- Else → use all detected plugins as the accepted list (autonomous Quick Mode path).

Always preserve the full detected list as `recommended`, independent of what was accepted.

**Step 3 — Compose CLAUDE.md "LSP support" subsection.** Append a small subsection under Plugin Integration in the root CLAUDE.md listing the accepted plugins and their language-server binary install prereqs (from `lsp-plugin-catalog.md`). Keep it under 10 lines. When `accepted` is empty but `recommended` is non-empty, list the recommended ones with a "not installed — run `/onboard:evolve` to install" note instead.

**Step 4 — Metadata-first ordering (mirrors Phase 7a).** Install AFTER metadata is written in Phase 8:

1. Add `lspStatus` placeholder to `onboard-meta.json`: `{ planned: [...], generated: [...], accepted: [...], autoInstalled: [], autoInstallFailed: [], skipped: [...] }` with install fields empty.
2. Wait for Phase 8's metadata write to complete.
3. Invoke `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh" <plugin1> <plugin2> ...` with the accepted list.
4. Update `onboard-meta.json.lspStatus.autoInstalled` and `.autoInstallFailed` from the install script's JSON output (single-field read-modify-write; don't touch other keys).

Rationale: if `claude plugin install` hangs or errors, telemetry must already be persisted. Same contract as Phase 7a.

**Step 5 — Write `.claude/onboard-lsp-snapshot.json`.** Pure JSON, no maintenance header — this is the drift baseline for `update` Step 4b.8 and `evolve` Step 2g:

```json
{
  "recommended": ["typescript-lsp", "rust-analyzer-lsp", "pyright-lsp"],
  "accepted": ["typescript-lsp", "rust-analyzer-lsp"]
}
```

Both arrays are sorted alphabetically for stable diffs. Add the snapshot path to `generatedArtifacts`.

**Step 6 — lspStatus telemetry schema.**

```json
"lspStatus": {
  "planned": ["typescript-lsp", "rust-analyzer-lsp", "pyright-lsp"],
  "accepted": ["typescript-lsp", "rust-analyzer-lsp"],
  "generated": ["typescript-lsp", "rust-analyzer-lsp"],
  "skipped": [{"plugin": "pyright-lsp", "reason": "user-declined"}],
  "autoInstalled": ["typescript-lsp"],
  "autoInstallFailed": [],
  "alreadyInstalled": ["rust-analyzer-lsp"]
}
```

**`skipped[].reason` values**: `user-declined` | `caller-disabled` | `detection-empty`.

**Step 7 — Post-emit stdout summary.** Print a terse block listing accepted plugins, any auto-install failures, and any language-server binaries the user still needs to install manually (per catalog). Keep under 6 lines.
