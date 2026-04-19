# MCP Generation Guide

Rules for emitting `.mcp.json` during Phase 7a of the generation pipeline.

## Purpose

`.mcp.json` tells Claude Code which Model Context Protocol servers to start alongside the project. Onboard emits it automatically when the detected stack unambiguously benefits from a known MCP server. The source of truth for signal→MCP mapping is the probe table in `plugin-detection-guide.md` (MCP columns + "MCP Auto-Emit Signals" section).

## Invocation Gate

Auto-emit. No wizard prompt. The decision is driven purely by stack signals, not plugin installation. If a signal fires and the corresponding Claude Code plugin is not installed, onboard will auto-install it after writing the config (see § Auto-install).

## Catalog

The initial catalog has **6 entries**:

| Signal | Server name | Transport | URL / command | Auth | Required env | Plugin |
|---|---|---|---|---|---|---|
| Any project | `context7` | stdio | `npx -y @upstash/context7-mcp` | none | — | `context7` |
| `.github/workflows/` present | `github` | http | `https://api.githubcopilot.com/mcp/` | token | `GITHUB_PERSONAL_ACCESS_TOKEN` | `github` |
| `vercel.json` OR `@vercel/*` dep | `vercel` | http | `https://mcp.vercel.com` | oauth | — | `vercel` |
| `prisma/` dir OR `@prisma/client` / `prisma` dep | `prisma` | stdio + http | per-plugin (bundled via the `prisma` Claude plugin) | none | — | `prisma` |
| `@supabase/*` dep OR `supabase/` dir | `supabase` | http | `https://mcp.supabase.com` | oauth | — | `supabase` |
| Frontend framework detected | `chrome-devtools-mcp` | stdio | `npx -y chrome-devtools-mcp` | none | — | `chrome-devtools-mcp` |

Frontend frameworks that trigger `chrome-devtools-mcp`: React, Next.js, Vue, Svelte, SvelteKit, Astro, Remix, SolidJS, Nuxt, Qwik. Detection uses `framework` fingerprints from `analysis.stack.frameworks[]`.

## Confidence Tiers

- **always** — emit regardless of other signals. Today: `context7` only (zero-auth, universally useful for docs lookup).
- **high** — emit when the signal is unambiguous (e.g., `vercel.json` present, OR `@vercel/*` in deps). Dedupe by server name across signals.
- **skip-on-uncertainty** — never guess. If the signal matches a fingerprint loosely (e.g., a stray `vercel` string in a README), skip. Record in `mcpStatus.skipped[]` with reason.

## Config Shape

`.mcp.json` lives at project root. Schema:

```json
{
  "mcpServers": {
    "<server-name>": {
      "type": "http" | "stdio" | "sse",
      "url": "https://...",
      "headers": { "Authorization": "Bearer ${ENV_VAR}" },
      "command": "npx",
      "args": ["-y", "package"],
      "env": { "KEY": "${HOST_ENV_VAR}" }
    }
  }
}
```

Field rules per transport:

- **http**: required `type`, `url`; optional `headers`
- **sse**: same as http
- **stdio**: required `command`, `args`; optional `env`. No `type` field needed (stdio is the default when `command` is present).

Env-var references always use the `${VAR}` substitution syntax supported by Claude Code — never inline real secrets.

## Pre-existing .mcp.json

If `.mcp.json` already exists at project root:

1. **Never overwrite.** Record in `onboard-meta.json`:
   ```json
   { "mcpStatus": { "existedPreOnboard": true, "preservedFile": ".mcp.json" } }
   ```
2. Continue to emit `.claude/rules/mcp-setup.md` describing the servers onboard *would* have emitted, so the user can reconcile manually.
3. `onboard:update` may later surface suggested additions, but still never writes the file.

## Drift Snapshot

Because `.mcp.json` is pure JSON (no comments / markers possible), drift detection uses a sidecar file:

- Path: `.claude/onboard-mcp-snapshot.json`
- Contents: exactly what onboard last wrote to `.mcp.json`
- Purpose: `onboard:update` / `onboard:evolve` compare `.mcp.json` vs snapshot to detect user edits and propose (never apply) deltas

## Auto-install

After `.mcp.json` is written and metadata is updated, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh"` with the list of emitted server→plugin pairs. The script:

1. Probes installed plugins once (`claude plugin list --json`)
2. Skips any server whose plugin is already installed
3. Calls `claude plugin install <plugin>` for each remaining server's plugin
4. Logs failures (offline, plugin renamed) to stdout but NEVER exits non-zero — install layer must not fail the generation phase

## mcpStatus Telemetry

Parallel to `hookStatus`. Added to `onboard-meta.json`:

```jsonc
{
  "mcpStatus": {
    "planned": ["context7", "vercel"],           // evaluated from signals
    "generated": ["context7", "vercel"],         // actually written into .mcp.json
    "skipped": [                                  // why anything was not emitted
      { "server": "github", "reason": "no-github-workflows-detected" }
    ],
    "autoInstalled": ["vercel"],                 // plugins that were freshly installed
    "autoInstallFailed": [                        // best-effort install layer
      { "plugin": "supabase", "reason": "exit-code-1" }
    ],
    "existedPreOnboard": false
  }
}
```

Headless callers (forge) read `mcpStatus` from the generate-skill return and can surface it in their own handoff output.

## Caller Escape Hatch

Headless callers may pass `callerExtras.disableMCP: true` to suppress `.mcp.json` emission entirely. When set:

- Skip Phase 7a completely
- Record `mcpStatus.skipped = [{ server: "*", reason: "caller-disabled" }]`
- Do NOT emit `mcp-setup.md`
- Do NOT attempt auto-install

Used by forge when the scaffold template already ships an `.mcp.json`.

## Post-emit Summary

After Phase 7a completes, emit a stdout block summarizing what happened — keep it terse:

```
MCP servers configured:
  ✓ context7 (stdio) — no auth required
  ✓ vercel (http) — OAuth required
    → run `claude mcp auth vercel` to complete setup

See .claude/rules/mcp-setup.md for full details.
```

The rule file is the long-form reference; the stdout block is the quick-glance.

## mcp-setup.md Template

Emit this file at `.claude/rules/mcp-setup.md` when any emitted server requires auth OR when a pre-existing `.mcp.json` was detected. Use standard rules frontmatter (`paths: **` — project-wide context). Include the maintenance header per § Maintenance Header in `generation/SKILL.md`.

Template body (fill the `{{ ... }}` placeholders from `mcpStatus.generated` + catalog metadata):

```markdown
---
paths: "**"
---

# MCP Server Setup

Onboard emitted `.mcp.json` with {{N}} server(s) based on this project's
stack signals. Some servers need additional setup before they will work.

## Emitted servers

| Server | Transport | Auth | Status |
|---|---|---|---|
{{#each emittedServers}}
| `{{name}}` | {{transport}} | {{auth}} | {{authStatus}} |
{{/each}}

## Pending auth steps

{{#each serversNeedingAuth}}
### `{{name}}`

{{#if needsEnvVar}}
Set the following environment variable before starting Claude Code:

```bash
export {{envVar}}="<your-token>"
```

Token source: {{envVarSourceUrl}}
{{/if}}

{{#if needsOAuth}}
Run the Claude Code OAuth flow:

```bash
claude mcp auth {{name}}
```

This opens a browser window to complete authentication. The resulting
token is stored by Claude Code automatically.
{{/if}}
{{/each}}

## Pre-existing `.mcp.json`

{{#if existedPreOnboard}}
This project had `.mcp.json` before onboard ran. Onboard did NOT overwrite it.
Servers listed above are what onboard *would* have emitted — compare against
your existing file and merge manually if useful.
{{/if}}

## Drift

Onboard tracks a snapshot at `.claude/onboard-mcp-snapshot.json`. If you edit
`.mcp.json` directly, running `/onboard:update` will surface the diff but
never auto-apply changes — you stay in control.
```

Rendering notes:
- Omit empty sections (e.g., no "Pre-existing" section if not applicable)
- When no server needs auth AND no pre-existing file existed, onboard does NOT write this rule at all — the stdout summary is sufficient
- Token source URLs live in the catalog: `github` → `https://github.com/settings/tokens`
