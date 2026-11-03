# MCP Generation Guide

Rules for emitting `.mcp.json` during emission Step 1 of the generation pipeline.

## Purpose

`.mcp.json` tells Claude Code which Model Context Protocol servers to start alongside the project. Onboard emits it automatically when the detected stack unambiguously benefits from a known MCP server. The source of truth for signal→MCP mapping is the probe table in `../plugins/plugin-detection-guide.md` (MCP columns + "MCP Auto-Emit Signals" section).

## Invocation Gate

Server entries are emitted from stack signals: no wizard prompt decides which servers are written, and the decision does not depend on which plugins are installed. The **plugin** behind a server is different. It is never installed on a signal alone; it is offered by name and installed only when accepted (see § Install accepted plugins).

## Trust boundary

The catalog below is **hardcoded**. Server URLs and plugin names are NEVER read from the user's project, package metadata, or any external source. A malicious package with a spoofed name (e.g., a typosquat matching `@supabase/*`) can cause a false-positive signal fire — but the resulting `.mcp.json` entry always points to the legitimate URL from this catalog, and a plugin offer always names a plugin from `claude-plugins-official`, never an attacker-controlled endpoint or package. The blast radius of a spoofed signal is "user gets an unexpected-but-real MCP server or plugin offer," not "user gets a malicious MCP server wired up."

To keep spoofed signals rare:

- Use `skip-on-uncertainty` liberally — if the match is loose, skip.
- Prefer two-signal confirmation when adding new catalog entries (e.g., require both a dep match AND a directory match, not just one).
- Document every `.mcp.json` write in `mcpStatus` so the user can review what was emitted.
- The generated `.mcp.json` is committed to the user's project — they see it in code review and can remove or gate auth.

## Catalog

The catalog has **6 entries**. Every plugin named here is in Anthropic's `claude-plugins-official` marketplace and is installed as `<plugin>@claude-plugins-official`.

| Signal | Server name | Transport | URL | Auth | Plugin |
|---|---|---|---|---|---|
| Any project | `context7` | — | none — **plugin-delivered** (the server ships inside the `context7` plugin; no `.mcp.json` entry) | set up by the plugin | `context7` |
| `.github/workflows/` present | `github` | — | none — **plugin-delivered** (the server ships inside the `github` plugin; no `.mcp.json` entry) | set up by the plugin | `github` |
| `vercel.json` OR `@vercel/*` dep | `vercel` | http | `https://mcp.vercel.com` | oauth | `vercel` |
| `prisma/` dir OR `@prisma/client` / `prisma` dep | `prisma` | — | none — **plugin-delivered** (the server ships inside the `prisma` plugin; no `.mcp.json` entry) | set up by the plugin | `prisma` |
| `@supabase/*` dep OR `supabase/` dir | `supabase` | http | `https://mcp.supabase.com` | oauth | `supabase` |
| Frontend framework detected | `chrome-devtools-mcp` | — | none — **plugin-delivered** (the server ships inside the `chrome-devtools-mcp` plugin; no `.mcp.json` entry) | set up by the plugin | `chrome-devtools-mcp` |

Frontend frameworks that trigger `chrome-devtools-mcp`: React, Next.js, Vue, Svelte, SvelteKit, Astro, Remix, SolidJS, Nuxt, Qwik. Detection uses `framework` fingerprints from `analysis.stack.frameworks[]`.

**Plugin-delivered servers.** A row with no URL of its own is plugin-delivered: onboard never writes a `.mcp.json` entry for it, and it exists only as a plugin offer. Today that is `context7`, `github`, `prisma` and `chrome-devtools-mcp`. Onboard never writes a server that runs a package launcher (`npx`, `uvx`) or that reads a credential from the user's environment; those servers reach the project only through their official plugin, and only when the person accepts the offer.

## Confidence Tiers

- **any-project** — a candidate on every project. Today: `context7` only (plugin-delivered, so this only puts it in the offer list; its row starts unchecked like every MCP-plugin row).
- **high** — emit (or offer, for a plugin-delivered row) when the signal is unambiguous (e.g., `vercel.json` present, OR `@vercel/*` in deps). Dedupe by server name across signals.
- **skip-on-uncertainty** — never guess. If the signal matches a fingerprint loosely (e.g., a stray `vercel` string in a README), skip. Record in `mcpStatus.skipped[]` with reason.

## Config Shape

`.mcp.json` lives at project root. Every entry onboard writes is a remote server with a fixed `https` URL from the catalog:

```json
{
  "mcpServers": {
    "<server-name>": {
      "type": "http",
      "url": "https://..."
    }
  }
}
```

Field rules:

- Required: `type` (`"http"`) and `url` (the catalog's absolute `https://` URL).
- Never written: `headers`, `env`, `command`, `args`. Onboard writes no credentials, no `${VAR}` references to the user's environment, and no package launchers. A server that signs in does so with OAuth through Claude Code (`claude mcp login <name>`).

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

## Install accepted plugins

After `.mcp.json` is written and metadata is updated, install the plugins the person accepted, and only those. The procedure is in `../emission/mcp-emission.md` § Install accepted plugins. The rule is in `../../../../references/plugin-install-consent.md`. In short:

1. The accepted list comes from the wizard's MCP-plugin offer, or from a programmatic caller's explicit list. Absent or empty means no install.
2. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh" <name>@claude-plugins-official ...` probes installed plugins once and skips those already installed. Every name is passed qualified with its marketplace, so the install never resolves against another marketplace that happens to use the same name.
3. Failures (offline, plugin renamed) are logged and NEVER fail the generation phase.
4. A `regenerateOnly` or `reResearch` generation skips this step.

## mcpStatus Telemetry

Parallel to `hookStatus`. Added to `onboard-meta.json`:

```jsonc
{
  "mcpStatus": {
    "planned": ["context7", "vercel"],           // evaluated from signals
    "generated": ["vercel"],                     // actually written into .mcp.json
    "skipped": [                                  // why anything was not emitted
      { "server": "context7", "reason": "plugin-declined" },
      { "server": "github", "reason": "no-github-workflows-detected" }
    ],
    "pluginOffers": { "offered": ["context7", "vercel"], "accepted": ["vercel"] }, // what was offered, and what the person took
    "autoInstalled": ["vercel"],                 // installed after acceptance (key name is historical)
    "autoInstallFailed": [                        // an accepted install that failed
      { "plugin": "supabase", "reason": "exit-code-1" }
    ],
    "existedPreOnboard": false
  }
}
```

Programmatic callers read `mcpStatus` from the generate-skill return and can surface it in their own handoff output.

## Caller Escape Hatch

Programmatic callers may pass `callerExtras.disableMCP: true` to suppress `.mcp.json` emission entirely. When set:

- Skip emission Step 1 completely
- Record `mcpStatus.skipped = [{ server: "*", reason: "caller-disabled" }]`
- Do NOT emit `mcp-setup.md`
- Do NOT offer or install any plugin

Used when the scaffold template already ships an `.mcp.json`.

## Post-emit Summary

After emission Step 1 completes, emit a stdout block summarizing what happened — keep it terse:

```
MCP servers configured:
  ✓ vercel (http) — OAuth required
    → run `claude mcp login vercel` to complete setup

Plugins:
  ✓ vercel — installed (you accepted it)
  · context7 — not installed; add it with `claude plugin install context7@claude-plugins-official`

See .claude/rules/mcp-setup.md for full details.
```

The rule file is the long-form reference; the stdout block is the quick-glance.

## mcp-setup.md Template

Emit this file at `.claude/rules/mcp-setup.md` when any emitted server requires auth OR when a pre-existing `.mcp.json` was detected. Use standard rules frontmatter (`paths: **` — project-wide context). Include the maintenance header per § Maintenance Header in `../../SKILL.md`.

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

{{#if needsOAuth}}
Run the Claude Code OAuth flow:

```bash
claude mcp login {{name}}
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
- Every server onboard writes signs in with OAuth; onboard never asks for a token or an environment variable
