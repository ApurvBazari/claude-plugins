<!-- Extracted from ../SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# MCP Servers (.mcp.json) — Phase 7a

Follow `mcp-guide.md` for emission rules, catalog, and transport shapes.

**When to run**: After Recommended Plugins copy is resolved and before Hooks are merged. Phase 7a runs once per generation; drift handling lives in `update`/`evolve`.

**Firing paths** (mutually exclusive — exactly one fires per generation):

| Path | Trigger | Behavior |
|---|---|---|
| **Path A — wizard answer** | `wizardAnswers` contains MCP server preferences (rare; MCP is signal-driven, not wizard-gated) | Emit per wizard. |
| **Path B — internal generation default** | wizard absent AND no candidate signals | Emit `mcpStatus: { status: "skipped", reason: "no-candidates" }`. No `.mcp.json`, no snapshot. |
| **Path C — signal-driven (default)** | `${CLAUDE_PLUGIN_ROOT}/scripts/detect-mcp-signals.sh` returns ≥1 candidate | Emit `.mcp.json` + snapshot + telemetry. **This path fires regardless of wizard or programmatic mode** unless `callerExtras.disableMCP === true`. |
| **Path SKIP — caller-disabled** | `callerExtras.disableMCP === true` | No `.mcp.json`, no snapshot. Telemetry: `mcpStatus: { status: "skipped", reason: "caller-disabled", planned: [], generated: [] }`. **Telemetry IS still written.** |

**Inputs**:
- `analysis.stack` — frameworks, deps, config-file fingerprints
- `callerExtras.disableMCP` (optional, programmatic) — see Path SKIP above
- Output of `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-mcp-signals.sh" <project-root>` — canonical signal list

**Telemetry contract**: `mcpStatus` MUST be present in `onboard-meta.json` after every generation, regardless of which path fired. Use the `status` enum (`emitted | documented | skipped | declined | failed`) per the Default behavior matrix in `../../generate/SKILL.md`.

**Step 1 — Detect candidates**. Run the detection script; parse JSON output. Candidates marked `confidence: "always"` (context7) emit unconditionally. Candidates marked `confidence: "high"` emit when the signal evaluates unambiguously (see `mcp-guide.md` § Confidence Tiers). Dedupe by server name.

**Step 2 — Pre-existing file check**. If `.mcp.json` already exists at project root:
- Do NOT overwrite
- Record `mcpStatus.existedPreOnboard: true` and `mcpStatus.preservedFile: ".mcp.json"`
- Still emit `.claude/rules/mcp-setup.md` describing servers we *would* have emitted, so the user can reconcile manually
- Skip the write in Step 3 and Step 4

**Step 3 — Write `.mcp.json`**. Use the schema in `mcp-guide.md` § Config Shape. Secret references use the `${VAR}` substitution form — never inline real values.

**Step 4 — Write drift snapshot**. Write `.claude/onboard-mcp-snapshot.json` with the exact contents of `.mcp.json` as written. This is the baseline that `onboard:update` / `onboard:evolve` diff against. Do not include a maintenance header — the snapshot is pure JSON consumed by tooling.

**Step 5 — Populate `mcpStatus`**. Add to `onboard-meta.json` alongside `hookStatus`:
```jsonc
{
  "mcpStatus": {
    "planned": ["context7", "vercel"],
    "generated": ["context7", "vercel"],
    "skipped": [{ "server": "github", "reason": "no-github-workflows-detected" }],
    "autoInstalled": [],
    "autoInstallFailed": [],
    "existedPreOnboard": false
  }
}
```

**Step 6 — Write `.claude/rules/mcp-setup.md`** (conditional on at least one server requiring auth OR on `existedPreOnboard: true`). Use the template in `mcp-guide.md` § mcp-setup.md Template. Include per-server env-var requirements and OAuth steps. Omit when no auth is needed and no pre-existing file existed.

**Step 7 — Auto-install matching plugins** (after Phase 8 metadata is written, see § Auto-install Plugins below). Running after metadata ensures telemetry is persisted even if install fails.

**Step 8 — Post-emit stdout summary**. Print a terse block listing each emitted server and any pending auth steps. See `mcp-guide.md` § Post-emit Summary.

#### Auto-install Plugins

After the metadata file is written in Phase 8, invoke `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh" <plugin1> <plugin2> ...` for each server's `plugin` field (if present). The script:

1. Probes `claude plugin list --json` once
2. Skips plugins already installed
3. Calls `claude plugin install <plugin>` for each remaining plugin
4. Logs failures to stdout but always exits 0 — install layer must never fail Phase 7a

On completion, update `mcpStatus.autoInstalled` and `mcpStatus.autoInstallFailed` in `onboard-meta.json` (re-write the single field; do not touch other keys).
