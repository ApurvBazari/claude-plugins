# Adopt — Detection & Classification (A1)

Canonical procedure for detecting and classifying a repo's pre-existing Claude tooling surface. Invoked by `adopt/SKILL.md` Step A1. Read-only — this procedure writes nothing.

## Detect the surface

Use native Glob/Read (no scripts) to enumerate every Claude-tooling artifact:

| Category | Probe | Classify as |
|---|---|---|
| Root context | `CLAUDE.md` (project root) | `claude-md` |
| Subdir context | `**/CLAUDE.md` (excluding root) | `subdir-claude-md` |
| Rules | `.claude/rules/*.md` | `rule` |
| Skills | `.claude/skills/*/SKILL.md` | `skill` |
| Agents | `.claude/agents/*.md` | `agent` |
| Output styles | `.claude/output-styles/*.md` | `output-style` |
| MCP | `.mcp.json` (root) | `mcp` |
| Hooks | `.claude/settings.json` → `.hooks` keys | `hook` |
| LSP | installed marketplace LSP plugins matching project languages (`claude plugin list --json`, best-effort) | `lsp` |
| Built-in skill refs | mentions of built-in skills (`/loop`, `/simplify`, …) inside `CLAUDE.md` | `built-in-ref` |
| Harness (enriched) | `docs/progress.md`, `docs/HARNESS-GUIDE.md`, `docs/feature-list.json`, `docs/sprint-contracts/**` | `harness` (catalogued, not deeply managed) |

For each detected file capture: `path`, `category`, and (for `skill`/`agent`/`output-style`) the parsed YAML frontmatter fields, and whether an onboard maintenance header is present (it is normally **absent** for foreign tooling).

## Redirect rules (entry guards)

Run these BEFORE recon:

1. **No CLAUDE.md AND no `.claude/` tooling** → there is nothing to adopt. Tell the developer and redirect:
   > No existing Claude tooling found to adopt. Run `/onboard:start` to generate tooling from scratch.
   Stop. (When `adopt` was entered from `update`'s guard, this case cannot occur — update's guard only routes here when tooling was detected.)
2. **`.claude/onboard-meta.json` already present** → this repo is already onboard-managed. Redirect:
   > This project is already managed by onboard (`.claude/onboard-meta.json` found). Run `/onboard:update` to align it with the latest best practices.
   Stop. (Adopt is only for *foreign* tooling.) Exception: a `mode:"stub-empty-repo"` meta is not a real baseline — treat it as adoptable only if real source + tooling now exist; otherwise prefer `/onboard:start` (stub auto-promote). In practice, redirect stub repos to `/onboard:start`.

## Output (in-context, not written)

Return a `detectedSurface` object held in conversation context:

```jsonc
{
  "artifacts": [
    { "path": "CLAUDE.md", "category": "claude-md", "headerPresent": false },
    { "path": ".claude/rules/testing.md", "category": "rule", "headerPresent": false },
    { "path": ".claude/skills/run-tests/SKILL.md", "category": "skill", "headerPresent": false,
      "frontmatter": { "name": "run-tests", "description": "…" } }
    // … one entry per detected artifact
  ],
  "categoriesPresent": ["claude-md", "rule", "skill", "agent", "mcp", "hook"],
  "reconHints": { /* set later by recon (A2); placeholder here */ }
}
```

Empty categories simply don't appear — the baseline reflects only present categories (spec F2 edge case 5).
