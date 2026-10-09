<!-- Extracted from ../../SKILL.md via progressive-disclosure. Content is verbatim emission spec / templates. -->

# MCP Servers (.mcp.json) — emission Step 1

Follow `../catalogs/mcp-guide.md` for emission rules, catalog, and transport shapes.

**When to run**: After Recommended Plugins copy is resolved and before Hooks are merged. emission Step 1 runs once per generation; drift handling lives in `update`/`evolve`.

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

**Telemetry contract**: `mcpStatus` MUST be present in `onboard-meta.json` after every generation, regardless of which path fired. Use the `status` enum (`emitted | documented | skipped | declined | failed`) per the Default behavior matrix in `../../../generate/SKILL.md`.

**Step 1 — Detect candidates**. Run the detection script; parse JSON output. Candidates marked `confidence: "always"` (context7) emit unconditionally. Candidates marked `confidence: "high"` emit when the signal evaluates unambiguously (see `../catalogs/mcp-guide.md` § Confidence Tiers). Dedupe by server name.

**Step 2 — Pre-existing file check**. If `.mcp.json` already exists at project root:
- Do NOT overwrite
- Record `mcpStatus.existedPreOnboard: true` and `mcpStatus.preservedFile: ".mcp.json"`
- Still emit `.claude/rules/mcp-setup.md` describing servers we *would* have emitted, so the user can reconcile manually
- Skip the write in Step 3 and Step 4

**Step 3 — Write `.mcp.json`**. Use the schema in `../catalogs/mcp-guide.md` § Config Shape. Secret references use the `${VAR}` substitution form — never inline real values. A catalog row with no command or URL of its own (today: `prisma`) is **plugin-delivered**: never write a `.mcp.json` entry for it. Record it in `mcpStatus.skipped` as `{ "server": "<name>", "reason": "plugin-delivered" }` when its plugin is in the accepted list, or with reason `"plugin-declined"` when it is not.

**Step 4 — Write drift snapshot**. Write `.claude/onboard-mcp-snapshot.json` with the exact contents of `.mcp.json` as written. This is the baseline that `onboard:update` / `onboard:evolve` diff against. Do not include a maintenance header — the snapshot is pure JSON consumed by tooling.

**Step 5 — Populate `mcpStatus`**. Add to `onboard-meta.json` alongside `hookStatus`:
```jsonc
{
  "mcpStatus": {
    "planned": ["context7", "vercel"],
    "generated": ["context7", "vercel"],
    "skipped": [{ "server": "github", "reason": "no-github-workflows-detected" }],
    "pluginOffers": { "offered": ["context7", "vercel"], "accepted": ["vercel"] },
    "autoInstalled": [],
    "autoInstallFailed": [],
    "existedPreOnboard": false
  }
}
```

Write `pluginOffers` here on every full `write` run, whether or not anything was accepted: a declined offer has to be remembered. What goes in it is defined under § Install accepted plugins below. On a `regenerateOnly` or `reResearch` run, leave the stored `pluginOffers` exactly as it is.

**Step 6 — Write `.claude/rules/mcp-setup.md`** (conditional on at least one server requiring auth OR on `existedPreOnboard: true`). Use the template in `../catalogs/mcp-guide.md` § mcp-setup.md Template. Include per-server env-var requirements and OAuth steps. Omit when no auth is needed and no pre-existing file existed.

**Step 7 — Install accepted plugins** (after the metadata-write step, see § Install accepted plugins below). Running after metadata ensures telemetry is persisted even if an install fails.

**Step 8 — Post-emit stdout summary**. Print a terse block listing each emitted server and any pending auth steps. See `../catalogs/mcp-guide.md` § Post-emit Summary.

#### Install accepted plugins

Follow `../../../../references/plugin-install-consent.md`: the rule (R1 to R4), the offer shape and what happens when nobody answers live there. This step never asks. The offer was made earlier, in wizard Exchange 3 for `start` or by the caller.

1. Resolve the accepted list: `callerExtras.mcpPlugins` → `wizardAnswers.mcpPlugins` → `[]`.
2. Keep only names that are the `plugin` of a server in `../catalogs/mcp-guide.md` § Catalog. Drop anything else and add a warning.
3. If the context carries `callerExtras.regenerateOnly` or `callerExtras.reResearch`, stop here. A repair run never installs.
4. If the list is empty, stop here. Nothing was accepted, so nothing is installed.
5. After the metadata file is written, invoke `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh" <accepted1> <accepted2> ...`. The script probes `claude plugin list --json` once, skips plugins already installed, installs the rest, and always exits 0: an install failure must never fail emission Step 1.
6. Update `onboard-meta.json`, re-writing the install results only: `mcpStatus.autoInstalled`, `mcpStatus.autoInstallFailed`. `mcpStatus.pluginOffers` was already written in Step 5 and is not touched here.

`mcpStatus.pluginOffers.offered` is every candidate server's plugin **when an answer exists**, meaning `callerExtras.mcpPlugins` or `wizardAnswers.mcpPlugins` is present. When neither is present no offer was made, so `offered` is `[]` and `update` or `evolve` may offer those plugins later. `accepted` is the list from step 2. Both arrays are sorted alphabetically.
