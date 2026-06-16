# Adopt — Baseline Synthesis (A4 + A6)

Canonical procedure for synthesizing the onboard baseline from a detected foreign-tooling surface, and writing it. Invoked by `adopt/SKILL.md` (A4 builds the record-set + meta in context; A6 writes them after the gate approves). **Adopt writes ONLY `onboard-meta.json` + snapshots (+ the research engine's own `onboard-research.json`, written in A2). It touches NONE of the existing hand-crafted artifacts.**

## A4: build the record-set (in context, writes nothing)

From the `detectedSurface` (A1) build a `record`-set — one `changes[]` entry per tracked artifact, shaped per `../../../schemas/generation-manifest.json` `changes[]`:

```jsonc
{ "path": "CLAUDE.md", "action": "record", "purpose": "Existing root project context (adopted)",
  "outline": "<top-level section names parsed from the file>", "tier": "core", "origin": "adopted" }
```

- `action` is **always `"record"`** (adopt never `create`/`merge`/`modernize` — those belong to a later `/onboard:update`).
- `tier`: `core` for CLAUDE.md/rules/skills/agents/output-styles/hooks/mcp/lsp/built-in; `enriched` for harness artifacts.
- `origin` is **always `"adopted"`**.

Also build, in context, the baseline `onboard-meta.json` and the snapshot objects (below) — but DO NOT write yet. A5 (the gate) renders the record-set; only A6 writes.

## A4: synthesize the meta object (in context)

Canonical-shape `onboard-meta.json` with retrofit additions. Resolve `<dynamic>` plugin version exactly as `../../start/references/empty-repo-stub-procedure.md § Dynamic version resolution` (CLI-first, plugin.json fallback, hard-fail if unresolved — reuse that block verbatim).

```jsonc
{
  "pluginVersion": "<dynamic>",
  "_generated": { "by": "onboard", "version": "<dynamic>", "date": "<ISO-date>" },
  "timestamp": "<ISO-8601 UTC>",
  "source": "onboard:adopt",
  "mode": "retrofit",

  "wizardAnswers": { /* canonical shape from the A3 grounded wizard — wizard/SKILL.md § Output */ },
  "wizardStatus": { /* canonical 5-key shape — wizard/SKILL.md § Key Rule 7 */ },

  "research": {
    "consumed": true, "engineUsed": "subagent", "depth": "comprehensive",
    "specialistsRun": [ /* dossier findings{} keys */ ],
    "claimsVerified": <n>, "claimsDropped": <n>,
    "artifactLocation": "<committed|local|none>", "artifactsWritten": [ /* dossier artifacts.written */ ],
    "htmlRendered": "<gate render path or null>",
    "backlogSeeded": false, "backlogItemCount": 0
  },

  "detectedPlugins": { "installedPlugins": [ /* probe */ ], "coveredCapabilities": [], "qualityGates": {}, "phaseSkills": {} },

  "artifactProvenance": {
    "CLAUDE.md": "adopted",
    ".claude/rules/testing.md": "adopted"
    // … one entry per tracked artifact, ALL "adopted"
  },

  "generatedArtifacts": [ /* every adopted artifact path — update Step 2 walks this list */ ],

  "hookStatus":          { "status": "adopted", "generated": [ /* hook event names present in settings.json */ ], "skipped": [], "warnings": [] },
  "skillStatus":         { "status": "adopted", "generated": [ /* skill names */ ], "existedPreOnboard": [], "frontmatterFields": { /* <name>: {<captured fields>, "source": "adopted"} */ }, "warnings": [] },
  "agentStatus":         { "status": "adopted", "generated": [ /* agent names */ ], "existedPreOnboard": [], "frontmatterFields": { /* … "source": "adopted" */ }, "warnings": [] },
  "outputStyleStatus":   { "status": "adopted", "generated": [ /* style stems */ ], "existedPreOnboard": [], "frontmatterFields": { /* … "source": "adopted" */ }, "warnings": [] },
  "mcpStatus":           { "status": "adopted", "generated": [ /* server names from .mcp.json */ ], "existedPreOnboard": true, "autoInstalled": [], "autoInstallFailed": [] },
  "lspStatus":           { "status": "adopted", "accepted": [ /* installed lsp plugins */ ], "generated": [], "skipped": [], "autoInstalled": [], "autoInstallFailed": [] },
  "builtInSkillsStatus": { "status": "adopted", "generated": [ /* built-in skill refs found in CLAUDE.md */ ], "skipped": [], "detectionSignals": {}, "warnings": [] }
}
```

Notes:
- Block `status: "adopted"` is a retrofit-only value. It is written by adopt, NOT by config-generator, so it does not pass through config-generator's generated-mode self-audit (which stays `{emitted|documented|skipped|declined|failed}`).
- A category with no detected artifacts → omit its `generated[]` entries (empty arrays are fine); reflect only present categories.
- `mcpStatus.existedPreOnboard: true` always in retrofit mode (adopt never owns `.mcp.json`).
- Adopt always runs research (A2), so `research.consumed` is **always `true`**. On a `location:"none"` or minimal dossier, keep `consumed:true` with `artifactLocation:"none"`, `artifactsWritten:[]`, `htmlRendered:null` — never `consumed:false` (that is config-generator's research-absent convention, which adopt never hits). The re-research 4c telemetry fields never apply (adopt does not re-research).
- `detectedPlugins` captures `installedPlugins` / `coveredCapabilities` / `qualityGates` / `phaseSkills` (the drift-load-bearing set `update` § 4b.1 reads). Adopt does not run start's Phase-2.5 surface probe, so `pluginSurfaces` is intentionally omitted; a later `/onboard:update` modernization re-probes plugin surfaces live when it regenerates the Plugin Integration section.
- `wizardStatus.presetUsed` is `"retrofit"` — a retrofit-only value parallel to the stub's `"stub-empty-repo"`; it sits outside the wizard's 3-profile enum (`minimal|standard|comprehensive`) and is not enum-gated by any consumer (the canonical 5-key shape is otherwise honored per `../../wizard/SKILL.md` § Key Rule 7).
- In retrofit mode `hookStatus.generated` lists the hook events **observed** in the user's `.claude/settings.json` (user-owned), not events onboard wired — consistent with the A6 prohibition on touching `.claude/settings.json`.

## A4: synthesize snapshots (in context)

Capture **current** (hand-crafted) state as the baseline so update shows zero drift immediately after adopt. One file per present category, same shapes update's drift detectors read (`drift-classification.md` §§ 4b.5–4b.9):

- `.claude/onboard-skill-snapshot.json` — `{ "<skill>": { <frontmatter fields parsed from the live SKILL.md> } }`
- `.claude/onboard-agent-snapshot.json` — `{ "<agent>": { <live frontmatter> } }`
- `.claude/onboard-output-style-snapshot.json` — `{ "<style>": { name, description, keep-coding-instructions, archetype, source } }` — always write all 5 keys; for keys absent in the foreign frontmatter set `archetype: null` (or a best-effort inference) and `source: "adopted"`.
- `.claude/onboard-mcp-snapshot.json` — the servers as they appear in `.mcp.json`
- `.claude/onboard-lsp-snapshot.json` — `{ "recommended": [], "accepted": [ /* installed lsp plugins */ ] }`
- `.claude/onboard-builtin-skills-snapshot.json` — `{ "recommended": [], "accepted": [ /* refs found in CLAUDE.md */ ] }`

## A6: write the baseline (only after the gate Approves)

Write order (atomic where possible; mirror the stub procedure's interrupt-safety):

1. `mkdir -p .claude` (if absent).
2. The snapshot files (each present category).
3. `.claude/onboard-meta.json` (last of the state files — downstream tools key off its presence).
4. Set `research.htmlRendered` (and re-write `.claude/onboard-research.json`'s `artifacts.html`) to the gate's render path when the A5 HTML render succeeded; leave `null` on the markdown-fallback path. (The research engine already wrote `onboard-research.json` in A2; A6 only patches `artifacts.html`.)

**Never** call Write/Edit on `CLAUDE.md`, `.claude/rules/**`, `.claude/skills/**`, `.claude/agents/**`, `.claude/output-styles/**`, `.mcp.json`, or merge into `.claude/settings.json`. Adopt's write surface is exactly: the 6 snapshots + `onboard-meta.json` + the `onboard-research.json` html patch. Any other write is a contract violation.

On a write failure, surface the error and recovery guidance (same shape as the stub procedure's failure message); do not retry silently; no partial baseline.

## Key rules

1. **Baseline only** — the write surface above is exhaustive. Hand-crafted artifacts are read, catalogued, snapshotted — never modified.
2. **Everything `origin:"adopted"`** — `artifactProvenance` has one `"adopted"` entry per tracked artifact (Managed stance).
3. **`action:"record"` only** — the record-set never carries `create`/`merge`/`modernize`/`add-header`; modernization is a later `/onboard:update`.
4. **Canonical meta shape** — downstream consumers must not need retrofit-specific branching except to read `mode:"retrofit"` / `artifactProvenance` when they specifically want provenance.
5. **Dynamic version resolution is not optional** — hard-fail if the onboard version cannot be resolved (reuse the stub procedure's block); never write `pluginVersion: null`.
